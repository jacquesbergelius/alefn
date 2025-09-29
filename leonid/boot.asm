	page	132,79
	opt	rc
	title	'DSP CARD 4/EVM56K BIOS'

;****************************************************************************
;* Copyright (C) 1992-1996 by Alef Null. All rights reserved.		    *
;* Author(s): Jarkko Vuori, OH2LNS					    *
;*	      Johan Forrer, KC7WW					    *
;****************************************************************************
;* Here are all DSP56001/2 interrupt vectors and space for       	    *
;* interrupt contexts and basic interrupt service routines.    		    *
;* Also included are initalization code, self checking and     		    *
;* support routines for host communication, codec control,     		    *
;* low level AX25 handling and transmit control.	       		    *
;*							       		    *
;* KISS protocol handling is based on article		       		    *
;*	Chepponis, M., Karn, P.:			       		    *
;*	"The KISS TNC: A simple Host-to-TNC communications     		    *
;*	 protocol",                                            		    *
;*	Proc. of the sixth ARRL computer networking cnf., 1988 		    *
;*							       		    *
;* HDLC protocol handling is based on article		       		    *
;*	Carlson, D., E.:				       		    *
;*	"Bit-Oriented Data Link Control Procedures",	       		    *
;*	IEEE Trans. on Comm., Vol. 28, No. 4, April 1980       		    *
;*							       		    *
;* CRC calculation/checking is based on article 	       		    *
;*	Morse, G.:					       		    *
;*	"Calculating CRCs by bits and bytes",		       		    *
;*	BYTE Vol. 11, No. 9, September 1986		       		    *
;*							       		    *
;* Modification(s):					       		    *
;*							       		    *
;*	08.04.95    added version number printout after reset	(JV)	    *
;*	03.08.95    added DWAIT control logic to the KISS	(JV)	    *
;*		    transmit control			                    *
;*	02.09.95    corrected and modified KISS parameter	(JV)	    *
;*		    handling and TXDELAY=0,TXTAIL=0 bugs                    *
;*		    KISS buffer length increased to 2048 bytes		    *
;*	27.12.95    Conditional assembly for either EVM or DSP4 (JF)	    *
;*	22.03.96    Corrected occasional hang-out in opencd	(JF,JV)     *
;*	11.06.96    Corrected occasional hang-out in reset	(JV)	    *
;*									    *
;*									    *
;* NOTE: r7 is sacred!! - it is used by the SSI - DO NOT TOUCH! 	    *
;*	 r3 as well	- it is used by SCI				    *
;*									    *
;* EVM CODEC SETUP DIFFERENCES (cryconf):				    *
;*	 1) EVM uses the wrong crystal selection for the 24MHz xtal	    *
;*	    (check control word 1/2).					    *
;*	 2) It appears that we need to use the MIC input - I also	    *
;*	    disable the input pre-amp, (check control word 3/4).	    *
;****************************************************************************

; Version number (source code date)
year	equ	1996
month	equ	6
day	equ	11

; Platform selector (DSPCARD4 (0), EVM56002 (1))
EVM56K	equ	0

	if EVM56K
;-----------------------------------------------------------------------------
; We include LEONID here because we need the addresses
; for the user program/data areas in one place only.									    
        nolist
	include 'leonid'
	list

; EVM CODEC usage definitions - these are only EQU's
NO_PREAMP       equ     $100000 
LO_OUT_DRV      equ     $080000
HI_PASS_FILT    equ     $008000
SAMP_RATE_9     equ     $003800		;  9600    SPS with 24.576MHz xtal
SAMP_RATE_48    equ     $003000		; 48000	   SPS 
SAMP_RATE_32    equ     $001800		; 32000    SPS
SAMP_RATE_27    equ     $001000		; 27428.57 SPS
SAMP_RATE_16    equ     $000800		; 16000    SPS
SAMP_RATE_8     equ     $000000		;  8000    SPS
STEREO          equ     $000400
DATA_8LIN       equ     $200300
DATA_8A         equ     $200200
DATA_8U         equ     $200100
DATA_16         equ     $200000
IMMED_3STATE    equ     $800000
XTAL2_SELECT    equ     $200000
BITS_64         equ     $000000
BITS_128        equ     $040000
BITS_256        equ     $080000
CODEC_MASTER    equ     $020000
CODEC_TX_OFF    equ     $010000

CTRL_WD_12      equ     NO_PREAMP+HI_PASS_FILT+SAMP_RATE_48+STEREO+DATA_16   ;CLB=0
CTRL_WD_34      equ     IMMED_3STATE+XTAL2_SELECT+BITS_64+CODEC_MASTER
CTRL_WD_56      equ     $000000
CTRL_WD_78      equ     $000000

HEADPHONE_EN    equ     $800000
LINEOUT_EN      equ     $400000
LEFT_ATTN       equ     $010000 ;63*LEFT_ATTN   = -94.5 dB, 1.5 dB steps
SPEAKER_EN      equ     $004000
RIGHT_ATTN      equ     $000100 ;63*RIGHT_ATTN  = -94.5 dB, 1.5 dB steps
MIC_IN_SELECT   equ     $100000
LEFT_GAIN       equ     $010000 ;15*LEFT_GAIN    = 22.5 dB, 1.5 dB steps
MONITOR_ATTN    equ     $001000 ;15*MONITOR_ATTN = mute,    6   dB steps
RIGHT_GAIN      equ     $000100 ;15*RIGHT_GAIN   = 22.5 dB, 1.5 dB steps
OUTPUT_SET      equ     HEADPHONE_EN+LINEOUT_EN+(LEFT_ATTN*4)
INPUT_SET       equ     MIC_IN_SELECT+(15*MONITOR_ATTN)+(RIGHT_ATTN*4)

;****************************
;*  EVM specific parameters *
;****************************
xtal	equ	40000000

topmem	equ	$1400		; top p memory locations (1FFF is highest)
				; where buffers and monitor routines 
				; are located
rom	equ	$8000		; starting address of the EPROM
monhigh equ	$C600		; part of monitor to be placed on high memory
romlen	equ	32768		; length of the EPROM (in bytes)

; On the EVM56K, P and X shares the same space, so we arbitrarily let
; P use 0100 - 1FFF, X use 2000 - 3FFF, Y is separate 0 - 3FFF
ramx	equ	$2000		; external X RAM st address
ramxlen equ	$4000-$0100	; external X RAM length
ramy	equ	$0100		; external Y RAM st address
ramylen equ	$4000-$0100	; external Y RAM length
ramp	equ	$0200		; external P RAM st address
ramplen equ	$2000-$0200	; external P RAM length
;-----------------------------------------------------------------------------
	else
;-----------------------------------------------------------------------------
;****************************
;* DSP4 specific parameters *
;****************************
xtal	equ	27000000			    ; XTAL frq (in MHz)

topmem	equ	$0c00				    ; top p memory locations where buffers and monitor routines are located

rom	equ	$8000				    ; starting address of the EPROM
monhigh equ	$c600				    ; part of monitor to be placed on high memory
romlen	equ	32768				    ; length of the EPROM (in bytes)

ramx	equ	$0100				    ; external X RAM st address
ramxlen equ	$2000-$0100			    ; external X RAM length
ramy	equ	$0100				    ; external Y RAM st address
ramylen equ	$4000-$0100			    ; external Y RAM length
ramp	equ	$0200				    ; external P RAM st address
ramplen equ	$2000-$0200			    ; external P RAM length
;-----------------------------------------------------------------------------
	endif

; General parameters
hbeat	equ	72.0				    ; heartbeat blinking rate (pulses/min)

; SCI parameters
baud	equ	19200				    ; SCI baud rate
buflen	equ	2048				    ; SCI input/output buffer length

; Protocol parameters
pgm_flash   equ 0				    ; commands
chg_pgm     equ 1
read_flash  equ 2
load_go     equ 3

ack	    equ 4				    ; responses
bad_crc     equ 5
no_flash    equ 6
erase_err   equ 7
pgm_err     equ 8
no_pgm	    equ 9

