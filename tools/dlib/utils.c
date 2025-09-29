/*  UTILS.C -- Various utilities for DLIB and DL
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
#include <ctype.h>
#ifndef __linux__
#include <dos.h>
#endif
#include "utils.h"

#if defined(__TURBOC__)
    #undef  halloc
    #define halloc(a, b)    farcalloc(a, b)
    #undef  hfree
    #define hfree(a)	    farfree(a)
#endif
#if defined(__linux__)
    #undef  halloc
    #define halloc(a, b)    calloc(a, b)
    #undef  hfree
    #define hfree(a)	    free(a)
#endif

/*
 * Calculate CCITT (HDLC, X25) CRC
 */
unsigned crc(unsigned char *blk, unsigned len) {
    const unsigned poly = 0x8408;   // x^16+x^12+x^5+1

    register unsigned	    result;
    register unsigned char  ch;
    int 		    i;
    unsigned char	   *p;

    result = 0xffff;
    for (p = blk; p < blk+len; p++) {
	ch = *p;
	for (i = 0; i < 8; i++) {
	    if ((result^ch) & 0x001) {
		result >>= 1;
		result ^= poly;
	    } else
		result >>= 1;
	    ch >>= 1;
	}
    }

    return (result);
}


/*
 * Add extension to the filename
 */
char *AddExtension(char *FileName, char *Extension) {
    static char  Name[_MAX_PATH];
    char	*s1;

    /* copy basename */
    s1 = Name;
    while(*FileName && *FileName != '.')
        *s1++ = *FileName++;

    /* copy extension (if there are already no extension) */
    strcpy(s1, !*FileName ? Extension : FileName);

    return(Name);
}


/*
 *  Return ASCII date string from the internal MSDOS-format
 */
char *dateStr(DATE date) {
#ifndef __linux__
    struct {
	int   co_date;	    // date format
	char  co_curr[5];   // currency symbol
	char  co_thsep[2];  // thousands separator
	char  co_desep[2];  // decimal separator
	char  co_dtsep[2];  // date separator
	char  co_tmsep[2];  // time separator
	char  co_currstyle; // currency style
	char  co_digits;    // significant digits in currency
	char  co_time;	    // time format
	long  co_case;	    // case map
	char  co_dasep[2];  // data separator
	char  co_fill[10];  // filler
    } country_info;
#endif
    static char result[10+1];

#ifdef __linux__
    /* fixed output format, sorry... */
    sprintf(result, "%02d-%02d-%04d", date.day, date.month+1, date.year+1900);
#else
    /* first obtain the current output format */
    bdos(0x38, (unsigned)&country_info, 0x00);

    /* finally formulate date using correct format */
    switch (country_info.co_date) {
    case 0: // USA
	sprintf(result, "%02d%s%02d%s%04d", date.month+1, country_info.co_dtsep, date.day, country_info.co_dtsep, date.year+1900);
	break;

    case 1: // Europe
    default:
	sprintf(result, "%02d%s%02d%s%04d", date.day, country_info.co_dtsep, date.month+1, country_info.co_dtsep, date.year+1900);
	break;

    case 2: // Japan
	sprintf(result, "%04d%s%02d%s%02d", date.year+1900, country_info.co_dtsep, date.month+1, country_info.co_dtsep, date.day);
	break;
    }
#endif

    return (result);
}


/*
 * Parse and execute command line options
 *
 *  returns zero if everything is ok
 *	    nonzero otherwise
 */
