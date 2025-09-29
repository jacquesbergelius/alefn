;***************************************************************
;* LEONID.ASM -- Alef Null DSP CARD 4 monitor interface        *
;*							       *
;* Here are equates for services provided by DSP CARD 4        *
;* monitor.						       *
;*							       *
;* Copyright (C) 1992-1996 by Alef Null. All rights reserved.  *
;* Author(s): Jarkko Vuori, OH2LNS			       *
;* Modification(s):					       *
;***************************************************************


; Start of the user program and data areas
user_code equ	$0040				    ; user P-memory starting address
user_data equ	$0018				    ; use X- and Y-memories starting address
kiss_pars equ	$0c00				    ; address of KISS parameter block

; Initialize program space counters
	org	p:user_code
	org	x:user_data
	org	y:user_data

; Macro for target system detecting (simulator or DSP CARD 4 platform)
system	macro	target
	if @scp("target",'simulator')!=0
sim_debug
	else
	    if @scp("target",'dsp4')==0
		fail "No such system: target, known systems are dsp4 or simulator"
	    endif
	endif
	endm


; Open serial communication port (reset all buffers)
;   a - kiss command routine address (zero if not is kiss mode)
;	this routine is called when KISS parameter frame is received
;	a1 - parameter, x1 - data
;	registers r3, a, x0 and x1 are allowed to change in this routine
;   b - xmit on/off routine address (zero if Leonid PTT control is omitted)
;	carry bit tells whether to put PTT on or off
;	registers r3, a1, a0, x0 and x1 are allowed to change in this routine
opensc	macro
	jsr	<$0020
	endm


; Put a byte in x0 to the serial output
putc	macro
	jsr	<$0022
	endm


; Request a character from the serial input
; waits until character given and returns it in x0
getc	macro
_gc1	wait
	jsr	<$0024
	jcs	_gc1
	endm


; Look if there are characters waiting at the serial input
; If specified, wait for a given time (in seconds)
; returns C if there are no data available
;	 NC if there are data, and received data is placed to x0
lookc	macro	time
	if time==0
	    jsr     <$0024
	else
	    move    #>@cvi(time*19200),x0   ; set timer
	    jsr     <$0034
_cwait	    wait
	    jsr     <$0024		    ; check if we have a character available
	    jcc     _cfnd
	    jset    #4,y:$0002,_cwait	    ; no, are we tired for waiting
	    ori     #$01,ccr		    ; yes, ensure that C condition is met
_cfnd	    nop
	endif
	endm


; Test if there are characters waiting at the serial input
; returns C if there are no data available
;	 NC if there are data available
tstc	macro
	jsr	<$0026
	endm


; Terminate KISS output frame
endc	macro
	jsr	<$0028
	endm


; Reject KISS output frame
rejc	macro
	jsr	<$002A
	endm


; put next bit in C to the host transmit queue
putbit	macro
	jsr	<$002C
	endm


; returns next bit to be sent in C
; returns Z if this is an end of the transmission
getbit	macro
	jsr	<$002E
	endm


; Open codec
; fs  is the desired sampling rate   (8,9.6,16,27.42857,32,48)
; hpf is the high-pass filter enable (NOHPF,HPF)
NOHPF	equ	$0000
HPF	equ	$8000
opencd	macro	fs,hpf
	if @def(sim_debug)==0
	    if fs==8
LeoFs		equ			    $000000
	    else
		if fs==9.6
LeoFs		    equ 		    $003800
		else
		    if fs==16
LeoFs			equ		    $000800
		    else
			if fs==27.42857
LeoFs			    equ 	    $001000
			else
			    if fs==32
LeoFs				equ	    $001800
			    else
				if fs==48
LeoFs				    equ     $003000
				else
				    fail "Illegal sampling rate: fs"
				endif
			    endif
			endif
		    endif
		endif
	    endif
	    move    #>LeoFs|hpf,x0
	    jsr     <$0030
	endif
	endm


; Set codecs input and output settings
HEADP	equ	$8000
LINEO	equ	$4000
SPEAKER equ	$0040

LINEI	equ	$0000
MIC	equ	$1000