dataorp equ	0				    ; download space flags
xory	equ	1

magicw	equ	271828				    ; special magic word to detect first time reset

; KISS special characters
fend	equ	$c0
fesc	equ	$db
tfend	equ	$dc
tfesc	equ	$dd

; HDLC equations
flagmsk equ	$ff				    ; left justified flag mask
flag	equ	%01111110			    ; HDLC bit flag
abrtmsk equ	$fe				    ; left justified abort mask
abort	equ	%11111110			    ; abort sequence
fivemsk equ	$fe				    ; left justified five bit mask
five	equ	%01111100			    ; left justified five bit sequence
poly	equ	$8408				    ; HDLC CRC polynomial (x^16 + x^12 + x^5 + 1)
crcchk	equ	$f0b8				    ; special CRC checkword

; flags
rempty	equ	0				    ; SCI flags
rfull	equ	1
xempty	equ	2
xfull	equ	3
timer	equ	4				    ; timer flag
scmode	equ	5				    ; serial communication mode
xkissf	equ	6				    ; put KISS frame begin
ztstflg equ	7				    ; HDLC xmitter status flags
zinsflg equ	8
hunt	equ	9				    ; HDLC receiver status flags
firstb	equ	10
scndb	equ	11
pwrup	equ	12				    ; set if power-up reset
carrier equ	13				    ; carrier on/off
givedat equ	14				    ; data output gate


; macro for green LED handling
copled	macro	mode
	b\mode	#14,x:m_pbd
	endm

; macro for red LED handling
cmdled	macro	mode
	b\mode	#13,x:m_pbd
	endm

; macro for immediate move
movi	macro	data,dest
	move		    data,a1
	move		    a1,dest
	endm

; macro for entering interrupt service routine
; stores x0,x1 and a registers
enter	macro	contex
	move		    x,l:<contex+0
	move		    a10,l:<contex+1
	endm

; macro for leaving interrupt service routine
; restores x0,x1 and a registers
leave	macro	contex
	move		    l:<contex+0,x
	move		    l:<contex+1,a10
	rti
	endm

; CRC calculation routine
; data in the LSB of a
crc	macro	rem
	move		    #>1,x0
	and	x0,a	    rem,x0
	eor	x0,a
	lsr	a	    #>poly,x0
	jcc	_crc1
	eor	x0,a
_crc1	move		    a1,rem
	endm

; byte CRC calculation routine
; byte in x0, result in x:<crcrem
crcbyte macro
	move	x0,b1
	move		    #>$000001,x1
	move		    #>poly,y1
	do	#8,_crc2

	move	b1,a1				    ; first LSB to remainder
	and	x1,a	    x:<crcrem,y0
	eor	y0,a

	lsr	a				    ; XOR if needed
	jcc	_crc1
	eor	y1,a
_crc1	lsr	b	    a1,x:<crcrem
_crc2
	endm


; FLASH EPROM utilities used by DSP CARD4 (EVM does not use these)
; macros for subroutines to read word from ROM and load one ROM image
romhdlr macro	rdromb,rdromw,romload
; read one byte from the boot ROM to x0
rdromb	movep		    #$00f0,x:m_bcr	    ; slow EPROM on P bank
	move		    p:(r1)+,x0
	move		    #$0000ff,b1 	    ; mask unused databits off
	and	x0,b
	move	b1,x0
	movep		    #$0000,x:m_bcr	    ; no more slow EPROM reads
	rts

; read one word from the boot ROM to a1
rdromw	jsr	rdromb				    ; LS byte
	move		    x0,y:<tmp
	jsr	rdromb				    ; MS byte
	move		    #>@cvi(@pow(2,8-1)),x1
	mpy	x0,x1,a     y:<tmp,x0
	move	a0,a1
	or	x0,a
	rts

; load memory blocks from r1
romload jsr	rdromb				    ; packet id
	move		    x0,y:<mspace

	jsr	rdromw				    ; address
	move	a1,r0

	jsr	rdromw				    ; len
	move	a1,n0

	jeq	_loaded
	do	n0,_contld			    ; fetch data
	jsr	rdromb
	move		    x0,y:<tmp
	jsr	rdromb
	move		    #>@cvi(@pow(2,8-1)),x1
	mpy	x0,x1,a     y:<tmp,x1
	move	a0,a1
	or	x1,a
	move		    a1,y:<tmp
	jsr	rdromb
	move		    #>@cvi(@pow(2,16-1)),x1
	mpy	x0,x1,a     y:<tmp,x1
	move	a0,a1
	or	x1,a
	jclr	#dataorp,y:mspace,_d
	move		    a1,p:(r0)+		    ; put to P space
	jmp	_a
_d	jclr	#xory,y:mspace,_x
	move		    a1,y:(r0)+		    ; put to Y space
	jmp	_a
_x	move		    a1,x:(r0)+		    ; put to X space
_a	nop
_contld
	jmp	romload
_loaded rts
	endm


	nolist
	include 'ioequlc'
	include 'intequlc'
	list

;****************************
;*   56K interrupt vectors  *
;****************************

; Reset vector
	org	p:i_reset
	jmp	boot

; Stack error interrupt
	org	p:i_stack
	jmp	shdown

; Trace interrupt
	org	p:i_trace
	jmp	shdown

; SWI
	org	p:i_swi
	jmp	shdown

; IRQA
	org	p:i_irqa
	jmp	shdown

; IRQB
	org	p:i_irqb
	jmp	shdown

; System error shutdown
shdown	nop
	stop

; SSI transmitter interrupt
;(because syncronous mode, we can use the same interrupt for both reading and writing)
	org	p:i_ssitd
	movep		    y:(r7)+,x:m_tx
	movep		    x:m_rx,x:(r7)

; SSI transmitter interrupt with errors
	org	p:i_ssitde
	movep		    x:m_sr,x:m_tx	    ; clear TUE

; SCI receive interrupt
	org	p:i_scird
	jsr	sci_rec

; SCI receive interrupt with errors
	org	p:i_scirde
	jsr	sci_rec

; SCI transmitter interrupt
	org	p:i_scitd
	jsr	sci_xmt

; SCI timer interrupt
	org	p:i_scitm
	jsr	sci_tim

; Monitor routine jump table (here because host port is not used)
	org	p:i_hstrd
	jmp	opensci
	jmp	putc
	jmp	getc
	jmp	tstc
	jmp	endc
	jmp	rejc
	jmp	putbit
	jmp	getbit
	jmp	opencd
	jmp	closecd
	jmp	stimer
	jmp	putio
	jmp	caron
	jmp	caroff

; Illegal instruction interrupt
	org	p:$003e
	jmp	>shdown

	if !EVM56K
;-----------------------------------------------------------------------------
; At this point there is a slightly different philosophy that the EVM uses. 
; The DSP CARD4	executes its startup code once, the re-cycles low memory after 
; the applciation is loaded from EEPROM. With the EVM, OnCe will be use to
; load both the application and low-level BIOS routines, it thus needs to 
; have some valid startup code. I guess	one can play some clever re-location 
; tricks, but this will not help much to re-use low-P space easily. So what 
; we here is to	let DSP CARD4 do its usual thing, while EVM  will assemble 
; its startup code in high-P space - tucked out of harm's way. (JF) 

;*****************************************************************************
;*   Start of the program for DSP CARD4                                      *
;*****************************************************************************
; no wait states on external memory
boot	movep		    #$0000,x:m_bcr

; initialize SCI
	movep		    #$2b02,x:m_scr	    ; 8,n,1
	movep		    #(xtal+2*16*baud)/(2*2*16*baud)-1,x:m_sccr	  ; round baud

; initialize port B
	movep		    #$0000,x:m_pbc	    ; port B as general purpose port
	movep		    #$60ff,x:m_pbddr	    ; PB0-PB7,PB13 and PB14 as outputs
	movep		    #$0000,x:m_pbd