int ParseCommands(int argc, char *argv[], CMDS *cmds, int cmdcount, int desc_len, void (*usage)(void)) {
    FILE *files[MAX_FILES];
    CMDS *p;
    int   i, numArg = 0;
    char  description[256];

    /* check that we have at least some arguments */
    if (argc--, argv++, !argc) {
	usage();
	return (-1);
    }

    /* then parse arguments */
    while (argc)
	switch (argc, **argv) {
	case '-':
	    /* was command mark, search for that command */
	    ++(*argv);
	    for (p = cmds; p < &cmds[cmdcount]; p++)
		if (toupper(**argv) == p->cmd) {
		    /* given command was legal check if we need numeric argument */
		    if (p->numericArgument)
			if (isdigit(*(++(*argv))))
			    numArg = atoi(*argv);
			else {
			    fprintf(stderr, "numeric argument must be given\n");
			    return (-1);
			}

		    argc--; argv++;

		    /* then open necessary files */
		    for (i = 0; p->fileModes[i] != Last; i++) {
			if (!argc) {
			    usage();
			    return (-1);
			}

			switch (p->fileModes[i]) {
			case Modify:
			    if ((files[i] = fopen(AddExtension(*argv, p->extension[i]), "rb+")) == NULL)
				if ((files[i] = fopen(AddExtension(*argv, p->extension[i]), "wb+")) == NULL) {
				    fprintf(stderr, "can't create file '%s'\n", *argv);
				    return (-1);
				}
			    setvbuf(files[i], NULL, _IOFBF, 8192);
			    break;

			case ReadOnly:
			    if ((files[i] = fopen(AddExtension(*argv, p->extension[i]), "rb")) == NULL) {
				fprintf(stderr, "can't open file '%s'\n", *argv);
				return (-1);
			    }
			    setvbuf(files[i], NULL, _IOFBF, 8192);
			    break;

			default:
			    break;
			}

			argc--; argv++;
		    }

		    /* then fetch remaining comments */
		    *description = '\0';
		    if (p->fDescription) {
			while (argc) {
			    if (strlen(description)+strlen(*argv) > desc_len) {
				fprintf(stderr, "given comment too long\n");
				return (-1);
			    }
			    strcat(description, *argv); strcat(description, " ");

			    argv++, argc--;
			}
			if (*description)
			    description[strlen(description)-1] = '\0';
		    }

		    /* and finally execute the given command */
		    if (p->operation) {
			if (!(*p->operation)(files, numArg, description))
			    return (-1);
		    } else
			fprintf(stderr, "not yet implemented\n");

		    break;
		}

	    /* check if we found any legal commands */
	    if (p == &cmds[cmdcount]) {
		usage();
		return (-1);
	    }
	    break;

	case '?':
	    usage();
	    return (0);

	default:
	    usage();
	    return (-1);
	}

    return (0);
}


/* read next token from input */
static char *ReadToken(FILE *fd) {
    static char line[80];
    char c, *p;

    #define WHITESPACE(x) ((x) == ' ' || (x) == '\t' || (x) == '\r' || (x) == '\n')

    /* flush leading whitespace out */
    do {
	fread(&c, 1, 1, fd);
    } while (WHITESPACE(c) && !feof(fd));

    /* then read next token */
    p = line;
    while (p < &line[80] && !feof(fd) && !WHITESPACE(c)) {
	*p++ = c;
	fread(&c, 1, 1, fd);
    }
    *p = '\0';

    return (line);
}

/* convert ASCII-Hex argument to long number */
static long HexToLong(char *data) {
    long val;

    sscanf(data, "%lX", &val);

    return (val);
}

