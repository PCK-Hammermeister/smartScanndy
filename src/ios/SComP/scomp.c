#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/time.h>

#include "crc32.h"
#include "scomp.h"


#define HDR_SIZE		10
#define TRL_SIZE		8
#define SND_TIMEOUT		100


static int dummycb( void *data, int size, int to )
{
	return 0;
	(void)data;
	(void)size;
	(void)to;
}

static struct {
	int use_crc;
	ScompCb_t snd;
	ScompCb_t rcv;
} scompOpt = {
	1,
	dummycb,
	dummycb,
};

static unsigned int scompSeq = 0;


static inline int xd2dd( int c )
{
	char h[] = "0123456789ABCDEFabcdef";
	char *p = strchr( h, c );
	int d;
	if ( !p || !*p )
		return -1;
	d = p - h;
	if ( 15 < d )
		d -= 6;
	return d;
}

static unsigned long xtoul( const char *s, int *rl )
{
	int d;
	unsigned long res = 0;

	while ( *rl && 0 <= ( d = xd2dd( *s ) ) )
	{
		res = res * 16 + d;
		++s;
		--*rl;
	}
	return res;
}


int ScompSetOption( enum ScompOpt_enum opt, ScompOpt_t val )
{
	int res = SCOMP_ERR_OK;
	switch ( opt )
	{
	case SCOMP_OPT_USE_CRC:
		scompOpt.use_crc = val.i;
		break;
	case SCOMP_OPT_SNDCB:
		scompOpt.snd = val.cb;
		break;
	case SCOMP_OPT_RCVCB:
		scompOpt.rcv = val.cb;
		break;
	default:
		res = SCOMP_ERR_BADOPT;
		break;
	}
	return res;
}


const char *ScompStrErr( int e )
{
	const char *msg[] = {
		"no error",// SCOMP_ERR_OK
		"timeout",//SCOMP_ERR_TIMEOUT
		"send",//SCOMP_ERR_SND
		"receive",//SCOMP_ERR_RCV
		"crc mismatch",//SCOMP_ERR_CRC
		"sequence number mismatch",//SCOMP_ERR_SEQ
		"message type mismatch",//SCOMP_ERR_TYPE
		"parameter out of range",//SCOMP_ERR_RANGE
		"number encoding",//SCOMP_ERR_BADNUM
		"bad option specifier",//SCOMP_ERR_BADOPT
		"buffer overflow",//SCOMP_ERR_OVER
	};
	if ( 0 > e || ( sizeof msg / sizeof *msg ) <= (unsigned)e )
		return "unknown";
	return msg[e];
}


static inline void incSeq( void )
{
	scompSeq = ( scompSeq + 1 ) % ( SCOMP_MAXSEQ + 1 );
}


int ScompSend( char *data, int size, int *seq, int type )
{
	int res = SCOMP_ERR_OK;
	char hdr[HDR_SIZE + 1];
	char trl[TRL_SIZE + 1] = "00000000";
	crc32_t crc;

	if ( SCOMP_MAXPAYLOAD < size )
		return SCOMP_ERR_RANGE;
	if ( 0 > *seq )
		*seq = scompSeq;
	sprintf( hdr, "%04X%c%04X#", *seq, type, size );
	if ( scompOpt.use_crc )
	{
		crc32_init( &crc );
		crc32_update( &crc, (uint8_t *)hdr, HDR_SIZE );
		crc32_update( &crc, (uint8_t *)data, size );
		crc32_final( &crc );
		sprintf( trl, "%08X", crc );
	}
    

#ifdef __APPLE__
    char * buffer;
    int sizeTotal = HDR_SIZE + size + TRL_SIZE;
    buffer = (char*) malloc (sizeTotal);
    
    if (buffer==NULL)
        res = SCOMP_ERR_OVER;
    else
    {
        memcpy(buffer, hdr, HDR_SIZE);
        memcpy(buffer + HDR_SIZE, data, size);
        memcpy(buffer + HDR_SIZE + size, trl, TRL_SIZE);        
    }
    
    if (scompOpt.snd( buffer, sizeTotal, SND_TIMEOUT ) != (sizeTotal))
        res = SCOMP_ERR_SND;
    
    free (buffer);
#else
    if ( HDR_SIZE != scompOpt.snd( hdr, HDR_SIZE, SND_TIMEOUT )
        || size != scompOpt.snd( data, size, SND_TIMEOUT )
        || TRL_SIZE != scompOpt.snd( trl, TRL_SIZE, SND_TIMEOUT ) )
	{
		res = SCOMP_ERR_SND;
	}
#endif
   
	incSeq();
	return res;
}


int ScompSendResponse( char *data, int size, int seq )
{
	int sseq = seq;
	return ScompSend( data, size, &sseq, SCOMP_RESPONSE );
}


int ScompRecv( char *data, int *size, int *seq, int *type, int to )
{
	int rl = 0;
	int len = 0;
	char hdr[HDR_SIZE + 1];
	char trl[TRL_SIZE + 1];
	crc32_t crc = 0x00000000;

	// get header
	rl = scompOpt.rcv( hdr, HDR_SIZE, to );
	if ( 0 == rl )
		return SCOMP_ERR_TIMEOUT;
	else if ( HDR_SIZE != rl )
		return SCOMP_ERR_RCV;
	hdr[rl] = '\0';
	// extract sequence number
	rl = 4;
	*seq = xtoul( hdr, &rl );
	if ( 0 != rl )
		return SCOMP_ERR_BADNUM;
	// extract type field (request or response)
	*type = hdr[4];
	// extract length field
	rl = 4;
	len = xtoul( hdr + 5, &rl );
	if ( 0 != rl )
		return SCOMP_ERR_BADNUM;
	if ( len > *size )
		return SCOMP_ERR_OVER;
	*size = len;

	// get payload data
	if ( 0 < len )
	{
		rl = scompOpt.rcv( data, len, to );
		if ( 0 == rl )
			return SCOMP_ERR_TIMEOUT;
		else if ( rl != len )
			return SCOMP_ERR_RCV;
	}

	// get trailer
	rl = scompOpt.rcv( trl, TRL_SIZE, to );
	if ( 0 == rl )
		return SCOMP_ERR_TIMEOUT;
	else if ( TRL_SIZE != rl )
		return SCOMP_ERR_RCV;
	trl[rl] = '\0';
	// check crc
	if ( scompOpt.use_crc )
	{
		crc32_init( &crc );
		crc32_update( &crc, (uint8_t *)hdr, HDR_SIZE );
		crc32_update( &crc, (uint8_t *)data, len );
		crc32_final( &crc );
		rl = 8;
		if ( xtoul( trl, &rl ) != crc || 0 != rl )
			return SCOMP_ERR_CRC;
	}
	return SCOMP_ERR_OK;
}


int ScompExch( char *query, int qsz, char *resp, int *rsz, int to )
{
	int sseq = -1;
	int rseq;
	int type;
	int r = ScompSend( query, qsz, &sseq, SCOMP_REQUEST );
	*resp = '\0';
	if ( SCOMP_ERR_OK == r && SCOMP_ERR_OK == ( r = ScompRecv( resp, rsz, &rseq, &type, to ) ) )
	{
		if ( rseq != sseq )
			r = SCOMP_ERR_SEQ;
		else if ( type != SCOMP_RESPONSE )
			r = SCOMP_ERR_TYPE;
	}
	return r;
}


/* EOF */