; initialize port C
	movep		    #$0003,x:m_pcc	    ; TXD,RXD
	movep		    #$001c,x:m_pcddr	    ; SCLK,SC0,SC1 as output
	movep		    #$0008,x:m_pcd	    ; PDN up

; initialize data structures
	move		    #outbuf,a1		    ; SCI queue handling
	move		    a1,x:<xhead
	move		    a1,x:<xtail
	move		    #inbuf,a1
	move		    a1,x:<rhead
	move		    a1,x:<rtail
	move		    #buflen-1,m3

	move		    #@cvi(30/hbeat*baud),n3 ; SCI timer system (hearbeat rate 72 pulses/min)
	clr	a
	move		    a,y:<timchg
	move		    a,y:<timcnt
	move		    a,y:<pertim

	move		    #<(1<<rempty)|(1<<xempty),a1
	move		    a1,y:<flags 	    ; buffer empty at first

	move		    #wakeup,a1
	move		    a1,x:<seqptr

; check if power-up reset
	move		    y:<pgmptr,a 	    ; if active program location
	rep	#4-1				    ; contains a special magic pattern
	asr	a				    ; this is not a power-up reset
	asr	a	    #>magicw,x0
	eor	x0,a
	jeq	<chkok
	bset	#pwrup,y:<flags

; hit watchdog (because system testing will take a while)
	copled	chg

; check the system (ROM)
	move		    #rom,r1		    ; calculate ROM's CRC sum
	move		    #$00ffff,a1
	move		    a1,x:<crcrem

	move		    #romlen,r0
	do	r0,check1
	jsr	<rdb
	jsr	<crcb
	nop

check1	move		    #>crcchk,x0 	    ; check with special checkword
	move		    x:<crcrem,a
	cmp	x0,a
	jne	<rombad

; check the system (RAM)
	move		    #$00ffff,a1 	    ; initialize test pattern generator
	move		    a1,x:<crcrem

	move		    #ramx,r1		    ; write test pattern to X ram
	move		    #ramxlen,r0
	do	r0,check2a
	move		    #0,x0
	jsr	<tstpat
	move		    a1,x:(r1)+
check2a

	move		    #ramy,r1		    ; write test pattern to Y ram
	move		    #ramylen,r0
	do	r0,check2b
	move		    #0,x0
	jsr	<tstpat
	move		    a1,y:(r1)+
check2b

	move		    #ramp,r1		    ; write test pattern to P ram
	move		    #ramplen,r0
	do	r0,check2c
	move		    #0,x0
	jsr	<tstpat
	move		    a1,p:(r1)+
check2c

	move		    #$00ffff,a1 	    ; initialize test pattern generator
	move		    a1,x:<crcrem

	move		    #ramx,r1		    ; test X ram
	move		    #ramxlen,r0
	move		    #0,x0
	do	r0,check3a
	jsr	<tstpat
	move		    x:(r1)+,x0
	eor	x0,a	    #0,x0
	jne	<rambad
	nop
check3a

	move		    #ramy,r1		    ; test Y ram
	move		    #ramylen,r0
	move		    #0,x0
	do	r0,check3b
	jsr	<tstpat
	move		    y:(r1)+,x0
	eor	x0,a	    #0,x0
	jne	<rambad
	nop
check3b

	move		    #ramp,r1		    ; test P ram
	move		    #ramplen,r0
	move		    #0,x0
	do	r0,check3c
	jsr	<tstpat
	move		    p:(r1)+,x0
	eor	x0,a	    #0,x0
	jne	<rambad
	nop
check3c

; read the remaining monitor to the upper memory
chkok	move		    #monhigh,r1
	jsr	<memload

; start interrupts
	movep		    #$b000,x:m_ipr	    ; SSI=IPL2, SCI=IPL1
	andi	#$fc,mr 			    ; unmask interrupts

; wait 1 s for the (possible) command
	cmdled	set
	move		    #>ack,x0		    ; tell to host that we managed to get out from the reset
	jsr	putc
	move		    #>(day<<3)|((month-1)>>1),x0
	jsr	putc
	move		    #>((month-1)<<7)|(year-1900),x0
	jsr	putc

	move		    #>@cvi(1.0*baud),x0     ; set timer
	jsr	stimer
_wchr	wait
	jsr	getc				    ; wait for chr of timer
	jcc	<cmdok
	jset	#timer,y:<flags,_wchr

ldpgm	cmdled	clr				    ; no complete command, turn cmd led off
	move		    y:<pgmptr,a
	jset	#pwrup,y:<flags,firstrs

_nopgm	move		    #>$00000f,x0	    ; no, calculate next pgm slot number
	and	x0,a	    #>1,x0
	add	x0,a	    #>16,x1		    ; robin round if last pgm slot number
	cmp	x1,a
	tge	x0,a
	move		    a1,y:<pgmptr
	jsr	ldadr
	move		    y:<pgmptr,a
	jeq	<_nopgm
ldnextp move		    #>magicw<<4,b	    ; active pgm slot found, store slot number
	move	a1,x0
	or	x0,b
	move		    b1,y:<pgmptr
	jmp	lromg				    ; and load image from ROM and jump to it

firstrs move		    #rom+2,r1		    ; first reset, check if there are autoboot programs
	jsr	<rdw
	jne	<ldnextp

_idling wait					    ; nothing to do (no command given, no program to load from ROM)
	jmp	<_idling

; command read, search command
cmdok	move		    #>load_go,a
	cmp	x0,a
	jeq	lg

	jmp	<ldpgm


; temporary utility routines in internal memory
	romhdlr rdb,rdw,memload

crcb	crcbyte
	rts

; pseudonoise RAM test pattern generator (pattern in a)
tstpat	jsr	<crcb
	move		    x:<crcrem,a
	rep	#8-1
	lsl	a
	lsl	a	    x:<crcrem,x1
	eor	x1,a
	rts

; 100 ms software delay
dly100	do	#@cvi(@sqt(xtal/2.0/10.0)),_romb2
	do	#@cvi(@sqt(xtal/2.0/10.0)),_romb1
	nop
_romb1	nop
_romb2	rts

; show that ROM has failed crc check (red and green led blinks at 10 Hz)
rombad	jsr	<dly100
	copled	chg
	cmdled	chg
	jmp	<rombad

; show that RAM has failed check (greed led blinks at 10 Hz, red led blinks at 5 Hz)
rambad	jsr	<dly100
	copled	chg
	cmdled	chg
	jsr	<dly100
	copled	chg
	jmp	<rambad
;-----------------------------------------------------------------------------
	endif

;*****************************************************************************
;*	   The following code will be placed to top p-memory bank	     *
;*****************************************************************************

	org	p:topmem

; KISS parameter table (here because of fixed address)
kisspar dc	@cvi(50*baud/100.0)		    ; txdelay
	dc	63				    ; P
	dc	@cvi(10*baud/100.0)		    ; SlotTim
	dc	@cvi(1*baud/100.0)		    ; TXtail
	dc	0				    ; FullDup
kissext equ	*-kisspar
	dup	16-(*-kisspar)
	dc	0				    ; extra KISS parameters
	endm
kisses	equ	*-kisspar


;****************************
;*    SCI timer interrupt   *
;****************************
sci_tim enter	scidata 			    ; only a1,a0,x1,x0 are saved

; increment timer
	move		    #-1,m3		    ; yes, set next time
	move		    y:<timcnt,r3

; check if destination time reached
	move		    y:<timval,a1
	move		    r3,x0
	eor	x0,a	    (r3)+
	jne	_scit1
	bclr	#timer,y:<flags 		    ; yes, clear flag bit

; check if watch-dog interval reached
_scit1	move		    y:<timchg,a1
	eor	x0,a	    r3,y:<timcnt
	jne	scite
	copled	chg
	move		    (r3)+n3
	nop
	move		    r3,y:<timchg

scite	jsr	pertick 			    ; xmit control module timer
	move		    #buflen-1,m3
	leave	scidata



