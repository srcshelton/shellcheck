extern int armv6_llvm_answer(void);
int main(void) {
    return armv6_llvm_answer() == 42 ? 0 : 1;
}
