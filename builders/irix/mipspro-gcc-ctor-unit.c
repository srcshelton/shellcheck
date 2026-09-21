/* Compile only this fixture with the seed GCC to model its constructor ABI. */
#include <stdio.h>
#include <stdlib.h>
extern int mixed_ctor_state;
static void initialise(void) __attribute__((constructor));
static void finalise(void) __attribute__((destructor));
static void initialise(void) { mixed_ctor_state = 42; }
static void finalise(void)
{
    if (mixed_ctor_state != 43) abort();
    puts("PASS GCC destructor called by MIPSpro-linked executable");
}