;****************************
;*    SCI xmit interrupt    *
;****************************
sci_xmt enter	scidata 			    ; only a1,a0,x1,x0 are saved

	move		    x:<xtail,r3
	move		    x:<xhead,x0
	movep		    p:(r3)+,x:m_stxl
	move		    r3,x:<xtail

	bclr	#xfull,y:<flags 		    ; don't bother to check buffer state if it is full
	jcs	scixe

; check if buffer empty
	move	r3,a1
	eor	x0,a
	jne	scixe

; yes, shut down xmitter
	bset	#xempty,y:<flags
	bclr	#m_tie,x:m_scr

scixe	leave	scidata


;****************************
;*   SCI receive interrupt  *
;****************************
wakeup	dc	$12,$b9,$b0,$a1
sci_rec enter	scidata 			    ; only a1,a0,x1,x0 are saved

	movep		    x:m_ssr,x1		    ; clear SCI errors

; first check for special wake-up sequence
	move		    x:<seqptr,r3
	movep		    x:m_srxl,x1 	    ; read byte to x1
	move		    p:(r3)+,a1
	eor	x1,a	    #>wakeup+4,x0
	jeq	scir1
	move		    #wakeup,r3
	jmp	scir2
scir1	move		    r3,a1
	eor	x0,a
	jne	scir2

; wake-up sequence detected (boot the system up)
	stop					    ; watchdog will give reset pulse

; no wake-up sequence detected, continue searching
scir2	move		    r3,x:<seqptr

; then check that there are room left in the buffer
	jset	#rfull,y:<flags,scire

; yes, determine in which mode we are (normal, KISS mode)
	jset	#scmode,y:<flags,scir3

; * normal mode, put data to buffer
	move		    x:<rhead,r3
	bclr	#rempty,y:<flags
	move		    x1,p:(r3)+
	move		    r3,x:<rhead

; check buffer full condition
	move		    r3,a1
	move		    x:<rtail,x0
	eor	x0,a
	jne	scire
	bset	#rfull,y:<flags

	jmp	scire

; * KISS protocol mode, read received character
scir3	move		    x:<getkst,r3
	move		    #fend,a1
	jmp	(r3)				    ; determine what to do for it

; --- State 0, waiting for FEND
str0	eor	x1,a	    #>str1,x0
	jne	scire				    ; we didn't see FEND, keep looking
	move	x0,x:<getkst			    ; FEND found, change state
	jmp	scire

; --- State 1, we have seen FEND, look for the command byte
str1	eor	x1,a	    #>str2,x0
	jeq	scire				    ; just another FEND, keep looking for cmd
; analyze command byte
	move		    #0,a1
	eor	x1,a	    x1,x:<kisscmd
	jeq	str1b				    ; cmd 0, data will follow
; store cmd and change state
str1a	move		    #str4,a1
	move		    a1,x:<getkst
	jmp	scire
; start a new frame
str1b	move		    x0,x:<getkst
	move		    x:<rhead,a1 	    ; get current rhead
	move		    a1,x:<rnhead
	jmp	scire

; --- State 2, data to follow
str2	eor	x1,a				    ; check if end of frame
	jeq	strend
	move		    #fesc,a1
	eor	x1,a				    ; check if escape
	jne	store
; escape character found
	move		    #str3,a1		    ; enter FESC found state
	move		    a1,x:<getkst
	jmp	scire
; end of frame, store negative value
strend	move		    #-1,x1
	jmp	store

; --- State 3, saw FESC, expecting TFESC or TFEND
str3	move		    #tfesc,a1		    ; check if TFESC
	eor	x1,a
	jeq	str3esc
	move		    #tfend,a1
	eor	x1,a				    ; check if TFEND
	jeq	str3end
	move		    #str2,a1
	move		    a1,x:<getkst	    ; something wrong has happened,
	jmp	scire				    ; go back to the data receiving mode
; we have seen TFESC after an FESC, write an FESC
str3esc move		    #str2,a1
	move		    a1,x:<getkst
	move		    #>fesc,x1
	jmp	store
; we have seen TFEND after an FESC, write an FEND
str3end move		    #str2,a1
	move		    a1,x:<getkst
	move		    #>fend,x1

; store the character to the queue
store	move		    x:<rnhead,r3
	move		    x:<rtail,x0
	move		    x1,p:(r3)+
	move	r3,a1				    ; check buffer full
	eor	x0,a	    r3,x:<rnhead
	jeq	scr_st0 			    ; queue full, discard current frame
; check if end of frame
	move		    #-1,a1
	eor	x1,a	    x:<rnhead,x1
	jne	scire

	move		    x1,x:<rhead 	    ; yes, reset real buffer write pointer
	bclr	#rempty,y:<flags
	jsr	frmrec				    ; inform xmit control module
	jmp		    scr_st0

; --- State 4, get command data
str4	move		    a2,y:<tmp		    ; backup a2
	move		    x:<kisscmd,a	    ; check if a local parameter
	move		    #>kisses,x0
	cmp	x0,a	    #>P,x0
	jgt	str4c

	cmp	x0,a	    #>kissext,x0	    ; local parameter, check if a time parameter
	jeq	str4a
	cmp	x0,a	    #>kisspar-1,x0
	jle	str4b

str4a	move		    #>kisspar-1,x0
	add	x0,a				    ; no, store it without any conversion
	move		    a,r3
	nop
	move		    x1,p:(r3)
	jmp	str4c

str4b	add	x0,a	    #>baud/100,x0	    ; yes, time scale parameter
	mpy	x0,x1,a     a,r3
	asr	a				    ; interger multiply correction
	move		    a0,p:(r3)		    ; product in low order word

str4c	move		    y:<kisssub,r3	    ; give also the parameter to the user application
	move		    x:<kisscmd,a
	jsr	(r3)				    ; a1 - cmd, x1 - data
	move		    y:<tmp,a2

; go back to FEND hunt state
scr_st0 move		    #str0,a1
	move		    a1,x:<getkst

scire	leave	scidata


	if !EVM56K
;-----------------------------------------------------------------------------
; Some further DSP CARD4 EEPROM loader code

;**************************
;* LOAD FROM HOST AND GO  *
;**************************
lg	move		    #>ack,x0		    ; tell to host that command was accepted
	jsr	putc

lghunt	move		    #$00ffff,a1 	    ; try to find beginning of the frame
	move		    a1,x:<crcrem
	jsr	rdbyte
	jcs	xmtnak
	move		    #>flag,a
	cmp	x0,a
	jne	lghunt

	jsr	rdbyte				    ; packet id
	jcs	xmtnak
	move		    x0,y:<mspace

	jsr	rdword				    ; address
	jcs	xmtnak
	move	a1,r0

	jsr	rdword				    ; len
	jcs	xmtnak
	move	a1,n0

	jsr	rdbyte				    ; CRC
	jcs	xmtnak
	jsr	rdbyte
	jcs	xmtnak
	move		    #>crcchk,x0
	move		    x:<crcrem,a
	cmp	x0,a
	jne	xmtnak

	move		    #$00ffff,a1
	move		    a1,x:<crcrem
	move	n0,a
	tst	a
	jeq	rdytogo

	do	n0,alldata			    ; fetch data
	jsr	rdbyte
	jcs	xmtnak
	move		    #>@cvi(@pow(2,16-1)),x1
	mpy	x0,x1,a
	move		    a0,y:<tmp
	jsr	rdbyte
	jcs	xmtnak
	move		    #>@cvi(@pow(2,8-1)),x1
	mpy	x0,x1,a     y:<tmp,x1
	move	a0,a1
	or	x1,a
	move		    a1,y:<tmp
	jsr	rdbyte
	jcs	xmtnak
	move		    y:<tmp,a
	or	x0,a
	jclr	#dataorp,y:mspace,_d
	move		    a1,p:(r0)+		    ; put to P space
	jmp	_a
_d	jclr	#xory,y:mspace,_x
	move		    a1,y:(r0)+		    ; put to Y space
	jmp	_a
