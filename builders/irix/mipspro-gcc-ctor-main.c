/* Compile/link with the MIPSpro adapter and the seed-GCC fixture object. */
#include <stdio.h>
int mixed_ctor_state;
int main(void)
{
    if (mixed_ctor_state != 42) {
        puts("FAIL GCC constructor was not called before MIPSpro main");
        return 1;
    }
    mixed_ctor_state = 43;
    puts("PASS GCC constructor called before MIPSpro main");
    return 0;
}
