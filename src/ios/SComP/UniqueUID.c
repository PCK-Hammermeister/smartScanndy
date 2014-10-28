#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <bsp/bsp.h>


// convert string of hex digits to array of bytes
static int hex2bin( unsigned char *dst, const char *src, int ndigits )
{
	if ( ndigits % 2 )	// cannot convert odd number of nibbles (half-bytes)
		return -1;

	const char * const hstr = "0123456789ABCDEF";
	char *p = NULL;
	int i = 0;

	while ( i < ndigits )
	{
		p = strchr( hstr, toupper( (unsigned char)src[ i ] ) );

		if ( NULL == p )
			return -1;	// invalid hex digit

		dst[ i / 2 ] = ( p - hstr ) << 4;
		++i;
		p = strchr( hstr, toupper( (unsigned char)src[ i ] ) );

		if ( NULL == p )
			return -1;	// invalid hex digit

		dst[ i / 2 ] |= ( p - hstr );
		++i;
	}

	return ( i / 2 );
}


// convert array of bytes to string of hex digits
static int bin2hex( char *dst, const unsigned char *src, int nbytes )
{
	int i = 0;

	for ( i = 0; i < nbytes; ++i )
	{
		if ( 2 != sprintf( dst + i * 2, "%02X", (unsigned int)src[ i ] ) )
			return -1;	// conversion error
	}

	return i * 2;
}


// convert array of bytes to string of decimal digits
static int bin2dec( char *dst, const unsigned char *src, int nbytes )
{
	unsigned long long val = 0;
	int i = 0;

	for ( i = 0; i < nbytes; ++i )
		val = val * 256 + src[ i ];
	
	dst[ 13 ] = '\0';

	for ( i = 12; i >= 0; --i )
	{
		dst[ i ] = val % 10 + '0';
		val /= 10;
	}

	return strlen( dst );
}


/*
** Convert hexadecimal ASCII coded 64 bit UID (16 characters stored in uid64s)
** to hexadecimal ASCII coded 40 bit UID (10 characters stored in uid40s).
*/
int Unique64to40( char *pUid40s, const char *pUid64s )
{
	if ( strlen( pUid64s ) != 16 )
		return -1;

	unsigned char uid64[ 8 ]; // buffer to store binary uid64

	if ( 8 != hex2bin( uid64, pUid64s, 16 ) )
		return -1;			// hex digit to binary conversion error
		
	unsigned char uid40[ 5 ]; // buffer to store binary uid40
	
	// do the bit (un)shuffeling to extract the "pure" 40 bit UID:
	uid40[ 0 ] = ( ( uid64[ 1 ] << 1 ) & 0xf0 ) | 
				 ( ( uid64[ 1 ] << 2 ) & 0x0c ) |
				 ( ( uid64[ 2 ] >> 6 ) & 0x03 );

	uid40[ 1 ] = ( ( uid64[ 2 ] << 3 ) & 0xf0 ) | 
				 ( ( uid64[ 3 ] >> 4 ) & 0x0f );

	uid40[ 2 ] = ( ( uid64[ 3 ] << 5 ) & 0xe0 ) | 
				 ( ( uid64[ 4 ] >> 3 ) & 0x10 ) |
				 ( ( uid64[ 4 ] >> 2 ) & 0x0f );

	uid40[ 3 ] = ( ( uid64[ 4 ] << 7 ) & 0x80 ) | 
				 ( ( uid64[ 5 ] >> 1 ) & 0x70 ) |
				 (   uid64[ 5 ]        & 0x0f );

	uid40[ 4 ] = ( ( uid64[ 6 ] << 1 ) & 0xf0 ) | 
				 ( ( uid64[ 6 ] << 2 ) & 0x0c ) |
				 ( ( uid64[ 7 ] >> 6 ) & 0x03 );

	if ( 10 != bin2hex( pUid40s, uid40, 5 ) )
		return -1;			// binary to hex digit conversion error
		
	return 0;
}


/*
** Convert hexadecimal ASCII coded 64 bit UID (16 characters stored in uid64s)
** to decimal ASCII coded 40 bit UID (13 characters stored in uid40s).
*/
int Unique64to13( char *pUid40s, const char *pUid64s )
{
	if ( strlen( pUid64s ) != 16 )
		return -1;

	unsigned char uid64[ 8 ]; // buffer to store binary uid64
	
	if ( 8 != hex2bin( uid64, pUid64s, 16 ) )
		return -1;			// hex digit to binary conversion error
		
	unsigned char uid40[ 5 ]; // buffer to store binary uid40
	
	// do the bit (un)shuffeling to extract the "pure" 40 bit UID:
	uid40[ 0 ] = ( ( uid64[ 1 ] << 1 ) & 0xf0 ) | 
				 ( ( uid64[ 1 ] << 2 ) & 0x0c ) |
				 ( ( uid64[ 2 ] >> 6 ) & 0x03 );

	uid40[ 1 ] = ( ( uid64[ 2 ] << 3 ) & 0xf0 ) | 
				 ( ( uid64[ 3 ] >> 4 ) & 0x0f );

	uid40[ 2 ] = ( ( uid64[ 3 ] << 5 ) & 0xe0 ) | 
				 ( ( uid64[ 4 ] >> 3 ) & 0x10 ) |
				 ( ( uid64[ 4 ] >> 2 ) & 0x0f );

	uid40[ 3 ] = ( ( uid64[ 4 ] << 7 ) & 0x80 ) | 
				 ( ( uid64[ 5 ] >> 1 ) & 0x70 ) |
				 (   uid64[ 5 ]        & 0x0f );

	uid40[ 4 ] = ( ( uid64[ 6 ] << 1 ) & 0xf0 ) | 
				 ( ( uid64[ 6 ] << 2 ) & 0x0c ) |
				 ( ( uid64[ 7 ] >> 6 ) & 0x03 );

	if ( 13 != bin2dec( pUid40s, uid40, 5 ) )
		return -1;			// binary to decimal digit conversion error
		
	return 0;
}


/* EOF */
