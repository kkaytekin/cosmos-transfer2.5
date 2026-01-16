/*
 * GLIBC Symbol Wrapper for pow, log2, and powf
 * Provides GLIBC_2.27 and GLIBC_2.29 versioned symbols
 */

#include <math.h>

/* Wrapper functions */
double __pow_wrapper(double x, double y) {
    return pow(x, y);
}

double __log2_wrapper(double x) {
    return log2(x);
}

float __powf_wrapper(float x, float y) {
    return powf(x, y);
}

/* Create aliases */
asm(".globl pow");
asm(".set pow, __pow_wrapper");
asm(".globl log2");
asm(".set log2, __log2_wrapper");
asm(".globl powf");
asm(".set powf, __powf_wrapper");