/* Read next word from LNK56000 output file */
static int ReadWord(FILE *fd, unsigned char *space, unsigned short *address, long *word) {
    static unsigned char currentspace;
    static Bool 	 longspace;
    static unsigned short currentaddress;
    static enum {
	ignore, spaceheader, collectdata
    }		     state = ignore;
    char	    *token;

    while (True) {
	token = ReadToken(fd);

	if (strlen(token) == 0) {
	    fprintf(stderr, "rdlod error: inputfile too short or no _END record, not a valid Motorola load file\n");
	    return (-1);
	}

	if (*token == '_') {
	    if (!strcmp(token, "_END"))
		return (1);

	    else if (!strcmp(token, "_DATA"))
		state = spaceheader;

	    else if (!strcmp(token, "_START") || !strcmp(token, "_SYMBOL"))
		state = ignore;
	    else {
		fprintf(stderr, "rdlod error: unknown record '%s'\n", token);
		return (-1);
	    }
	}

	switch (state) {
	case ignore:
	    /* ignore this record */
	    break;

	case spaceheader:
	    /* data space header */
	    switch (*ReadToken(fd)) {
	    case 'P': currentspace = p; longspace = False; break;
	    case 'L': currentspace = x; longspace = True;  break;
	    case 'X': currentspace = x; longspace = False; break;
	    case 'Y': currentspace = y; longspace = False; break;
	    default:
		fprintf(stderr, "rdlod error: illegal data space, not a valid Motorola load file\n");
		return (-1);
	    }

	    currentaddress = (unsigned)HexToLong(ReadToken(fd));

	    state = collectdata;
	    break;

	case collectdata:
	    /* read next data */
	    *space   = currentspace;
	    *address = currentaddress;
	    *word    = HexToLong(token);

	    if (longspace) {
		/* fill x and y spaces from l space */
		if (currentspace == x)
		    currentspace = y;
		else {
		    currentspace = x;
		    currentaddress++;
		}
	    } else
		currentaddress++;

	    return (0);
	}
    }
}


/*
 * Reads consecutive memory blocks from the LNK56000 output file
 */
Bool ReadBlocks(FILE *fp, Bool (*block)(BLKHEADER *pHeader, long huge *data)) {
    static struct {
	char	  *name;
	unsigned short words,
		   maxaddress;
	long huge *data;
	Bool huge *touched;
    } memspaces[3] = {
	/* normal program */
	{ "X", 0, 0x1fff, },
	{ "P", 0, 0x1fff, },
	{ "Y", 0, 0x3fff, }
    };
    BLKHEADER header;
    long      word;
    unsigned  i;
    int       result;
    Bool      fResult = True, fHunt;

    /* first allocate space for loadable data */
    for (header.space = x; header.space <= y; header.space++)
	if (
	    (memspaces[header.space].data    = halloc((long)memspaces[header.space].maxaddress+1, sizeof(long))) == NULL ||
	    (memspaces[header.space].touched = halloc((long)memspaces[header.space].maxaddress+1, sizeof(Bool))) == NULL
	) {
	    fprintf(stderr, "loader error: not enought memory\n");
	    fResult = False; goto endload;
	}

    /* read program from file to memspaces */
    while (!(result = ReadWord(fp, &header.space, &header.address, &word))) {
	if (header.address > memspaces[header.space].maxaddress) {
	    fprintf(stderr, "loader error: too big %s header.space, allowed range %04XH-%04XH\n", memspaces[header.space].name, 0, memspaces[header.space].maxaddress);
	    fResult = False; goto endload;
	}

	memspaces[header.space].data[header.address]	= word;
	memspaces[header.space].words			= max(memspaces[header.space].words, header.address+1);
	memspaces[header.space].touched[header.address] = True;
    }
    if (result < 0) {
	fResult = False; goto endload;
    }

    for (header.space = x; header.space <= y; header.space++) {
	/* search for continuous blocks */
	fHunt = True;
	for (i = 0; i < memspaces[header.space].maxaddress; i++)
	    if (fHunt) {
		if (memspaces[header.space].touched[i]) {
		    /* start of data found */
		    fHunt	   = False;
		    header.address = i;
		}
	    } else {
		if (!memspaces[header.space].touched[i]) {
		    /* end of data found */
		    fHunt      = True;
		    header.len = i-header.address;
		    if (!(*block)(&header, &memspaces[header.space].data[header.address])) {
			fResult = False; goto endload;
		    }
		}
	    }
	if (!fHunt) {
	    header.len = i-header.address;
	    if (!(*block)(&header, &memspaces[header.space].data[header.address])) {
		fResult = False; goto endload;
	    }
	}
    }

endload:
    for (header.space = x; header.space <= y; header.space++) {
	hfree(memspaces[header.space].data); hfree(memspaces[header.space].touched);
    }

    return (fResult);
}