ctrlcd	macro	init,reg,len,inputs,lgain,rgain,outputs,loattn,roattn
	if @def(sim_debug)==0
	    if	    (lgain>22.5)|(rgain>22.5)|(loattn>94.5)|(roattn>94.5)
	    fail 'Illegal input gain or output attenuation'
	    endif
	    move		#(inputs|$f0|(@cvi(lgain/1.5)<<8)|@cvi(rgain/1.5))<<8,x0
	    clr     a		#(outputs|(@cvi(loattn/1.5)<<8)|@cvi(roattn/1.5))<<8,x1
	    move    (reg)+
	    do	    #len,_initcs
	    if	    init
	    move		a,y:(reg)+
	    move		a,y:(reg)+
	    else
	    move		(reg)+
	    move		(reg)+
	    endif
	    move		x1,y:(reg)+
	    move		x0,y:(reg)+
_initcs
	    move    (reg)-
	endif
	endm


; Close codec
closecd macro
	jsr	<$0032
	endm


; Put byte in x0 to output port
putio	macro
	jsr	<$0036
	endm

; Carrier on
caron	macro
	jsr	<$0038
	endm

; Carrier off
caroff	macro
	jsr	<$003A
	endm

; Wait for the given time (in seconds)
sleep	macro	time
	move		    #@cvi(time*19200.0),x0
	jsr	<$0034
_slp1	wait
	jset	#4,y:$0002,_slp1
	endm


; Macro for waiting specified amount of input data from the codec
waitblk macro	reg,buflen,blklen
	if @def(sim_debug)==0
_loop	    ; bset    #0,x:$ffe4
	    wait					; wait for a new sample to be received
	    ; bclr    #0,x:$ffe4
	    move		r7,a
	    move		reg,x0
	    sub     x0,a	#>blklen*4+2,x0
	    jmi     <_wrap
	    cmp     x0,a				; wp - rp > threshold
	    jlo     <_loop
	    jmp     <_ok
_wrap	    move		#>buflen*4,x1
	    add     x1,a				; buffer wraparound, rp - wp + lenght > threshold
	    cmp     x0,a
	    jlo     <_loop
_ok
	else
	    movep		x:$ffe0,x:(reg)
	endif
	endm


; Macro for debugging SPY program
; a and b (if in complex mode) registers are send to the host
spy	macro
	jsr	<LeoSpy
	endm


; Macro for SPY program
; fComplex detemines if both a and b registers are recorded when calling the 'spy' subroutine
CplxSpy equ	$80
RealSpy equ	$00

spyhere macro	fComplex
	if !(@scp("fComplex",'CplxSpy')|@scp("fComplex",'RealSpy'))
	    fail "Illegal data type selector: fComplex"
	endif

	org	x:

_spyn	dc	$800000


	org	p:

spyflg	equ	23				    ; spy on/off flag

LeoSpy	jclr	#spyflg,x:<_spyn,_spyon

	lookc	0				    ; check if spy operation requested
	jcs	<_spyend
	move		    #>'S',a
	cmp	x0,a
	jne	<_spyend

	move		    #>'P',x0		    ; yes, send first a preamble
	putc
	if @def(LeoFs)
	    move	    #>fComplex|(LeoFs>>11),x0
	else
	    move	    #>fComplex|$04,x0
	endif
	putc
	move		    #>512,a1
	move		    a1,x:<_spyn
	bclr	#spyflg,x:<_spyn
	jmp	<_spyend

; spy is active, send a and b registers to the host
_spyon	move		    a,y0

	rep	#8				    ; LSB first
	lsr	a
	move	a1,x0
	putc

	move		    y0,a		    ; then MSB
	rep	#16
	lsr	a
	move	a1,x0
	putc

	if fComplex
	move		    b,y0
	rep	#8				    ; LSB first
	lsr	b
	move	b1,x0
	putc

	move		    y0,b		    ; then MSB
	rep	#16
	lsr	b
	move	b1,x0
	putc
	endif

	move		    x:<_spyn,a		     ; check if all samples allready given
	move		    #>1,x0
	sub	x0,a
	move		    a,x:<_spyn
	jne	<_spyend
	bset	#spyflg,x:<_spyn

_spyend rts
	endm