_x	move		    a1,x:(r0)+		    ; put to X space
_a	nop
alldata

	jsr	rdbyte				    ; CRC
	jsr	rdbyte
	move		    #>crcchk,x0
	move		    x:<crcrem,a
	cmp	x0,a	    #>ack,x0

	jsr	putc				    ; crc ok, wait for the next
	jmp	lghunt

xmtnak	move		    #>bad_crc,x0	    ; crc bad, ignore frame and try again
	jsr	putc
	jmp	lghunt

rdytogo move		    #>ack,x0		    ; crc ok, if len=0 then jump to the user code
	jsr	putc
	cmdled	clr
	jmp	<boot

sherror move		    #>@cvi(0.5*baud),x0     ; error condition, blink cmd led
	jsr	stimer
_sherro wait
	jset	#timer,y:<flags,_sherro
	cmdled	chg
	jmp	sherror


;********************
;* LOAD ROM AND GO  *
;********************
; program number is in a1 register
lromg	jsr	ldadr
	move	a1,r1
	jsr	romload 			    ; then load the program
	jmp	<boot				    ; and finally jump to it
;-----------------------------------------------------------------------------
	endif


;****************************
;*     Open Serial line     *
;****************************
; flushes all buffers and set the desired communication speed
;   a - kiss command routine address (zero if not is kiss mode)
;   b - xmit on/off routine address
opensci move		    a1,y:<kisssub
	bclr	#scmode,y:<flags
	tst	a	    #str0,a1
	jeq	opensce

; KISS mode, initialize handlers
	move		    b1,y:<xmitsub	    ; store given addresses
	move		    a1,x:<getkst
	move		    #(1<<xoff),b1
	clr	b	    b1,x:<pstate	    ; and initialize xmit control module
	move		    b1,y:<pertim

	bset	#scmode,y:<flags
	bclr	#xkissf,y:<flags

	movi	#xstD,y:<xstate 		    ; initialize coder
	movi	#flag,y:<xdata
	movi	#$0,y:<x5bit
	movi	#0,y:<xbit
	bclr	#ztstflg,y:<flags
	bclr	#zinsflg,y:<flags

	movi	#0,x:<rdata			    ; initialize decoder
	movi	#$0,x:<rflag
	bset	#hunt,y:<flags
	bset	#firstb,y:<flags
	bset	#scndb,y:<flags

opensce rts


;****************************
;*  Put character to queue  *
;****************************
; byte in x0
; returns  Z if buffer full
;	  NZ otherwise
putc	ori	#$02,mr 			    ; disable interrupts
	nop
	nop
	jset	#scmode,y:<flags,putkiss

; * normal mode
	move		    x:<xtail,x1
	move		    x:<xhead,a1
	move		    a1,r3

; xmitter was running, check if there are free space left
	bclr	#xempty,y:<flags		    ; if buffer empty, sure there are free space left
	jcs	putc1
	eor	x1,a				    ; if read ptr <> write ptr there are also free space left
	jne	putc2

; buffer full state reached (ignore given data)
	bset	#xfull,y:<flags
	jmp	putce

; there was free space left, write character to the buffer
putc1	bset	#m_tie,x:m_scr			    ; start xmitter interrupts
putc2	move		    x0,p:(r3)+
	move		    r3,x:<xhead
	jmp	putce


; * KISS mode, check if start of new KISS frame
putkiss jset	#xkissf,y:<flags,putk1

; yes, send KISS preamble
	bset	#xkissf,y:<flags
	move		    x:<xhead,r3
	move		    r3,x:<xnhead

	move		    #fend,a1
	move		    a1,p:(r3)+
	move		    #0,a1
	move		    a1,p:(r3)+

	move		    r3,x:<xnhead

; no, send pure data only
putk1	move		    x:<xnhead,r3

	move		    #fesc,a1		    ; check if FESC
	eor	x0,a	    #tfesc,b1
	jeq	putkspe

	move		    #fend,a1		    ; check if FEND
	eor	x0,a	    #tfend,b1
	jne	putke1

; special character, enter escaped special character
putkspe move		    #>fesc,x0
	move		    x0,p:(r3)+
	move	b1,x0

putke1	move		    x0,p:(r3)+
	move		    r3,x:<xnhead

putce	andi	#$fc,mr
	rts


;****************************
;* End current KISS frame   *
;****************************
endc	ori	#$02,mr 			    ; disable interrupts
	nop
	nop
	nop
	bclr	#xkissf,y:<flags

	move		    x:<xnhead,r3	    ; write last fend
	move		    #>fend,x0
	move		    x0,p:(r3)+
	move		    r3,x:<xhead

	jclr	#xempty,y:<flags,ekisse 	    ; check for idling xmitter
	bset	#m_tie,x:m_scr

ekisse	andi	#$fc,mr
	rts


;****************************
;* Reject current KISS frame*
;****************************
rejc	bclr	#xkissf,y:<flags
	rts


;****************************
;* Get character from queue *
;****************************
; byte in x0
; returns  C if no data available
;	  NC if data available
getc	ori	#$02,mr 			    ; disable interrupts
	nop
	nop
	nop
	nop
	move		    x:<rtail,r3

; check if there are data available
	btst	#rempty,y:<flags
	jcs	getce

; yes, take it from the queue
	bclr	#rfull,y:<flags
	move		    p:(r3)+,x0
	move		    r3,x:<rtail

; check if buffer gets empty
	move		    x:<rhead,a
	move		    r3,x1
	cmp	x1,a
	andi	#$fe,ccr			    ; NC
	jne	getce

; yes, set empty flag
	bset	#rempty,y:<flags

getce	andi	#$fc,mr
	rts


;****************************
;* Test if chrs available   *
;****************************
; returns  C if no data available
;	  NC if data available
tstc	btst	#rempty,y:<flags
	rts


;****************************
;*	  Get a bit	    *
;****************************
; returns next bit to be sent in C
; returns Z if this is an end of the transmission
; Note! Interrupts are disabled if end of transmission detected

; check if we are allowed to send data
getbit	jclr	#givedat,y:<flags,xstD2

; check if we must insert a zero
	bclr	#zinsflg,y:<flags
	jcs	getins

; check if there are bits left
	move		    y:<xbit,a
	tst	a	    y:<xstate,r0
	move		    #-1,m0
	jeq	(r0)

; five bit sequence detection logic
getsft0 jclr	#ztstflg,y:<flags,getsft1	  ; check if logic enabled
	move		    y:<xdata,a
	lsr	a
	move		    y:<x5bit,a
	ror	a	    #>$f80000,x0
	and	x0,a
	cmp	x0,a	    a1,y:<x5bit
	jne	getsft1

; 11111 detected, insert zero
	bset	#zinsflg,y:<flags

; calculate CRC
getsft1 move		    y:<xdata,a
	crc	y:<xcrcrem

; shift data out (LSB first) and decrement bit counter
	move		    y:<xbit,r0
	move		    y:<xdata,a
	lsr	a	    (r0)-
	move		    r0,y:<xbit
	move		    a1,y:<xdata
	andi	#$fb,ccr			    ; NZ
	rts

; insert zero bit
getins	clr	a				    ; reset five bit counter
	move		    a1,y:<x5bit
	andi	#$fa,ccr			    ; NC NZ
	rts


; --- A, after a begin flag
xstA
; set up data xmission
	movi	#xstB,y:<xstate
	movi	#$00ffff,y:<xcrcrem		    ; init CRC generator
	bset	#ztstflg,y:<flags		    ; enable 11111 checker

; --- B, after data byte sent
xstB	movi	#8,y:<xbit			    ; init bit counter for the next byte
	jsr	getc				    ; fetch next byte
	move	x0,y:<xdata
	move	x0,a
	tst	a
	jpl	getsft0

; last databyte sent, send CRC
	movi	#xstC,y:<xstate
	movi	#16,y:<xbit
	move		    y:<xcrcrem,a
	not	a
	move		    a1,y:<xdata
	jmp	getsft0

