/*
 * FFT.H -- Header for Fourier transform module
 *
 *  Copyright (C) 1988-1994 by Alef Null. All rights reserved.
 *  Author(s): J Vuori
 *
 *  Modification(s):
 */


void DirectWin(struct complex *dest, int *src, int n);
void HanningWin(struct complex *dest, COMPLEX *src, int n);
void HammingWin(struct complex *dest, int *src, int n);
void BlackmanWin(struct complex *dest, int *src, int n);
void fft(struct complex x[], int m);
int  Bit_Reverse(int i, int n);
