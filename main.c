#include <stdio.h>

int MyPrintf (char* s, ...);

int main() {
    MyPrintf ("I love %x and %d %s\n", 3802, 1234, "chocolates");
    return 0;
}
