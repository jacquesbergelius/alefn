/*  DL.C -- Download DSP56001 programs to the DSP CARD 4
 *
 *  Copyright (C) by Alef Null 1992, 1993, 1994
 *  Author(s): Jarkko Vuori, OH2LNS
 *	       Rob Janssen,  PE1CHL
 *  Modification(s):
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "utils.h"
#include "dl.h"


CMDS args[] = {
    { 'F', False,False, "-f         <rom_image>  - program FLASH EPROM", { ReadOnly, Last }, { ".bin" }, (Operation)program },
    { 'C', True, False, "-c<numarg>              - change program",	 { Last },	     { "" },	 NULL },
    { 'R', False,False, "-r         <rom_image>  - read FLASH EPROM",	 { Modify, Last },   { ".bin" }, NULL },
    { 'G', False,False, "-g         <load_image> - load RAM and go",	 { ReadOnly, Last }, { ".lod" }, (Operation)loadandgo },
    { 'X', False,False, "-x                      - reset DSP CARD 4",	 { Last },	     { "" },     (Operation)reset },
    { 'P', True, False, "-p<numarg>              - set current port",	 { Last },	     { "" },	 (Operation)setport },
};


static void usage(void) {
    CMDS *p;

    fprintf(stderr, "usage: dl -<command>[numarg] [<rom_image>|<load_image>]\n");
    for (p = args; p < &args[sizeof(args)/sizeof(CMDS)]; p++)
	fprintf(stderr, "    %s\n", p->usage);
}


int cdecl main(int argc, char *argv[]) {
    printf("DSP CARD 4 program downloader (%s)\n", __DATE__);

    return (ParseCommands(argc, argv, args, sizeof(args)/sizeof(CMDS), 0, usage));
}