; --- C, after CRC sent
xstC	movi	#xstD,y:<xstate
	movi	#flag,y:<xdata
	movi	#8,y:<xbit
	bclr	#ztstflg,y:<flags		    ; disable 11111 checker
	jmp	getsft0

; --- D, after the last flag sent
xstD	jsr	tstc
	jcs	xstD1

; new data to send, start a new frame
	movi	#xstA,y:<xstate
	movi	#flag,y:<xdata
	movi	#8,y:<xbit
	jmp	getsft0
	rts

; no new data, return with Z (and NC, giving a zero databit)
xstD1	jsr	rdempty 			    ; inform xmit control module
xstD2	ori	#$04,ccr
	andi	#$fe,ccr
	rts


;****************************
;*	  Put a bit	    *
;****************************
; put next bit in C to the host transmit queue
putbit	move		    x:<rflag,a
	ror	a	    #abrtmsk,b
	move		    a1,x:<rflag
	move		    a1,x0

; check if abort sequence detected
	and	x0,b	    #abort,y0
	eor	y0,b
	jeq	putb4

; check if flag detected
	move		    #flagmsk,b
	and	x0,b	    #flag,y0
	eor	y0,b	    #fivemsk,a
	jeq	putb3				    ; yes, special handling

; check if 11111 sequence detected
	and	x0,a	    #five,y0
	eor	y0,a	    x0,b
	jeq	putb2				    ; yes, ignore this bit

; no special sequence detected, shift data normally
	jset	#hunt,y:<flags,putb2
	lsl	b	    x:<rdata,a
	ror	a	    #>@pow(2,-15),x1
	move		    a1,x:<rdata
	move		    a1,x0

; calculate CRC
	mpy	x0,x1,a     #>1,x1		    ; shift to right 15 bits
	crc	x:<rcrcrem

; decrement the bit counter
	move		    x:<rbit,a
	sub	x1,a	    #8,b1
	move		    a1,x:<rbit
	jne	putb2

; 8 bit shifted, init bit counter again
	move		    b1,x:<rbit
	bclr	#firstb,y:<flags
	jcc	putb1

; first byte, init CRC checker
	move		    #$00ffff,a1
	move		    a1,x:<rcrcrem
	rts

; data bytes, put it to the queue
putb1	bclr	#scndb,y:<flags
	jcs	putb2
	move		    x:<rdata,a
	move		    #>$ff,x0
	and	x0,a
	move		    a1,x0
	jsr	putc

; discard the previous bit
putb2	rts

; flag detected
putb3	bclr	#hunt,y:<flags
	movi	#8,x:<rbit
	bset	#firstb,y:<flags
	bset	#scndb,y:<flags
	jcc	putb3a				    ; reject frame if it is too short
	jsr	rejc
	rts

; calculate the last CRC bit
putb3a	move		    x:<rdata,x0
	move		    #>@pow(2,-16),x1	    ; shift to right 16 bits
	mpy	x0,x1,a
	crc	x:<rcrcrem

; check that it is valid
	move		    #>crcchk,x0
	eor	x0,a
	jne	putb3b				    ; reject frame if CRC failed
	jsr	endc
	rts
putb3b	jsr	rejc
	rts

; abort detected
putb4	bset	#hunt,y:<flags
	jsr	rejc
	rts


;****************************
;*	 Request timer	    *
;****************************
; delay in x0 (in 1/baud s)
stimer	move		    y:<timcnt,a
	add	x0,a	    #>$00ffff,x0
	and	x0,a
	move		    a1,y:<timval
	bset	#timer,y:<flags
	rts

;-----------------------------------------------------------------------------
; The DSP CARD4 and EVM uses different hardware	handshaking lines
; to control the CODEC and thus requires their specific initializations.

	if EVM56K 
;-----------------------------------------------------------------------------
;****************************************************************************
;*     Open codec driver for EVM   *
;
;   r7 - address of the modulo buffer (x: A/D, y: D/A)
;   m7 - length of the modulo buffer
;   x0 - samping rate:
;
;****************************************************************************
;
;      portc usage:
;     	bit8: SSI TX (from DSP to Codec)
;	bit7:
;	bit6:
;	bit5:
;	bit4: codec reset (from DSP to Codec)
;	bit3:
;     	bit2: data/control bar
;             0=control
;             1=data
;
;
;  PROGRAM OUTLINE:
;
;1 program fsync and sclk == output
;2 write pc0 = 0 (control mode)
;3 send 64 bit frame x times, with dcb bit = 0, keep doing until read back as 0
;4 send 64 bit frame x times, with dcb bit = 1, keep doing until read back as 1
;5 re-program fsync and sclk == input
;6 write pc0 = 1 (data mode)
;7 receive/send data (echo slots 1,2,3,4; slots 5,6,7,8 == DIP switched)
; 
;      initialize ssi -- fsync and sclk ==> outputs
;
;
;****************************************************************************
; *****Sample rate is passed in x0 from macro call*****
;****************************************************************************
opencd	movep	#$0003,x:m_pcc	;  turn off ssi port (keep SCI on)
	movep   #$4303,x:m_cra  ;  40MHz/16 = 2.5MHz SCLK, WL=16 bits, 4W/F
	movep   #$3B30,x:m_crb  ; RIE,TIE,RE,TE, NTWK, SYN, FSR/RSR->bit

	bclr	#4,x:m_pcd	; RESET~ ....
	bclr	#2,x:m_pcd	; D/C~	 ...... 0 ==> Control mode
				;----reset delay for codec ----
	do      #500,_delay_loop
	rep     #2000           ; 100 us delay
	nop
_delay_loop
	bset    #4,x:m_pcd      ; RESET~ = 1

	movep   #$01E3,x:m_pcc  ; Turn on ssi port (keep SCI on)

; send control blocks to the codec until we get valid responce from it
						      ; add sampling rate and set CLB = 0
	move		    #>%1110101101000111<<8,x1 ; add MICGAIN, HPF,
						      ; sampling rate,
						      ; set CLB = 0
	move		    y:<cryconf,a1
	and	x1,a
	or	x0,a	    #cryconf,r0
	move		    a1,y:<cryconf
	move		    #4-1,m0

confcod jsr	outblk		; send control info until CLB is low
	jset	#2+16,x:tmpblk+2,confcod

; codec is configured, send final control block
	bset	#2+16,y:<cryconf+0		    ; set CLB = 1
	do	#200,confok			    ; at least two frames after CLB high
	jsr	outblk				    ; and ensure that at least 50 ms elapsed after leaving from PDN state
	nop
confok	move		    #-1,m0

	movep   #$0003,x:m_pcc  ;  turn off ssi port (keep SCI on) 

;*****************************************************************************
;  now CLB should be 1 -- re-program fsync and sclk direction (i/p)
;
	movep   #$4303,x:m_cra  ; 16bits,4 word/frame, /2/4/2=2.5 MHz
	bset    #2,x:m_pcd      ; D/C~ = 1 ==> Data mode
	movep   #$01E3,x:m_pcc  ;  turn on ssi port (keep SCI on)

waitsyn jclr	#m_tde,x:m_sr,waitsyn		    ; wait for the frame sync
	jset	#m_tfs,x:m_sr,frmsync
	movep		    x:m_rx,x:m_tsr
	jmp	waitsyn

frmsync do	#4-1,flshfrm			    ; then get rid of the remaining data
_loop1	jclr	#m_tde,x:m_sr,_loop1
	movep		    y:(r7)+,x:m_tx
	movep		    x:m_rx,x:(r7)
flshfrm

	do	#192*4,waitcal			    ; wait for calibration
_loop2	jclr	#m_tde,x:m_sr,_loop2
	movep		    y:(r7)+,x:m_tx
	movep		    x:m_rx,x:(r7)
waitcal

	movep   #$7b00,x:m_crb	    ; enable transmit interrupts
	rts

