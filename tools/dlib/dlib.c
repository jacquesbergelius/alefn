/*  DLIB.C -- Edit/View DSP CARD 4 (FLASH) EPROM memory image
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
#include "dlib.h"


CMDS args[] = {
    { 'C', True, True,	"-c<numarg> <rom_image> <load_image> [comment] - replace/add a new image", { Modify, ReadOnly, Last }, { ".bin", ".lod" }, (Operation)replace },
    { 'D', True, False, "-d<numarg> <rom_image>                        - delete image", 	   { Modify, Last },	       { ".bin" },	   (Operation)NULL },
    { 'B', False,True,	"-b         <rom_image> <load_image> [comment] - replace/add boot image",  { Modify, ReadOnly, Last }, { ".bin", ".lod" }, (Operation)bootimage },
    { 'P', True, False, "-p<numarg> <rom_image>                        - set autoboot program",    { Modify, Last },	       { ".bin" },	   (Operation)autoboot },
    { 'L', False,False, "-l         <rom_image>                        - show rom_image status",   { ReadOnly, Last },	       { ".bin" },	   (Operation)list },
};


static void usage(void) {
    CMDS *p;

    fprintf(stderr, "usage: dlib -<command>[numarg] <rom_image> [<load_image>] [comment]\n");
    for (p = args; p < &args[sizeof(args)/sizeof(CMDS)]; p++)
	fprintf(stderr, "    %s\n", p->usage);
}


int cdecl main(int argc, char *argv[]) {
    printf("DSP CARD 4 ROM library maintainer (%s)\n", __DATE__);

    return (ParseCommands(argc, argv, args, sizeof(args)/sizeof(CMDS), DESC_LEN, usage));
}
