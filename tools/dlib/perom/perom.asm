; program the PEROM (AT29C256) onboad the DSP CARD 4
; this program is downloaded into the DSP CARD 4 by DL, when the -f option
; is used (to program the PEROM)
; it will receive the image, check the CRC, and then will program the image
; into the PEROM (skipping those pages that are already equal to the image
; sent)
;
; Be careful!  this program must be assembled using the 'leonid' include
; file corresponding to the version of 'leonid' present in the PEROM
; BEFORE programming.  It must be re-assembled each time a new 'leonid'
; version has been loaded in the PEROM (when it changes the org addresses)
;
; (c) 1994 by Rob Janssen, PE1CHL  (using some material from 'leonid'
;                                       (c) by Jarkko Vuori, OH2LNS)
;
        title   'PEROM'
        opt     rc
        nolist
        include 'leonid'
        include 'ioequlc'
        list

rom     equ     $8000                           ; starting address of PEROM
romlen  equ     32768                           ; lenght of the PEROM (in by tes)
page    equ     64                              ; length of one page
pages   equ     romlen/page                     ; number of pages

xtal    equ     27000000                        ; xtal frequency

poly    equ     $8408                           ; HDLC CRC polynomial (x^16 + x^12 + x^5 + 1)
crcchk  equ     $f0b8                           ; special CRC checkword

; byte CRC calculation routine
; byte in x0, result in x:<crcrem
; modifies a, b, x1, y0, y1
crcbyte macro
        move    x0,b1
        move    #>$000001,x1
        move    #>poly,y1
        do      #8,_crc2

        move    b1,a1                           ; first LSB to remainder
        and     x1,a        x:<crcrem,y0
        eor     y0,a

        lsr     a                               ; XOR if needed
        jcc     _crc1
        eor     y1,a
_crc1   lsr     b           a1,x:<crcrem
_crc2
        endm

; macro for green LED handling
copled  macro   mode
        b\mode  #14,x:m_pbd
        endm

; macro for red LED handling
cmdled  macro   mode
        b\mode  #13,x:m_pbd
        endm

        org     p:user_code

; macro for immediate move
movi    macro   data,dest
        move    data,a1
        move    a1,dest
        endm


; entry point: acknowledge startup and prepare for image transfer
entry   nop                                     ; attempt to make entry point
        nop                                     ;   less critical (leonid
        nop                                     ;   versions have different
        nop                                     ;   user code org addresses)
        nop
        move    #>$47,x0                        ; send G
        putc

        movi    #$00ffff,x:<crcrem              ; prepare for CRC check
        move    #buffer,r4                      ; r4 = buffer pointer
        move    #0,r5                           ; r5 = word packing ptr
        move    #romlen,x0
        do      x0,receive
        getc                                    ; get one byte from RS232
        crcbyte                                 ; calculate CRC of byte in x0, result in x:<crcrem
        move    #>1,a                           ; see where it goes
        move    r5,x1
        cmp     x1,a        (r5)+
        jlt     <byte3
        jeq     <byte2
        move    #>@cvi(@pow(2,16-1)),x1         ; move to upper byte
        mpy     x0,x1,a
        move    a0,y:(r4)                       ; write xx0000 to memory
        jmp     <next

byte2   move    #>@cvi(@pow(2,8-1)),x1          ; move to middle byte
        mpy     x0,x1,a     y:(r4),y1
        move    a0,a1                           ; combine with upper byte
        or      y1,a
        move    a1,y:(r4)                       ; move xxyy00 to memory
        jmp     <next

byte3   move    y:(r4),a1
        or      x0,a
        move    a1,y:(r4)+                      ; move xxyyzz to memory
        move    #0,r5                           ; next triple
next    nop
receive move    #>crcchk,x0                     ; check CRC
        move    x:<crcrem,a
        cmp     x0,a
        jeq     <xferok

; CRC error in transferred ROM image
        move    #>$45,x0                        ; send E
        putc

; just sit idle until RESET
loop    wait
        jmp     loop

; Transfer was ok, double check from RAM to know for sure the image is OK
xferok  movi    #$00ffff,x:<crcrem              ; prepare for CRC check
        move    #buffer,r4                      ; r4 = buffer pointer
        move    #0,r5                           ; r5 = word packing ptr
        move    #romlen,x0
        do      x0,check
        jsr     <getbyte
        crcbyte
        nop
check   move    #>crcchk,x0                     ; check CRC
        move    x:<crcrem,a
        cmp     x0,a
        jeq     <ramok

; CRC was ok in transfer, bad in RAM -> RAM FAULT
        move    #>$46,x0                        ; send F
        putc

        jmp     loop

; CRC ok in RAM as well
ramok
again   move    #>$59,x0                        ; send Y
        putc

        cmdled  set
        movi    #0,x:errors

