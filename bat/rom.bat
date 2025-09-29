@echo off

rem This batch file builds the demo EPROM for the DSP CARD 4
rem
rem Copyright (C) 1993, 1994 by Alef Null. All rights reserved.
rem Author(s): Jarkko Vuori, OH2LNS
rem Modification(s):

rem First add the Leonid monitor to the EPROM
del	 demo.bin
dlib -b  demo leonid\boot.lod		       Demo Boot

rem Then add application software to the EPROM
dlib -c1 demo source\lpc\recoder.lod	       Greetings
dlib -c2 demo source\nochange\nochange.lod     NoChange
dlib -c3 demo source\bandpass\bandpass.lod     Bandpass
dlib -c4 demo source\qrmqrn\qrm.lod	       QRM
dlib -c5 demo source\qrmqrn\qrn.lod	       QRN
dlib -c6 demo source\fsk\fsk.lod	       1200 FSK
dlib -c7 demo source\pam\g3ruh.lod	       9600 G3RUH

rem Finally set the greetings program to be started automatically when the card demos up
dlib -p1 demo
