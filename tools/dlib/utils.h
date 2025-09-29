/*  UTILS.H -- Header for the utility functions
 *
 *  Copyright (C) by Alef Null 1992-1995
 *  Author(s): Jarkko Vuori, OH2LNS
 *	       Rob Janssen,  PE1CHL
 *  Modification(s):
 */

#define MAX_FILES   2

#ifndef _MAX_PATH
#define _MAX_PATH   1024
#endif

#ifndef max
#define max(a,b)    ((a) > (b) ? (a) : (b))
#endif

typedef enum { True = -1, False = 0 } Bool;

typedef enum {
    p = 0x01,	// bit 0: data/pgm
    x = 0x00,	// bit 1: x/y
    y = 0x02
} DATASPACE;

typedef struct {
    unsigned	year:7;
    unsigned	month:4;
    unsigned	day:5;
} DATE;

typedef enum { Modify, ReadOnly, Last } FileMode;

typedef Bool (cdecl *Operation)(FILE *files[], ...);

typedef struct {
    unsigned char  space;
    unsigned short address,
		   len;
} BLKHEADER;

typedef struct {
    char       cmd;
    Bool       numericArgument, fDescription;
    char      *usage;
    FileMode   fileModes[MAX_FILES+1];
    char      *extension[MAX_FILES];
    Operation  operation;
} CMDS;

unsigned  crc(unsigned char *blk, unsigned len);
char	 *AddExtension(char *FileName, char *Extension);
char	 *dateStr(DATE date);
int	  ParseCommands(int argc, char *argv[], CMDS *cmds, int cmdcount, int desc_len, void (*usage)(void));
Bool	  ReadBlocks(FILE *fp, Bool (*block)(BLKHEADER *pHeader, long huge *data));
