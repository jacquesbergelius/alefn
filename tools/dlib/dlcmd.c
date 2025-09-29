/*  DLCMD.C -- Commands for DSP CARD 4 downloader
 *
 *  Copyright (C) by Alef Null 1992-1995
 *  Author(s): Jarkko Vuori, OH2LNS
 *	       Rob Janssen,  PE1CHL
 *  Modification(s):
 */


#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include "utils.h"
#include "dl.h"


#define RETRIES 3	// number of retries after error
#define BAUD	19200	// serial port baud rate


static int port = 1;

typedef enum {
    PGM_FLASH,	// commands to DSP CARD
    CHG_PGM,
    READ_FLASH,
    LOAD_GO,

    ACK,	// responses
    BAD_CRC,
    NO_FLASH,
    ERASE_ERR,
    PGM_ERR,
    NO_PGM,

    RESET	// not a command, internally used only
} CardCommand;

const unsigned long wakeUp = 314159265L;// special wake-up sequence
const unsigned char flag   = 0x7e;	// msgblock flag byte (01111110)


/*
 * Wait (max 3s) for a character from the serial port
 *
 *  returns -1 if there is no character
 */
static int WaitSerial(void) {
    unsigned long start;
    int 	  c;

#ifdef __linux__
    start = time(NULL);
    while (start+3 > time(NULL))	 // resolution is 1 second
#else
    #define BIOS_TIMER (volatile unsigned long far *)(0x46c)

    /* wait until timer changes its state */
    start = *BIOS_TIMER;
    while (start+54L != *BIOS_TIMER)	 // 54.9ms*54=3s
#endif
	if ((c = ReadSerial()) != -1)
	    return (c);

    return (-1);
}


/*
 * Wait for ACK from the DSP CARD 4
 */
static Bool waitAck(char *errortext[]) {
    static char *errtxt[] = {
	"Transmission error (Bad CRC or missing characters)",
	"No FLASH EPROM chip on the board",
	"FLASH EPROM erase error",
	"FLASH EPROM program error",
	"No such program"
    };
    static char unknownerr[80];
    int 	c;

    if ((c = WaitSerial()) == -1) {
	*errortext = "No response from the DSP CARD 4";
	return (False);
    }
    if (c != ACK) {
	if (c >= BAD_CRC && c < BAD_CRC+sizeof(errtxt)/sizeof(char *))
	    *errortext = errtxt[c-BAD_CRC];
	else {
	    sprintf(unknownerr, "Unknown error code %d from the DSP CARD 4", c);
	    *errortext = unknownerr;
	}

	return (False);
    }

    return (True);
}


/*
 * Reset DSP CARD 4 and give a command to it
 *
 *  date will contain the version number of the monitor
 *  returns True if operation was succesfull
 */
static Bool giveCommand(CardCommand cmd, DATE *date) {
    int   c, retryCount = 0;
    char *errortext = "DSP CARD 4 doesn't behave properly";

    /* first wake up DSP CARD */
    while (retryCount++ < RETRIES) {
	while (ReadSerial() != -1); // flush any garbage before possible ack
	WriteSerial((int)(wakeUp >> 24)); WriteSerial((int)(wakeUp >> 16)); WriteSerial((int)(wakeUp >> 8)); WriteSerial((int)wakeUp);
	if (!waitAck(&errortext))
	    continue;

	/* get monitor version */
	if ((c = WaitSerial()) == -1)
	    continue;
	*(unsigned *)date = c << 8;

	if ((c = WaitSerial()) == -1)
	    continue;
	*(unsigned *)date |= c;

	/* when no command, return (just RESET) */
	if (cmd == RESET)
	    return (True);

	/* then send given command */
	WriteSerial(cmd);
	if (waitAck(&errortext))
	    return (True);
    }

    fprintf(stderr, "%s\n", errortext);
    return (False);
}


/*
 * Send one datablock to the DSP CARD 4
 */
static Bool sendBlock(BLKHEADER *pHeader, long huge *data) {
    unsigned char *msg;
    unsigned	   msglen, check;
    int 	   retryCount = 0;
    char	  *errortext;
    const int	   headerLen = (1 + 5) + 2;

    /* first calculate the lenght of messageblock (excluding the last CRC) */
    msglen = headerLen + 3 * pHeader->len;

    /* then setup message block */
    if ((msg = (unsigned char *)malloc(msglen)) != NULL) {
	register long huge     *sp;
	register unsigned char *dp;

	/* first the header */
	dp = msg;
	*dp++ = flag;
	*dp++ = pHeader->space;
	*dp++ = (unsigned char)(pHeader->address >> 8);
	*dp++ = (unsigned char)pHeader->address;
	*dp++ = (unsigned char)(pHeader->len >> 8);
	*dp++ = (unsigned char)pHeader->len;

	/* then the checkword for it */
	check = ~crc((unsigned char *)msg, headerLen - 2);
	*dp++ = (unsigned char)check;
	*dp++ = (unsigned char)(check >> 8);

	/* after that copy the data itself (24-bit words to bytes) */
	for (sp = data; sp < &data[pHeader->len]; sp++) {
	    *dp++ = (unsigned char)(*sp >> 16);
	    *dp++ = (unsigned char)(*sp >> 8);
	    *dp++ = (unsigned char)*sp;
	}

	/* and finally calculate the checkword */
	check = ~crc((unsigned char *)(msg + headerLen), msglen - headerLen);

	/* then send it */
	while (retryCount++ < RETRIES) {
	    for (dp = (unsigned char *)msg; dp < (unsigned char *)msg+msglen; dp++)
		WriteSerial(*dp);
	    if (msglen - headerLen > 0) {
		WriteSerial(check); WriteSerial(check >> 8);
	    }

	    /* then wait for ACK */
	    if (waitAck(&errortext)) {
		free(msg);
		return (True);
	    }
	}

	fprintf(stderr, "%s\n", errortext);
	free(msg);
    }

    return (False);
}


