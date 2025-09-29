/*  LSERIAL.C -- Linux Serial Port handler
 *
 *  Copyright (C) by Alef Null 1994
 *  Author(s): R E Janssen (PE1CHL)
 *  Modification(s):
 */


#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <fcntl.h>
#include <termio.h>
#include <sys/ioctl.h>
#include "utils.h"
#include "dl.h"

#undef TRACE			/* define to get hextrace of serial I/O */

static int comport;
static char devname[40];
static struct termios orgmodes;


/*
 * Initializes serial communication
 *
 * enter with:
 *  port - 1 = ttyS0 (COM1), 2 = ttyS1 (COM2), etc
 *
 * returns:
 *  NULL if failed
 */
int OpenSerial(int port, int baud) {
    struct termios termio;

    /* convert baudrate */
    switch (baud)
    {
    case 19200:
	baud = B19200;
	break;

    case 9600:
	baud = B9600;
	break;

    default:
	fprintf(stderr,"Invalid baudrate: %d\n",baud);
	break;
    }

    /* construct the devicename, open the port */
    sprintf(devname,"/dev/ttyS%d",port - 1);

    if ((comport = open(devname,O_RDWR | O_NDELAY)) < 0) {
	perror(devname);
	return 0;
    }

    /* get the termio structure and save it */
    if (ioctl(comport,TCGETS,&termio) < 0) {
	fprintf(stderr,"ioctl TCGETS ");
	perror(devname);
	close(comport);
	return 0;
    }

    orgmodes = termio;

    /* setup port */
    termio.c_iflag = IGNBRK|IGNPAR;
    termio.c_oflag = 0;
    termio.c_cflag = baud|CS8|CREAD|CLOCAL;
    termio.c_lflag = 0;
    memset(termio.c_cc,0,sizeof(termio.c_cc));	/* VMIN=0 VTIME=0 etc */

    /* install the new setup */
    if (ioctl(comport,TCSETSF,&termio) < 0) {
	fprintf(stderr,"ioctl TCSETSF ");
	perror(devname);
	close(comport);
	return 0;
    }

    fcntl(comport,F_SETFL,fcntl(comport,F_GETFL) & ~O_NDELAY);
    return -1;
}


/*
 * Terminates serial communication
 */
void CloseSerial(void) {
    /* restore original modes */
    if (ioctl(comport,TCSETSF,&orgmodes) < 0) {
	fprintf(stderr,"ioctl TCSETSF ");
	perror(devname);
    }
    /* close the port */
    close(comport);
}


/*
 * Reads one character from serial port,
 * returns -1 if there are no characters waiting
 */
int ReadSerial(void) {
    unsigned char c;

    if (read(comport,&c,1) != 1)
	return -1;

#ifdef TRACE
    printf(" <%02x",c);
    fflush(stdout);
#endif
    return c;
}


/*
 * Writes one character to serial port
 */
int WriteSerial(int c) {
    unsigned char ch;

    ch = c;
#ifdef TRACE
    printf(" >%02x",ch);
    fflush(stdout);
#endif
    write(comport,&ch,1);
    return c;
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
