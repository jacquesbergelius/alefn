/*  FFT.C - Fast Fourier Transfom Pagage
 *
 *  Copyright (C) 1988-1994 by Alef Null. All rights reserved.
 *  Author(s): J Vuori
 *  Modification(s):
 */

#include <math.h>
#include "spy.h"
#include "fft.h"


/*
 * Direct (Window)
 *
 * dest - pointer to complex array receiving the result
 * src	- pointer to double array to be windowed
 * n	- lenght of made transform (in form 2^m)
 */
void DirectWin(struct complex *dest, int *src, int n) {
    struct complex *d;
    int   	   *s;
    int 	    i, m;

    m = (1 << n);
    s = src; d = dest;
    for(i = 0; i < m; i++) {
	d->x = (double)*s;
	d->y = 0.0;
	s++; d++;
    }
}


/*
 * Hanning Window
 *
 * dest - pointer to complex array receiving the result
 * src	- pointer to double array to be windowed
 * n	- lenght of made transform (in form 2^m)
 */
void HanningWin(struct complex *dest, COMPLEX *src, int n) {
    struct complex *d;
    COMPLEX	   *s;
    int 	    i, m;

    m = (1 << n);
    s = src; d = dest;
    for(i = 0; i < m; i++) {
	d->x = 0.5 * (1 - cos(2 * M_PI * (i + 0.5) / m)) * (double)s->x;
	d->y = 0.0;
	s++; d++;
    }
}


/*
 * Hamming Window
 *
 * dest - pointer to complex array receiving the result
 * src	- pointer to double array to be windowed
 * n	- lenght of made transform (in form 2^m)
 */
void HammingWin(struct complex *dest, int *src, int n) {
    struct complex *d;
    int      	   *s;
    int 	    i, m;

    m = (1 << n);
    s = src; d = dest;
    for(i = 0; i < m; i++) {
	d->x = (0.54 - 0.46 * cos(2 * M_PI * (i + 0.5) / m)) * (double)*s;
	d->y = 0.0;
	s++; d++;
    }
}


/*
 * Blackman Window
 *
 * dest - pointer to complex array receiving the result
 * src	- pointer to double array to be windowed
 * n	- lenght of made transform (in form 2^m)
 */
void BlackmanWin(struct complex *dest, int *src, int n) {
    struct complex *d;
    int   	   *s;
    int 	    i, m;

    m = (1 << n);
    s = src; d = dest;
    for(i = 0; i < m; i++) {
	d->x = (0.42 - 0.5 * cos(2 * M_PI * (i + 0.5) / (m - 1))) * (double)*s;
	d->y = 0.0;
	s++; d++;
    }
}


/*
 * Fast Fourier Transform
 *
 * x - pointer to complex array, result replaces data that is here
 * m - lenght of data (in form 2^m)
 */
void fft(struct complex x[], int m) {
    register struct complex *a, *b;
    double		     w, dw,
			     c, s,
			     xt, yt;
    int 		     i, j, k,
			     n1, n2;

    n2 = (1 << m);

    for(k = 0; k < m; k++) {
	/* handle all partitions */
	n1 = n2;
	n2 = n2 / 2;

	w  = 0.0;
	dw = (2 * M_PI) / (double) n1;

	for(j = 0; j < n2; j++) {
	    /* handle all nodes */
	    c = cos(w);
	    s = sin(w);

	    for(i = j; i < (1 << m); i += n1) {
		/* basic butterfly (DIF) */
		a = &x[i];
		b = &x[i+n2];

		xt    = a->x - b->x;
		a->x += b->x;
		yt    = a->y - b->y;
		a->y += b->y;

		b->x  = c * xt + s * yt;
		b->y  = c * yt - s * xt;
	    }
	    w += dw;
	}
    }
}


/* Do bit-reversals on fft-result table
 *
 * i - direct index to result table
 * n - lenght of made transform (in form 2^m)
 */
int Bit_Reverse(int i, int n) {
    register int j, k;
    int 	 m;

    m = (1 << n);
    j = 0;

    for(k = 0; k < n; k++) {
	m = m / 2;
	if(i >= m) {
	    j += (1 << k);
	    i -= m;
	}
    }

    return(j);
}