;****************************
;*     Close codec driver   *
;****************************
; close SSI interface and set codec to power down mode
closecd movep		    #$0003,x:m_pcc	    ; TXD,RXD
	movep		    #$001c,x:m_pcddr	    ; SCLK,SC0,SC1 as output
	rts
;-----------------------------------------------------------------------------
	else	
;-----------------------------------------------------------------------------
;*****************************************
;*     Open codec driver  for DSP CARD4  *
;*****************************************
; Start-up Crystal CS4215 Codec
;   r7 - address of the modulo buffer (x: A/D, y: D/A)
;   m7 - lenght of the modulo buffer
;   x0 - samping rate and HPF enable/disable:
;	8	kHz   $000000
;	9.6	kHz   $003800
;      16	kHz   $000800
;      27.42857 kHz   $001000
;      32	kHz   $001800
;      48	kHz   $003000
;
;      HPF enable     $008000
;
; program SSI to handle codec's initial communication mode
opencd	ori	#$02,mr
	movep		    #$4f03,x:m_cra	    ; 27/16 MHz SCLK, WL=16 bit, 16 W/F
	movep		    #$3b3c,x:m_crb	    ; generate SCLK and FS

	movep		    #$01e3,x:m_pcc	    ; TXD,RXD,SC2,SCK,SRD,STD
	movep		    #$001c,x:m_pcddr	    ; SCLK,SC0,SC1 as output
	movep		    #$0000,x:m_pcd	    ; PDN & D/C down (wake up codec and put it to the control mode)

; send control blocks to the codec until we get valid responce from it
	move		    #>%1111101101000111<<8,x1 ; add sampling rate and HPF bit and set CLB = 0
	move		    y:<cryconf,a1
	and	x1,a
	or	x0,a	    #cryconf,r0
	move		    a1,y:<cryconf
	move		    #4-1,m0

confcod jsr	outblk				    ; send control info until CLB is low
	jset	#2+16,x:tmpblk+2,confcod

; codec is configured, send final control block
	bset	#2+16,y:<cryconf+0		    ; set CLB = 1
	do	#200,confok			    ; at least two frames after CLB high
	jsr	outblk				    ; and ensure that at least 50 ms elapsed after leaving from PDN state
	nop
confok	move		    #-1,m0

; reset and reprogram SSI again because we will get clock and frame signals from codec
	movep		    #$0003,x:m_pcc	    ; SRD,STD
	movep		    #$4303,x:m_cra	    ; WL=16 bit, 4 W/F
	movep		    #$3b0c,x:m_crb	    ; receive SCLK and FS
	movep		    #$01e3,x:m_pcc	    ; TXD,RXD,SC2,SCK,SRD,STD

; then start data transfer and synchronize to it
	movep		    #$0010,x:m_pcd	    ; D/C high (switch codec to data mode)

waitsyn jclr	#m_tde,x:m_sr,waitsyn		    ; wait for the frame sync
	jset	#m_tfs,x:m_sr,frmsync
	movep		    x:m_rx,x:m_tsr
	jmp	waitsyn

frmsync do	#4-1,flshfrm			    ; then get rid of the remaining data
_loop1	jclr	#m_tde,x:m_sr,_loop1
	movep		    y:(r7)+,x:m_tx
	movep		    x:m_rx,x:(r7)
flshfrm

	do	#192*4,waitcal			    ; wait for calibration
_loop2	jclr	#m_tde,x:m_sr,_loop2
	movep		    y:(r7)+,x:m_tx
	movep		    x:m_rx,x:(r7)
waitcal

	movep		    #$7b0c,x:m_crb	    ; enable transmit interrupts
	andi	#$fc,mr

	rts


;****************************
;*     Close codec driver   *
;****************************
; close SSI interface and set codec to power down mode
closecd movep		    #$0003,x:m_pcc	    ; TXD,RXD
	movep		    #$001c,x:m_pcddr	    ; SCLK,SC0,SC1 as output
	movep		    #$0008,x:m_pcd	    ; PDN up

	rts
;-----------------------------------------------------------------------------
	endif


;****************************
;*    Update output port    *
;****************************
; put lowest eight bits in x0 register to general purpose i/o-port
putio	ori	#$02,mr 			    ; disable interrupts
	move		    #>$0000ff,a1
	and	x0,a	    #>$ffff00,x0
	move	a1,x1

	movep		    x:m_pbd,a
	and	x0,a
	or	x1,a
	movep		    a1,x:m_pbd

	andi	#$fc,mr
	rts


; *** Persistence routines ***

; state bits
xstart	equ	0				    ; starting up xmitter (xmit on, no data transmitting)
xstop	equ	1				    ; putting xmitter off
xon	equ	2				    ; xmitter currently transmitting data
xoff	equ	3				    ; xmitter off
xwait	equ	4				    ; waiting for carrier to be inactive
xpersis equ	5				    ; waiting for a new persistence algorithm slot

; macro for state setting
nxstate macro	state
	move		    #(1<<state),a1
	move		    a1,x:<pstate
	endm

; kiss parameters
txdelay equ	1
P	equ	2
SlotTim equ	3
TXtail	equ	4
FullDup equ	5


;****************************
;*   Carrier off routine    *
;****************************
; inform Leonid that there are no data transmissions ongoing
caroff	ori	#$02,mr
	nop
	nop
	nop
	bclr	#carrier,y:<flags

	jsset	#xwait,x:<pstate,dlxmit 	    ; delayed start of xmitter if we are waiting for it

_car1	andi	#$fc,mr
	rts


;****************************
;*   Carrier on routine     *
;****************************
; inform Leonid that there are data transmissions ongoing
caron	ori	#$02,mr
	nop
	nop
	nop
	bset	#carrier,y:<flags

	jclr	#xpersis,x:<pstate,_car2
	nxstate xwait				    ; fall back to carrier off waiting mode

_car2	andi	#$fc,mr
	rts


; one KISS frame received
frmrec	jset	#xoff,x:<pstate,_frm1
	jset	#xstop,x:<pstate,stxmiti	    ; curretly shutting down, but continue directly
	rts

_frm1	move		    p:kisspar+FullDup-1,a   ; if fullduplex mode, then there is no need to check the carrier
	tst	a
	jne	stxmit
	jclr	#carrier,y:<flags,dlxmit	    ; if no carrier, then start xmitter

	nxstate xwait				    ; carrier, wait until it disappears
	rts

; trying to read empty buffer
rdempty ori	#$02,mr
	nop
	nop
	nop
	jclr	#xon,x:<pstate,_rde1

	nxstate xstop				    ; stop transmitting
	bclr	#givedat,y:<flags
	move		    p:kisspar+TXtail-1,a    ; and set txdelay timer
	tst	a	    a1,y:<pertim
	jne	_rde1
	jsr	stpxmit 			    ; if txtail=0 stop xmitter immediately

_rde1	andi	#$fc,mr
	rts

; persistence algorithm
mkpersi move		    a2,x:<a2tmp 	    ; backup a2 because this routine may be called from interrupt handler
	move		    x:(r7),x0		    ; first make a random number (combine left audio channel with timer)
	move		    #@pow(2,-8),x1
	mpy	x0,x1,a     y:<timcnt,x0
	add	x0,a	    #>$0000ff,x0
	and	x0,a
	move	a1,a
	move		    p:kisspar+P-1,x0	    ; then compare it with P
	cmp	x0,a	    x:<a2tmp,a2
	jle	stxmit

	move		    p:kisspar+SlotTim-1,a1  ; we lost random number, wait slottime before trying again
	move		    a1,y:<pertim
	rts

; wait slottime, then start xmitter
dlxmit	move		    p:kisspar+SlotTim-1,a   ; if slottime is zero, start P-persistence algorithm immediately
	tst	a	    a1,y:<pertim
	jeq	mkpersi

	nxstate xpersis 			    ; else wait first one slottime before starting P-persistence algorithm
	rts

