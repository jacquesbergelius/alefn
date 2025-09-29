/*  SERIAL.C -- IBM Serial Port handler (with interrupts)
 *
 *  Copyright (C) 1989,1990,1991 by Alef Null. All rights reserved.
 *  Author(s): J Vuori, E Torsti
 *  Modification(s):
 *	1989-Sep: COM1, COM2 and baud rate selection with
 *		  OpenSerial(int port, int baud)
 *	1991-Apr: DTR line control function added
 */


#define BUFLEN	4096	// buffer lenght


#include <dos.h>
#include <conio.h>
#include <stdlib.h>
#include <malloc.h>
#include <stdio.h>
#include "serial.h"


/* ring buffer definitions */
#define NEXT(p) if (++(p) >= &buffer[BUFLEN]) (p) = buffer
static volatile unsigned char *head, *tail;
static		unsigned char *buffer;


/* i/o-port definitions */
#define PIC_MASK  0x21	// 8259 mask register
#define PIC_EOI   0x20	// 8259 EOI command
static const struct {
    int data,		// 8250 data register
	ier,		//	interrupt enable register
	lcr,		//	line control register
	mcr,		//	modem control register
	stat;		//	status register
    int intno;		// interrupt number
    int mask;		// PIC mask
} *comport, comports[2] = {
    /* COM1 */
    0x3f8, 0x3f9, 0x3fb, 0x3fc, 0x3fd,
    0x0c,
    0x10,

    /* COM2 */
    0x2f8, 0x2f9, 0x2fb, 0x2fc, 0x2fd,
    0x0b,
    0x08,
};


#if defined(__TURBOC__)
    /* store for old interrupt vector */
    static void (interrupt far *OldHandler)(void);

    /*
     * 8250 UART Interrupt server routine
     */
    static void interrupt far ReadChr(void) {
	*head = (unsigned char)inp(comport->data);
	NEXT(head);

	outp(PIC_EOI, 0x20);
    }
#else
    /* store for old interrupt vector */
    static void (interrupt far cdecl *OldHandler)(void);

    #pragma intrinsic(inp, outp)    // produces more beautiful code with this

    /*
     * 8250 UART Interrupt server routine
     */
    #pragma check_stack(off)	    // because stack check is not allowed in interrupt service routine
    static void cdecl interrupt far ReadChr(void) {
	*head = (unsigned char)inp(comport->data);
	NEXT(head);

	outp(PIC_EOI, 0x20);
    }
    #pragma check_stack()
#endif


/*
 * Initializes serial communication
 *
 * enter with:
 *  port - 1 = COM1, 2 = COM2
 *
 * returns:
 *  NULL if failed
 */
int OpenSerial(int port, int baud) {
	comport = &comports[port-1];

    /* allocate receiving buffer */
    if ((buffer = (unsigned char *)malloc(BUFLEN)) != NULL) {
	/* reset buffer */
	head = tail = buffer;

	/* set interrupt vector */
	OldHandler = _dos_getvect(comport->intno);
	_dos_setvect(comport->intno, ReadChr);

	/* set 8250 UART chip */
	SetBaudRate(baud);
	SetDTR(0);
	outp(comport->ier, 0x01);			// enable rec interrupt

	inp(comport->data);				// make UART happy

	/* set 8259 PIC chip */
	outp(PIC_MASK, inp(PIC_MASK) & ~comport->mask); // remove interrupt mask

	return(-1);
    } else
	return(0);
}


/*
 * Terminates serial communication
 */
void CloseSerial(void) {
    /* set 8259 PIC chip */
    outp(PIC_MASK, inp(PIC_MASK) | comport->mask);  // set mask

    /* reset interrupt vector */
    _dos_setvect(comport->intno, OldHandler);

    free(buffer);
}


/*
 * Reads one character from serial port,
 * returns -1 if there are no characters waiting
 */
int ReadSerial(void) {
    register int c;

    if (head != tail) {
	c = *tail;
	NEXT(tail);
	return(c);
    } else
	return(-1);
}


/*
 * Writes one character to serial port
 */
int WriteSerial(int c) {
    while(!(inp(comport->stat) & 0x20));    // wait TBE status

    //printf("%02X ", c & 0xff);
    return(outp(comport->data, c));
}


/*
 * Controls DTR-line
 */
void SetDTR(int state) {
    outp(comport->mcr, state ? 0x0f : 0x0e);
}


/*
 * Controls baud rate
 */
void SetBaudRate(int baud) {
    outp(comport->lcr, 0x83);
    outp(comport->data, (12L*9600L/(long)baud) & 0xff);
    outp(comport->ier,	(12L*9600L/(long)baud) >> 8);
    outp(comport->lcr, 0x03);			    // 8, n, 1
}


/*
 * Check if break condition detected
 */
int IfBreak(void) {
    return (inp(comport->stat) & 0x10);
}


#if defined(DEBUG)
    #include <stdio.h>
    #include <signal.h>

    #define PORT    1
    #define BAUD    9600

    /*
     * CTRL-C handler
     */
    void handler(void) {
	CloseSerial();
	printf("disconnected\n");
	exit(-1);
    }


    int main(void) {
	int c;

	signal(SIGINT, handler);
	if (!OpenSerial(PORT, BAUD)) {
	    fprintf(stderr, "Can't open serial port COM%d\n", PORT);
	    return(-1);
	}

	printf("Simple serial port terminal [COM%1d, %4d] (%s)\n", PORT, BAUD, __DATE__);
	printf("Press CTRL-C to exit\n\n");

	while (1) {
	    while ((c = ReadSerial()) == -1)
		if (kbhit())
		    WriteSerial(getch());

	    putchar(c & 0x7f);
	}

	CloseSerial();
	return(0);
    }
#endif
