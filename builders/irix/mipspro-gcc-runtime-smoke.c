/* MIPSpro caller / qualified GCC N32 support archive interoperability. */
#include <stdio.h>
extern int __clzdi2(unsigned long long);
extern int __ctzdi2(unsigned long long);
extern void __clear_cache(char *, char *);
int main(void)
{
    volatile unsigned long long values[] = {
        1ULL, 0x100000000ULL, 0x8000000000000000ULL, 0xf00ULL
    };
    const int leading[] = {63, 31, 0, 52};
    const int trailing[] = {0, 32, 63, 8};
    char cache_range[32] = {0};
    unsigned int i;
    if (sizeof(void *) != 4 || sizeof(unsigned long long) != 8) return 1;
    for (i = 0; i < 4; ++i) {
        if (__clzdi2(values[i]) != leading[i]) return 2;
        if (__ctzdi2(values[i]) != trailing[i]) return 3;
    }
    __clear_cache(cache_range, cache_range + sizeof(cache_range));
    puts("PASS MIPSpro caller/GCC N32 runtime clz64/ctz64/cache helpers");
    return 0;
}
