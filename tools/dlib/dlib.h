/*  DLIB.H -- Header for the DSP CARD 4 ROM Library manager
 *
 *  Copyright (C) by Alef Null 1992, 1993, 1994
 *  Author(s): Jarkko Vuori, OH2LNS
 *	       Rob Janssen,  PE1CHL
 *  Modification(s):
 */


#define DIR_ENTRIES 16
#define CHECK_ID    0x564a
#define DESC_LEN    10

typedef struct {
    unsigned short	adr;
    unsigned short	len;
    char		description[DESC_LEN];
    unsigned short	date;
} ROMDIR;


/* DLIBCMD.C */
Bool cdecl replace(FILE *files[], int numArg, char *comment);
Bool cdecl bootimage(FILE *files[], int numArg, char *comment);
Bool cdecl list(FILE *files[]);
Bool cdecl autoboot(FILE *files[], int numArg);
