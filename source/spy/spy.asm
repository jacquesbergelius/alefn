;***************************************************************
;* SPY.ASM -- Simple oscilloscope with SPY		       *
;*							       *
;* Displays Left and Right channels on the SPY program.        *
;*							       *
;* Copyright (C) 1994-1996 by Alef Null. All rights reserved.  *
;* Author(s): Jarkko Vuori, OH2LNS			       *
;* Modification(s):					       *
;***************************************************************

	nolist
	include 'leonid'
	list

buflen	equ	16				    ; lenght of sample buffer


	org	p:

	move		    #buffer+2,r7
	move		    #buflen*4-1,m7

	move		    #buffer,r2
	move		    #4-1,n2
	move		    #buflen*4-1,m2

	ctrlcd	1,r2,buflen,LINEI,0.0,0.0,LINEO|HEADP,0.0,0.0
	opencd	32,NOHPF

; wait for one complete block
loop	waitblk r2,buflen,1

; copy left and right channels to the left and right outputs
	move		    x:(r2)+,a		    ; left channel  -> a
	move		    x:(r2),b		    ; right channel -> b
	move		    a,y:(r2)+
	move		    b,y:(r2)+
	move		    (r2)+

; and to the spy
	spy

; loop again (yeah, boring but that's the reason computers are built)
	jmp	<loop


	spyhere CplxSpy 			    ; here is the SPY code


	org	x:

buffer	dsm	buflen*4


	org	y:

	dsm	buflen*4

	end
