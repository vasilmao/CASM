nasm -f elf64 -l myprintf.lst myprintf.s
gcc main.c myprintf.o -no-pie
