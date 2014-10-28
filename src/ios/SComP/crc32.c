#include "crc32.h"


static uint32_t crc_tab[256];
static int crc_tab_isinit = 0;
static uint32_t crc_poly = 0xEDB88320L;


static void crc32inittab( void )
{
	uint32_t crc;
	int i, j;

	for ( i = 0; i < 256; i++ )
	{
		crc = i;
		for ( j = 8; j > 0; j-- )
		{
			if ( crc & 1 )
				crc = ( crc >> 1 ) ^ crc_poly;
			else
				crc >>= 1;
		}
		crc_tab[i] = crc;
	}
	crc_tab_isinit = 1;
}

void crc32_init( crc32_t *pcrc )
{
	if ( !crc_tab_isinit )
		crc32inittab();
	*pcrc = 0xFFFFFFFFL;
}

void crc32_final( crc32_t *pcrc )
{
	*pcrc ^= 0xFFFFFFFFL;
}

void crc32_update( crc32_t *pcrc, uint8_t *data, size_t size )
{
   while ( size-- )
      *pcrc = ( *pcrc >> 8 ) ^ crc_tab[ ( *pcrc ^ *data++ ) & 0xFF ];
}

crc32_t crc32_calc( uint8_t *data, size_t size )
{
   crc32_t crc;
   crc32_init( &crc );
   crc32_update( &crc, data, size );
   crc32_final( &crc );
   return crc;
}

/* EOF */
