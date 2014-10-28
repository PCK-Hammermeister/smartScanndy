#ifndef CRC32_H_INCLUDED
#define CRC32_H_INCLUDED

#include <stdlib.h>
#include <inttypes.h>

typedef uint32_t crc32_t;
void crc32_init( crc32_t *pcrc );
void crc32_final( crc32_t *pcrc );
void crc32_update( crc32_t *pcrc, uint8_t *data, size_t size );
crc32_t crc32_calc( uint8_t *data, size_t size );


#endif // CRC32_H_INCLUDED