; start xmitter
stxmit	move		    y:<xmitsub,r3	    ; call user's xmit on routine
	ori	#$01,ccr
	jsr	(r3)

	move		    p:kisspar+txdelay-1,a   ; and set txdelay timer
	tst	a	    a1,y:<pertim
	jeq	stxmiti 			    ; if txdelay=0 then start xmitter immediately
	nxstate xstart				    ; change to XSTART state
	rts

; start xmitter immediately
stxmiti nxstate xon				    ; start xmitting
	bset	#givedat,y:<flags		    ; start giving data to the application program
	rts

; stop xmitter immediately
stpxmit nxstate xoff				    ; stop xmitting
	move		    y:<xmitsub,r3	    ; call user's xmit off
	andi	#$fe,ccr
	jsr	(r3)
	rts

; 1/baud s timer ticks here
pertick move		    y:<pertim,a1
	move		    #>0,x0
	eor	x0,a	    a1,r3
	jeq	_pert1
	move		    (r3)-		    ; check if timer elapsed
	move	r3,a1
	eor	x0,a	    r3,y:<pertim
	jne	_pert1
	jset	#xpersis,x:<pstate,mkpersi
	jset	#xstart,x:<pstate,stxmiti
	jset	#xstop,x:<pstate,stpxmit
_pert1	rts


; read one word (updating CRC)
; returns NC if word received, C if not
rdword	jsr	rdbyte				    ; MS byte
	jcs	_rwe
	move		    #>@cvi(@pow(2,8-1)),x1
	mpy	x0,x1,a
	move		    a0,y:<tmp
	jsr	rdbyte				    ; LS byte
	jcs	_rwe
	move		    y:<tmp,a
	or	x0,a
_rwe	rts


; wait 1s for the next character and update CRC calculation
; returns NC if chr received, C if not
rdbyte	move		    #>@cvi(1.0*baud),x0     ; set timer (1s)
	jsr	stimer
	jsr	waitchr
	jcs	_rbe
	crcbyte 				    ; calculate CRC of byte in x0, result in x:<crcrem
	andi	#$fe,ccr			    ; ensure that NC condition is met
_rbe	rts


; wait for (predetermined time) the next character
; returns NC if chr received, C if not
wchr	wait
waitchr jsr	getc				    ; wait for chr of timer
	jcc	chrfnd
	jset	#timer,y:<flags,wchr
	andi	#$fe,ccr			    ; ensure that NC condition is met
chrfnd	rts					    ; chr found


; Output one 256 bit block (codec in the first time slot)
outblk	do	#4,outblk1			    ; actual data transfer on the first slot only
_loop	jclr	#m_tde,x:m_sr,_loop
	movep		    x:m_rx,x:(r0)
	movep		    y:(r0)+,x:m_tx

outblk1 do	#16-4,outblk2			    ; idling remainig slots
_loop	jclr	#m_tde,x:m_sr,_loop
	movep		    a1,x:m_tsr

outblk2 rts

	if !EVM56K
;-----------------------------------------------------------------------------
; More DSP CARD4 EEPROM loader
; Calculate program load address (to a1) from the address in a1
; returns Z if no program in a given slot
ldadr	rep	#4-1				    ; first calculate directory entry address (16*id+rom)
	lsl	a
	lsl	a	    #>rom,x0
	add	x0,a
	move	a1,r1				    ; then fetch the load address
	jsr	romrdw
	rts


	romhdlr romrdb,romrdw,romload
;-----------------------------------------------------------------------------
	endif

	if EVM56K
;-----------------------------------------------------------------------------
;****************************
;*   Startup code for EVM   *
;****************************
boot 	movep   #$261009,x:PLL          ; set PLL for MPY of 10x
	movep   #$0000,x:m_bcr          ; zero wait states for ext. memory
	ori     #3,mr                   ; disable interrupts
	movec   #0,sp
	move    #0,omr                  ; single chip mode

; initialize SCI
	movep		    #$2b02,x:m_scr	    ; 8,n,1
	movep		    #(xtal+2*16*baud)/(2*2*16*baud)-1,x:m_sccr	  ; round baud

; initialize port B
	movep		    #$0000,x:m_pbc	    ; port B as general purpose port
	movep		    #$60ff,x:m_pbddr	    ; PB0-PB7,PB13 and PB14 as outputs
	movep		    #$0000,x:m_pbd

; initialize port C
	movep		    #$0003,x:m_pcc	    ; We are using TXD,RXD

						    ; pc2 (D/C~), pc3 (DCD), 
	movep   	    #$1C,x:m_pcddr	    ; pc4 (C Reset) as outputs

	movep   	    #0,x:m_pcd		   ; init PC4,PC3,PC2=0

; initialize data structures
	move		    #outbuf,a1		    ; SCI queue handling
	move		    a1,x:<xhead
	move		    a1,x:<xtail
	move		    #inbuf,a1
	move		    a1,x:<rhead
	move		    a1,x:<rtail
	move		    #buflen-1,m3

	move		    #@cvi(30/hbeat*baud),n3 ; SCI timer system (hearbeat rate 72 pulses/min)
	clr	a
	move		    a,y:<timchg
	move		    a,y:<timcnt
	move		    a,y:<pertim

	move		    #<(1<<rempty)|(1<<xempty),a1
	move		    a1,y:<flags 	    ; buffer empty at first

	move		    #wakeup,a1
	move		    a1,x:<seqptr

	move	#CTRL_WD_12,a1		; CODEC control words
	move	a1,y:<cryconf
	move	#CTRL_WD_34,a1
	move	a1,y:<cryconf+1
	move	#CTRL_WD_56,a1
	move	a1,y:<cryconf+2
	move	#CTRL_WD_78,a1
	move	a1,y:<cryconf+3

; start interrupts
	movep		    #$b000,x:m_ipr	    ; SSI=IPL2, SCI=IPL1
	andi	#$fc,mr 			    ; unmask interrupts

; flash red LED once to show all is OK  
	cmdled	set
	move		    #>@cvi(1.0*baud),x0     ; set timer
	jsr	stimer
_wchr	wait
	jset	#timer,y:<flags,_wchr	; wait for timer
	cmdled	clr

; EVM56K transfer to label "user_code" here
	jmp	user_code
;----------------------------------------------------------------------------
	endif

; serial buffers
inbuf	dsm	buflen
outbuf	dsm	buflen


;****************************
;*  CONTEX STORE FOR INTS   *
;****************************

	org	l:$0000

scidata ds	2


	org	x:$0002

rhead	ds	1
rtail	ds	1

tmpblk	dsm	4
a2tmp	ds	1

xhead	ds	1
xtail	ds	1
seqptr	ds	1
crcrem	ds	1

getkst	ds	1
rnhead	ds	1
xnhead	ds	1
kisscmd ds	1

rdata	ds	1				    ; current byte received
rflag	ds	1				    ; one bit counter
rbit	ds	1				    ; received bit counter
rcrcrem ds	1				    ; CRC remainder

pstate	ds	1				    ; xmit control module state


	org	y:$0002

flags	ds	1
tmp	ds	1

; Crystal CS4215 configuration data
; Stereo, 16-bit linear, XTAL1, 64 bit/frame, generate SCLK and FSYNC
cryconf dc	%0000000000000100<<8		    ; Control Time Slot 1 & 2
	dc	%1001001000000000<<8		    ; Control Time Slot 3 & 4
	dc	%0000000000000000<<8		    ; Control Time Slot 5 & 6
	dc	%0000000000000000<<8		    ; Control Time Slot 7 & 8

timcnt	ds	1
timval	ds	1
timchg	ds	1
mspace	ds	1
pgmptr	ds	1

khead	ds	1
kisssub ds	1

xstate	ds	1				    ; current xmitter state
xdata	ds	1				    ; current byte to be send
x5bit	ds	1				    ; one bit counter
xbit	ds	1				    ; send bits counter
xcrcrem ds	1				    ; CRC remainder

xmitsub ds	1				    ; xmit control module xmit routine address store
pertim	ds	1				    ; xmit control module timer


	end
