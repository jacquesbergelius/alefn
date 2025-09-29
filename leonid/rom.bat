@echo off

rem This batch file builds the software developer's EPROM for the DSP CARD 4
rem
rem Copyright (C) 1994 by Alef Null. All rights reserved.
rem Author(s): Jarkko Vuori, OH2LNS
rem Modification(s):

rem First add the Leonid monitor to the EPROM
del	 rom.bin
dlib -b  rom boot.lod	     Boot only
