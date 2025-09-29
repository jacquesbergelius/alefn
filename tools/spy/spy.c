/*  SPY.C -- Show data
 *
 *  Copyright (C) 1991-1995 by Alef Null. All rights reserved.
 *  Author(s): Jarkko Vuori  (OH2LNS)
 *	       Craig  Newell (VK4YEQ)
 *  Modification(s):
 */


#include <stdio.h>
#include <values.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <conio.h>
#include <ctype.h>
#include "spy.h"
#include "dsply.h"
#include "fft.h"
#include "serial.h"


#define N	    512     // number of horisontal lines
#define LOGN	    9	    // log2(N)
#define STEP	    8

#define PORT	    1	    // default serial port number
#define BAUD	    19200   // baud rate

#define EXT   	    "DAT"   // file's extension


static struct {
    unsigned ctrlC:1;
    unsigned reso:1;
    unsigned cont:1;
    unsigned fft:1;
    unsigned fix:1;
} flags;

typedef struct {
    int      max, min;
    Bool     fComplex;
    double   fs;
    COMPLEX *cp, data[N];
} SAMPLES;


/*
 * CTRL-C handler
 */
void cdecl CtrlCHandler(void) {
    flags.ctrlC = 1;
    signal(SIGINT, CtrlCHandler);
}


static char *AddExtension(char *FileName, char *Extension) {
    static char Name[13];
    char        *s;
    
    s = Name;
    while(*FileName && *FileName != '.')
	*s++ = *FileName++;
        
    if(*FileName)
	while((*s++ = *FileName++) != NULL);
    else {
	*s++ = '.';
    
	while((*s++ = *Extension++) != NULL);
    }
    
    return(Name);
}


/*
 * Wait (max 3s) for a character from the serial port
 *
 *  returns -1 if there is no character
 */
static int ReadSerialLine(void) {
    unsigned long start;
    int 	  c;

    #define BIOS_TIMER (volatile unsigned long far *)(0x46c)

    /* wait until timer changes its state */
    start = *BIOS_TIMER;
    while (start+54L != *BIOS_TIMER)	 // 54.9ms*54=3s
	if ((c = ReadSerial()) != -1)
	    return (c);

    return (-1);
}


/*
 * Read samples from the DSP CARD 4
 */
static Bool ReadSamples(Bool *fComplex, double *fs, COMPLEX *frame) {
    int      c;
    COMPLEX *p;
    static double rates[] = {8e3, 16e3, 27.42857e3, 32e3, 0e3, 0e3, 48e3, 9.6e3};

    WriteSerial('S');

    /* wait for the block header */
    if (ReadSerialLine() == 'P') {
	/* parse control byte */
	if ((c = ReadSerialLine()) == -1)
	    return (False);

	*fComplex = c & 0x80;
	*fs	  = rates[c & 0x7];

	/* then data */
	if (*fComplex)
	    for (p = frame; p < &frame[512]; p++) {
		if ((p->x = ReadSerialLine()) == -1)
		    return (False);

		if ((c = ReadSerialLine()) == -1)
		    return (False);
		else
		    p->x |= (c<<8);

		if ((p->y = ReadSerialLine()) == -1)
		    return (False);

		if ((c = ReadSerialLine()) == -1)
		    return (False);
		else
		    p->y |= (c<<8);
	    }
	else
	    for (p = frame; p < &frame[512]; p++) {
		if ((p->x = ReadSerialLine()) == -1)
		    return (False);

		if ((c = ReadSerialLine()) == -1)
		    return (False);
		else
		    p->x |= (c<<8);

	    }

	return (True);
    }

    return (False);
}


static Bool nextl(FILE *fd, long *data) {
    int  c;
    char buff[80], *p;

    /* first flush leading space out */
    p = buff;
    while (c = getc(fd), !isdigit(c) && c != '-' && c != EOF);
    *p++ = c;
    if (c == EOF) return (False);

    /* then get the main body of the character */
    while (c = getc(fd), c != EOF && (isdigit(c) || c == '-'))
	*p++ = c;

    *p = '\0';

    *data = atol(buff) > 8388608L ? atol(buff)-16777216L : atol(buff);

    return (True);
}


/*
 * Reads one frame from the given file
 */
static Bool readFile(char *name, COMPLEX *frame) {
    FILE    *fp;
    long     d;
    COMPLEX *p;

    if ((fp = fopen(name, "r")) == NULL)
	return (False);

    p = frame;
    while (p < &frame[N])
	if (nextl(fp, &d))
	    p++->x = (int)d;
	else {
	    fclose(fp);
	    return (False);
	}

    fclose(fp);
    return (True);
}


/*
 * Writes one frame to the given file
 */
static Bool writeFile(char *name, COMPLEX *frame) {
    FILE    *fp;
    COMPLEX *p;

    if ((fp = fopen(name, "w")) == NULL)
	return (False);

    p = frame;
    while (p < &frame[N]) {
	fprintf(fp, "%d\n", p->x);
	p++;
    }

    fclose(fp);
    return (True);
}


/*
 * Search max and min values
 */
void searchMinMax(SAMPLES *s) {
    COMPLEX *p;

    s->min =  MAXINT;
    s->max = -MAXINT;

    for (p = s->data; p < &(s->data[N]); p++) {
	s->min = min(s->min, s->fComplex ? min(p->x, p->y) : p->x);
	s->max = max(s->max, s->fComplex ? max(p->x, p->y) : p->x);
    }
}


/*
 * Calculate spectrum of the given data block
 */
