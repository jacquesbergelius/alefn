# Borland C Makefile for DLIB and DL compilation

LIBS = c:\borlandc\lib

.c.obj:
    BCC -c -w -O1 $*.c

clean:
    del *.map
    del *.obj
    copy *.exe ..
    del *.exe

dl.exe: dl.obj dlcmd.obj utils.obj serial.obj
    TLINK /L$(LIBS) c0s $**, $*, ,cs

dlib.exe: dlib.obj dlibcmd.obj utils.obj
    TLINK /L$(LIBS) c0s $**, $*, ,cs
