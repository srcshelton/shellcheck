#include <stdio.h>
#include <string.h>
extern const char *mipspro_assembly_string(void);
int main(void)
{
    static const unsigned char expected[] =
        {97,92,110,92,117,50,48,97,99,92,117,68,56,51,68,92,117,68,69,48,48,0};
    const char *actual = mipspro_assembly_string();
    if (strlen(actual) != sizeof expected - 1 ||
        memcmp(actual, expected, sizeof expected) != 0) {
        fputs("FAIL MIPSpro assembly string bytes\n", stderr);
        return 1;
    }
    puts("PASS MIPSpro assembly preserves backslash-ended comment and following bytes");
    return 0;
}