Bool cdecl setport(FILE *files[], int numArg) {
    port = numArg;

    return (True);
}


Bool cdecl loadandgo(FILE *files[]) {
    static BLKHEADER termBlk = { p, 0, 0 };
    DATE	     date;
    Bool	     fResult = True;

#ifndef __linux__
    /* we manipulate interrupt vectors in serial port handler, so ignore ctrl-c */
    signal(SIGINT, (void (cdecl *)())SIG_IGN);
#endif

    if (!OpenSerial(port, BAUD)) {
	fResult = False; goto endload;
    }

    /* then download it to the DSP CARD 4 */
    if (!giveCommand(LOAD_GO, &date) || !ReadBlocks(files[0], sendBlock)) {
	fResult = False; goto endload;
    }

    /* finally start the program execution (by sending len=0 datablock) */
    if (!sendBlock(&termBlk, NULL))
	fResult = False;

endload:
    CloseSerial();
#ifndef __linux__
    signal(SIGINT, SIG_DFL);
#endif

    return (fResult);
}


Bool cdecl program(FILE *files[]) {
    static BLKHEADER termBlk = { p, 0, 0 };
    DATE	     date;
    Bool	     fResult = True;
    FILE	    *perom;
    int		     c,n;

#ifndef __linux__
    /* we manipulate interrupt vectors in serial port handler, so ignore ctrl-c */
    signal(SIGINT, (void (cdecl *)())SIG_IGN);
#endif

    if ((perom = fopen("perom.lod", "rb")) == NULL) {
	fprintf(stderr, "can't open file 'perom.lod'\n");
	return False;
    }
    setvbuf(perom, NULL, _IOFBF, 8192);

    if (!OpenSerial(port, BAUD)) {
	fResult = False; goto endprog;
    }

    printf("Downloading 'perom.lod'\n");

    /* download the PEROM programming routine to the DSP CARD 4 */
    if (!giveCommand(LOAD_GO, &date) || !ReadBlocks(perom, sendBlock)) {
	fResult = False; goto endprog;
    }

    /* start the PEROM program execution (by sending len=0 datablock) */
    if (!sendBlock(&termBlk, NULL)) {
	fResult = False; goto endprog;
    }

    /* wait for the indication that the program started OK */
    if (WaitSerial() != 'G') {
	fprintf(stderr,"No startup indication from 'perom.lod'\n");
	fResult = False; goto endprog;
    }

    printf("Downloading image");
    fflush(stdout);

    /* send the image to the DSP CARD 4 */
    n = 0;
    while ((c = fgetc(files[0])) != EOF) {
	WriteSerial(c);
	if ((++n % 1024) == 0) {
	    printf(".");
	    fflush(stdout);
	}
    }

    printf("\n");

    /* wait for the completion of image transfer (can take awhile) */
    for (n = 0; n < 3; n++)
	if ((c = WaitSerial()) != -1)
	    break;

    if (c == -1) {
	fprintf(stderr,"No response after image download\n");
	fResult = False; goto endprog;
    }

    if (c != 'Y') {
	fprintf(stderr,"Error during image download: %c\n",c);
	fResult = False; goto endprog;
    }

    printf("Image was received OK\n\n");

    do {
	printf("Programming");

	for (n = 0; n < (32768U / 64); n++) {
	    if ((c = WaitSerial()) == -1)
		break;
	    printf("%c",c);
	    fflush(stdout);
	}

	printf("\n");
    }
    while ((c = WaitSerial()) != 'Q');

    printf("Programming completed\n");

endprog:
    CloseSerial();
    fclose(perom);
#ifndef __linux__
    signal(SIGINT, SIG_DFL);
#endif

    return (fResult);
}


Bool cdecl reset(FILE *files[]) {
    Bool fResult = True;
    DATE date;

#ifndef __linux__
    /* we manipulate interrupt vectors in serial port handler, so ignore ctrl-c */
    signal(SIGINT, (void (cdecl *)())SIG_IGN);
#endif

    if (!OpenSerial(port, BAUD)) {
	fResult = False; goto endreset;
    }

    /* RESET the DSP CARD 4 (no command) */
    if (!giveCommand(RESET, &date)) {
	fResult = False; goto endreset;
    }

    printf("Leonid monitor version: %s\n", dateStr(date));

endreset:
    CloseSerial();
#ifndef __linux__
    signal(SIGINT, SIG_DFL);
#endif

    return (fResult);
}
