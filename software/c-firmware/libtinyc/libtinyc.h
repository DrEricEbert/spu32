#ifndef TINYLIB
#define TINYLIB

void printf_c(char c);
void printf_s(char* s);
void printf_d(int i);
void printf(const char* format, ...);

char *fgets(char *str, int n, void *stream);

#endif