void spectrum(SAMPLES *s) {
    struct complex tmp[N];
    int            i;

    /* first transform windowed input samples */
    HanningWin(tmp, s->data, LOGN);
    fft(tmp, LOGN);

    /* then calculate the logarithm of the power */
    for (i = 0; i < N; i++)
	s->data[i].x = (int)(10.0*log10(
		       tmp[Bit_Reverse(i, LOGN)].x*tmp[Bit_Reverse(i, LOGN)].x+
		       tmp[Bit_Reverse(i, LOGN)].y*tmp[Bit_Reverse(i, LOGN)].y)+.5);
}


/*
 * Plot given block
 */
static void plotSamples(SAMPLES *s) {
    PlotStart(s->min, s->max);
    LabelAxis(s->max, s->min, (s->cp - s->data) + (flags.reso ? N/STEP : N), s->cp - s->data);
    PlotSamples(flags.reso ? N/STEP : N, s->fComplex, s->cp);
}


int cdecl main(int argc, char *argv[]) {
    static char *logo[] = {
	"Alef Null DSP CARD 4 SPY (" __DATE__ ")",
	" ",
	"R  Read Samples        W  Write Samples      ",
	"<  Prev Sample         >  Next Sample        ",
	"S  Get New Samples     X  Fix Y scale at Max ",
	"T  Toggle Coarse Mode  C  Toggle Continous   ",
	"F  Toggle FFT Mode     Q  Exit SPY           ",
	NULL
    };
    static SAMPLES  samples;
    int 	    port = PORT;
    char	   *filename = "LOG", option;

    /* first parse arguments */
    argc--; argv++;
    while(argc > 0) {
	switch(**argv) {
	case '-':
	    switch(option = *(++(*argv))) {
	    /* port selection */
	    case 'p':
	    case 'P':
		port = atoi(++(*argv));
		break;

	    default:
		fprintf(stderr, "unknown option '%c', type 'spy ?' to get the allowed options\n", option);
		break;
	    }
	    break;

	case '?':
	    fprintf(stderr, "usage: spy [-p<portno>]\n");
	    fprintf(stderr, "\t-p<portno> uses the specified (1 (default) or 2) serial port\n");
	    return (0);

	default:
	    filename = *argv;
	    break;
	}

	argc--; argv++;
    }

    /* then open serial line */
    signal(SIGINT, CtrlCHandler);
    if (!OpenSerial(port, BAUD)) {
	fprintf(stderr, "can't open serial port COM%d\n", port);
	return (1);
    }

    /* open graphic display */
    if (InitDisplay(N, logo)) {
	fprintf(stderr, "%s: no support for the needed graphics device (VGA)\n", __FILE__);
	CloseSerial();
	return (1);
    }

    /* try to show default file at the first */
    samples.cp	     = samples.data;
    samples.fComplex = False;
    if (readFile(AddExtension(filename, EXT), samples.data) == True) {
	searchMinMax(&samples);
	plotSamples(&samples);
    }

    /* finally obey user instructions */
    while (True) {
	/* terminate if user is in panic */
	if (flags.ctrlC)
	    goto end;

	/* if key pressed, obey the given command */
	if (kbhit())
	    switch (toupper(getch())) {
	    case 'R':
		if (readFile(AddExtension(filename, EXT), samples.data) == True) {
		    samples.fComplex = False;
		    if (flags.fft)
			spectrum(&samples);

		    searchMinMax(&samples);
		    plotSamples(&samples);
		} else
		    putchar('\x7');
		break;

	    case 'W':
		if (writeFile(AddExtension(filename, EXT), samples.data) == False)
		    putchar('\x7');
		break;

	    case 'S':
		if (ReadSamples(&samples.fComplex, &samples.fs, samples.data) == True) {
		    if (flags.fft)
			spectrum(&samples);

		    if (!flags.fix)
			searchMinMax(&samples);
		    plotSamples(&samples);
		} else
		    putchar('\x7');
		break;

	    case '>':
goright:	samples.cp = min(&samples.data[N-(flags.reso ? N/STEP : N)], samples.cp+(flags.reso ? N/STEP : N));
		plotSamples(&samples);
		break;

	    case '<':
goleft: 	samples.cp = max(samples.data, samples.cp-(flags.reso ? N/STEP : N));
		plotSamples(&samples);
		break;

	    case 'T':
		flags.reso = !flags.reso;
		if (samples.cp + N > &samples.data[N])
		    samples.cp = max(samples.data, &samples.data[N] - N);
		plotSamples(&samples);
		break;

	    case 'C':
		flags.cont = !flags.cont;
		break;

	    case 'X':
		flags.fix = !flags.fix;
                if (flags.fix) {
                   if (flags.fft) {
                      samples.min = 0;
                      samples.max = 127;
                   } else {
                      samples.min = -MAXINT;
		      samples.max =  MAXINT;
                   }
                } else {
                   searchMinMax(&samples);
                }
                plotSamples(&samples);
		break;

	    case 'F':
		flags.fft = !flags.fft;
		if (flags.fft) {
		    spectrum(&samples);
		    searchMinMax(&samples);
		    plotSamples(&samples);
		}
		break;

	    case 'Q':
	    case 27:	// ESC
	    case '.':
		goto end;
		break;

            /* handle extended key codes (arrows extra) */
            case 0:
		switch (getch()) {
		    case 75:  goto goleft;
		    case 77:  goto goright;
		}
		break;

	    default:
		putchar('\x7');
		break;
	    }

	/* continuously sample if in continuous mode */
	if (flags.cont)
	    if (ReadSamples(&samples.fComplex, &samples.fs, samples.data) == True) {
		if (flags.fft)
		    spectrum(&samples);

		if (!flags.fix)
		    searchMinMax(&samples);

		plotSamples(&samples);
	    } else {
		putchar('\x7');
		flags.cont = 0;
	    }
    }

end:
    ReleaseDisplay();
    CloseSerial();
    return (0);
}