; now compare buffered data with PEROM, and program pages that differ
        move    #rom,r1                         ; r1 = PEROM pointer
        move    #buffer,r4                      ; r4 = buffer pointer
        move    #0,r5                           ; r5 = word packing ptr
        do      #pages,dopages
        clr     a
        move    r1,x:r1save                     ; save regs @ page start
        move    r4,x:r4save
        move    r5,x:r5save
        do      #page,dopage
        jsr     <getbyte
        move    x0,a1
        jsr     <rdromb
        eor     x0,a                            ; RAM ^ ROM to a1
        move    a0,x0
        or      x0,a                            ; keep accumulated xor
        move    a1,a0
dopage  clr     a           a0,x0
        cmp     x0,a
        jeq     <eqpage                         ; pages equal, skip

; a page with differing data has been found, program it
        move    #rom+$5555,r1                   ; enable programming
        move    #>$aa,x0
        jsr     <wrromb
        move    #rom+$2aaa,r1
        move    #>$55,x0
        jsr     <wrromb
        move    #rom+$5555,r1
        move    #>$a0,x0
        jsr     <wrromb
        move    x:r1save,r1                     ; back to page start
        move    x:r4save,r4
        move    x:r5save,r5
        do      #page,prpage
        jsr     <getbyte
        jsr     <wrromb                         ; load page data
        nop
prpage  move    x0,x1                           ; save last byte

; wait for the programming cycle to complete
        move    #>100,r0                        ; max milliseconds to wait

waitp   do      #@cvi(@sqt(xtal/2.0/1000.0)),del2 ; delay 1/1000s (1ms)
        do      #@cvi(@sqt(xtal/2.0/1000.0)),del1
        nop
del1    nop
del2
        move    (r1)-                           ; back to last address
        jsr     <rdromb
        move    x0,a                            ; verify D7
        eor     x1,a        #>$80,x0
        and     x0,a
        jeq     prcompl                         ; D7 okay, is complete

        move    (r0)-                           ; count attempts
        clr     a
        move    r0,x0
        cmp     x0,a
        jne     waitp                           ; check completion again

; verify the programmed page
prcompl clr     a
        move    x:r1save,r1                     ; back to page start
        move    x:r4save,r4
        move    x:r5save,r5
        do      #page,ckpage
        jsr     <getbyte
        move    x0,a1
        jsr     <rdromb
        eor     x0,a                            ; RAM ^ ROM to a1
        move    a0,x0
        or      x0,a                            ; keep accumulated xor
        move    a1,a0
ckpage  clr     a           a0,x0
        cmp     x0,a
        jeq     <okpage                         ; pages equal, ok

        move    x:errors,a                      ; count errors
        move    #>1,x0
        add     x0,a
        move    a1,x:errors

        move    #>$2d,x0                        ; error, send a -
        jmp     <epage

; page programmed OK
okpage  move    #>$2b,x0                        ; send a +
        jmp     <epage

eqpage  move    #>$2e,x0                        ; send a dot
epage   putc
        nop
dopages nop
        cmdled  clr

; check if errors remain
        clr     a           x:errors,x0
        cmp     x0,a
        jne     again                           ; errors, go again

; finally verify the CRC of the programmed PEROM
; (paranoid, aren't we?)
        move    #rom,r1
        movi    #$00ffff,x:<crcrem
        move    #romlen,x0
        do      x0,check1
        jsr     <rdromb
        crcbyte
        nop
check1  move    #>crcchk,x0                     ; check with special checkword
        move    x:<crcrem,a
        cmp     x0,a
        jne     again                           ; not ok, program again

        move    #>$51,x0                        ; done, send Q
        putc
        jmp     loop




; read one byte from the boot ROM (@r1) to x0
; modifies b, updates r1
rdromb  movep   #$00f0,x:m_bcr                  ; slow PEROM on P bank
        move    p:(r1)+,x0
        move    #$0000ff,b1                     ; mask unused databits off
        and     x0,b
        move    b1,x0
        movep   #$0000,x:m_bcr                  ; no more slow PEROM reads
        rts

; write one byte to the PEROM (@r1) from x0
; modifies b, updates r1
wrromb  movep   #$00f0,x:m_bcr                  ; slow PEROM on P bank
        move    x0,p:(r1)+
        movep   #$0000,x:m_bcr                  ; no more slow PEROM
        rts

; get a byte from the buffer (@r4, byte r5)
; modifies b, updates r4/r5
getbyte move    #>1,b                           ; from where?
        move    r5,x0
        cmp     x0,b        (r5)+
        move    y:(r4),b                        ; get word
        move    #>$0000ff,x0                    ; prepare for later masking
        jlt     <gbyte3
        jeq     <gbyte2
        rep     #16                             ; take upper byte
        lsr     b
        and     x0,b
        move    b1,x0
        rts

gbyte2  rep     #8                              ; take middle byte
        lsr     b
        and     x0,b
        move    b1,x0
        rts

gbyte3  and     x0,b        (r4)+               ; take lower byte, next
        move    b1,x0
        move    #0,r5
        rts



; variables

        org     x:user_data

        dsm     16
crcrem  ds      1
errors  ds      1
r1save  ds      1
r4save  ds      1
r5save  ds      1

        ds      1

        org     y:user_data

        dsm     16
buffer  ds      romlen/3+1                      ; holds the image

        ds      1

        end
