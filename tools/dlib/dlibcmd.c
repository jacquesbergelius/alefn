/*  DLIBCMD.C -- Commands for DSP CARD 4 ROM library
 *
 *  Copyright (C) by Alef Null 1992-1995
 *  Author(s): Jarkko Vuori, OH2LNS
 *	       Rob Janssen,  PE1CHL
 *  Modification(s):
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifndef __linux__
#include <dos.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>
#include "utils.h"
#include "dlib.h"

#define LOAD_ADDRESS 0x0000
#define BOOT_ADDRESS 0xC000
#define BOOT_LEN     512
#define BOOT_END     0xD400
#define ROM_BASE     0x8000
#define ROM_LEN      32768U
#define DIR_LEN      (DIR_ENTRIES*sizeof(ROMDIR))
#define CHECK_LEN    sizeof(unsigned short)

struct {
    ROMDIR	   dir[DIR_ENTRIES];
    unsigned char  data[ROM_LEN-DIR_LEN-CHECK_LEN];
    unsigned short check;
} rom;


/*
 * Read ROM image file and check that it is a valid one
 */
static Bool loadROMandCheckValidity(FILE *fp) {
    struct stat  statBuf;

    fstat(fileno(fp), &statBuf);
    if (statBuf.st_size) {
	/* check ROM library file validity */
	fread(&rom, ROM_LEN, 1, fp);
	if (statBuf.st_size != ROM_LEN || rom.dir[0].adr != CHECK_ID) {
	    fprintf(stderr, "illegal ROM library file\n");
	    return (False);
	}
	if (crc((unsigned char *)&rom, sizeof(rom)) != 0xf0b8) {
	    fprintf(stderr, "bad CRC in ROM library file\n");
	    return (False);
	}
    }

    return (True);
}


/*
 * Write ROM image back to the file
 */
static Bool storeROM(FILE *fp) {
    rom.check = ~crc((unsigned char *)&rom, sizeof(rom)-CHECK_LEN);
    fseek(fp, 0L, SEEK_SET); fwrite(&rom, ROM_LEN, 1, fp);

    return (True);
}


/*
 *  Return date string from the directory entry
 */
static char *ROMdateStr(ROMDIR *entry) {
    DATE date;

    memset(&date,0,sizeof(date));
    memcpy(&date,&entry->date,sizeof(entry->date));

    return (dateStr(date));
}


/*
 * Update ROM directory entry
 */
static void updateDirEntry(ROMDIR *entry, unsigned address, unsigned words, char *comment, FILE *fp) {
    struct stat  statBuf;
    struct tm	*mt;
    DATE date;

    /* update pointers to binary data */
    entry->adr = address;
    entry->len = words;

    /* copy the name of the binary image */
    memcpy(entry->description, comment, DESC_LEN);

    /* and finally form the date field */
    fstat(fileno(fp), &statBuf);
    mt = localtime(&statBuf.st_mtime);
    date.year  = mt->tm_year;
    date.month = mt->tm_mon;
    date.day   = mt->tm_mday;
    memcpy(&entry->date,&date,sizeof(entry->date));
}


/* data aggregate for setBlock parameters */
static struct {
    Bool	   fBoot;
    unsigned	   words;
    unsigned char *pb;
    unsigned char *lowaddress;
    unsigned char *highaddress;
} setBlockData;


/*
 * load one block of memory to ROM
 */
static Bool setBlock(BLKHEADER *pHeader, long huge *data) {
    unsigned char *pbOld;

    if (setBlockData.fBoot) {
	/* only P memory load allowed in first 512 words of boot program */
	if (pHeader->space != p) {
	    fprintf(stderr, "only P memory loadable\n");
	    return (False);
	}

	/* switch to internal loader mode if first 512 words of boot program loaded */
	if (pHeader->address < BOOT_LEN)
	    setBlockData.pb    = &rom.data[BOOT_ADDRESS+3*pHeader->address-ROM_BASE]-DIR_LEN;
	else {
	    setBlockData.pb    = &rom.data[BOOT_ADDRESS+3*BOOT_LEN-ROM_BASE]-DIR_LEN;
	    setBlockData.fBoot = False;
	}
    }

    /* check memory limits */
    if (setBlockData.pb+sizeof(BLKHEADER)+3*pHeader->len > setBlockData.highaddress) {
	fprintf(stderr, "too big load image (max. size is %d words)\n", (setBlockData.highaddress-setBlockData.lowaddress)/3);
	return (False);
    }

    pbOld = setBlockData.pb;
    if (!setBlockData.fBoot) {
	unsigned char *p;

	/* store header */
	for (p = (unsigned char *)pHeader; p < (unsigned char *)pHeader+sizeof(BLKHEADER); p++)
	    *setBlockData.pb++ = *p;
    }

    /* store 24-bit word to three consecutive ROM locations */
    for (;pHeader->len; pHeader->len--) {
	*setBlockData.pb++ = (unsigned char)*data;
	*setBlockData.pb++ = (unsigned char)(*data >> 8);
	*setBlockData.pb++ = (unsigned char)(*data++ >> 16);
    }

    setBlockData.words += setBlockData.pb - pbOld;

    return (True);
}


