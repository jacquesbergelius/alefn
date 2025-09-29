# Borland C Makefile for DLIB and DL compilation

LIBS = c:\borlandc\lib

.c.obj:
    BCC -c -w -O1 $*.c

spy.exe: spy.obj dsply.obj fft.obj serial.obj egavga.obj
    TLINK /L$(LIBS) c0s $**, $*, ,cs maths fp87 graphics

clean:
    del *.map
    del spy.obj
    del dsply.obj
    del fft.obj
    del serial.obj
    copy *.exe ..
    del *.exe
