#ifndef SCOMP_H
#define SCOMP_H

#define SCOMP_MAXSEQ		0xFFFF
#define SCOMP_MAXPAYLOAD	0xFFFF

#define SCOMP_REQUEST 		'Q'
#define SCOMP_RESPONSE 		'R'

typedef int (*ScompCb_t)(void *,int,int);

typedef union {
	int i;
	ScompCb_t cb;
} ScompOpt_t;

enum ScompOpt_enum {
	SCOMP_OPT_USE_CRC,
	SCOMP_OPT_SNDCB,
	SCOMP_OPT_RCVCB,
};

enum {
	SCOMP_ERR_OK,		// no error
	SCOMP_ERR_TIMEOUT,	// operation timed out
	SCOMP_ERR_SND,		// send message failed
	SCOMP_ERR_RCV,		// receive message failed
	SCOMP_ERR_CRC,		// CRC mismatch
	SCOMP_ERR_SEQ,		// sequence number mismatch
	SCOMP_ERR_TYPE,		// message type mismatch
	SCOMP_ERR_RANGE,	// size exceeds max payload length
	SCOMP_ERR_BADNUM,	// numerical field encoding error
	SCOMP_ERR_OVER,		// data length exceeds buffer size
	SCOMP_ERR_BADOPT,	// unrecognized SComP option
};

const char *ScompStrErr( int e );
int ScompSetOption( enum ScompOpt_enum opt, ScompOpt_t val );

int ScompSend( char *data, int size, int *seq, int type );
int ScompSendResponse( char *data, int size, int seq );
int ScompRecv( char *data, int *size, int *seq, int *type, int to );
int ScompExch( char *query, int qsz, char *resp, int *rsz, int to );

#endif	//ndef SCOMP_H

/* EOF */