/*
 * Load linker output file to the ROM image
 */
static unsigned loadLinkerToImage(FILE *fp, Bool fBoot, unsigned lowaddress, unsigned highaddress) {
    static BLKHEADER termBlk = { p, 0, 0 };

    setBlockData.pb	     = &rom.data[lowaddress-ROM_BASE]-DIR_LEN;
    setBlockData.words	     = 0;
    setBlockData.fBoot	     = fBoot;
    setBlockData.lowaddress  = &rom.data[lowaddress-ROM_BASE]-DIR_LEN;
    setBlockData.highaddress = &rom.data[highaddress-ROM_BASE]-DIR_LEN;
    ReadBlocks(fp, setBlock);

    /* set program terminator block */
    setBlock(&termBlk, NULL);

    return (setBlockData.words);
}


/*
 * Give first free address location
 */
static unsigned freeLocation(void) {
    ROMDIR   *p;
    unsigned  top;

    top = DIR_LEN+ROM_BASE;
    for (p = &rom.dir[1]; p < &rom.dir[DIR_ENTRIES]; p++)
	if (p->len)
	    top = max(top, p->adr + p->len);

    return (top);
}


Bool cdecl autoboot(FILE *files[], int numArg) {
    if (!loadROMandCheckValidity(files[0]))
	return (False);

    rom.dir[0].len = numArg;
    storeROM(files[0]);

    return (True);
}


Bool cdecl replace(FILE *files[], int numArg, char *comment) {
    unsigned startAddress, words;

    if (numArg <= 0 || numArg >= DIR_ENTRIES) {
	fprintf(stderr, "illegal program number\n");
	return (False);
    }

    if (!loadROMandCheckValidity(files[0]))
	return (False);

    startAddress = freeLocation();
    if ((words = loadLinkerToImage(files[1], False, startAddress, BOOT_ADDRESS)) != 0) {
	updateDirEntry(&rom.dir[numArg], startAddress, words, comment, files[1]);
	storeROM(files[0]);
    } else
	return (False);

    return (True);
}


Bool cdecl bootimage(FILE *files[], int numArg, char *comment) {
    struct stat statBuf;
    unsigned	words;

    fstat(fileno(files[0]), &statBuf);
    if (statBuf.st_size) {
	/* check ROM library file validity */
	fread(&rom, ROM_LEN, 1, files[0]);
	if (statBuf.st_size != ROM_LEN || rom.dir[0].adr != CHECK_ID) {
	    fprintf(stderr, "illegal ROM library file\n");
	    return (False);
	}
    } else {
	/* create a new ROM library file */
	printf("Creating a new library\n");
	memset(rom.data, 0xff, ROM_LEN-sizeof(ROMDIR));
	memset(rom.dir,  0x00, sizeof(ROMDIR));
    }

    /* read linker outputfile to the ROM image buffer */
    if ((words = loadLinkerToImage(files[1], True, BOOT_ADDRESS, BOOT_END)) != 0) {
	updateDirEntry(&rom.dir[0], CHECK_ID, 0, comment, files[1]);
	storeROM(files[0]);
    } else
	return (False);

    return (True);
}


Bool cdecl list(FILE *files[]) {
    ROMDIR *p;
    Bool    fEntryFound = False;
    char    buf[11];

    if (!loadROMandCheckValidity(files[0]))
	return (False);

    memcpy(buf, rom.dir[0].description, DESC_LEN); buf[DESC_LEN] = '\0';
    printf("ROM: %-10s      %s\n\n", (*buf ? buf : "NO NAME"), ROMdateStr(&rom.dir[0]));
    for (p = &rom.dir[1]; p < &rom.dir[DIR_ENTRIES]; p++)
	if (p->len) {
	    memcpy(buf, p->description, DESC_LEN); buf[DESC_LEN] = '\0';
	    printf("%2d%c  %-10s %4d %s\n", p-rom.dir, ((p-rom.dir) == rom.dir[0].len ? '*' : ' '), buf, p->len, ROMdateStr(p));
	    fEntryFound = True;
	}
    if (!fEntryFound)
	printf("\n     No programs found\n");

    return (True);
}
