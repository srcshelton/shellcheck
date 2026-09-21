#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
extern void _hs_text_memcpy(void *, size_t, const void *, size_t, size_t);
extern int _hs_text_memcmp(const void *, size_t, const void *, size_t, size_t);
int main(void)
{
    uint16_t source[] = {1, 0x1234, 0xabcd, 4};
    uint16_t dest[] = {9, 9, 9, 9, 9};
    uint16_t expected[] = {9, 0x1234, 0xabcd, 9, 9};
    _hs_text_memcpy(dest, 1, source, 1, 2);
    if (memcmp(dest, expected, sizeof dest) != 0) return 1;
    if (_hs_text_memcmp(dest, 1, source, 1, 2) != 0) return 2;
    if (_hs_text_memcmp(dest, 0, source, 0, 4) == 0) return 3;
    _hs_text_memcpy(dest, 3, source, 2, 0);
    if (memcmp(dest, expected, sizeof dest) != 0) return 4;
    if (_hs_text_memcmp(dest, 3, source, 2, 0) != 0) return 5;
    puts("PASS text memory offsets, zero length and guard words");
    return 0;
}
