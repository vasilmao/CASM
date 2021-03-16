#include <stdio.h>

int MyPrintf (char* s, ...);

int main() {
    MyPrintf ("I %s %x %d%%%c%b\n", "love", 3802, 100, 33, 255);
    return 0;
}
