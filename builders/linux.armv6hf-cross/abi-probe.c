#include <stdint.h>
#include <stdio.h>

double armv6_abi(double a, float b, uint64_t c) {
    return a + b + (double)c;
}

#ifndef HASKELL_FFI
int main(void) {
    volatile double a = 1.25;
    volatile float b = 2.5f;
    volatile uint64_t c = 4294967297ULL;
    if (armv6_abi(a, b, c) != 4294967300.75) return 1;
    puts("PASS ARMv6 C hard-float/64-bit ABI");
    return 0;
}
#endif
