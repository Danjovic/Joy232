; ------------------------------------------------------------------------------
;  Joy232:
;
;  Resident routine for serial print
;  using Joystick port on MSX computers
;
; danjovic@hotmail.com
; http://hotbit.blogspot.com
;
; Version 1.0 14/01/2008
; Version 1.1 25/11/2016 - cleanup, modified for tniASM  and 
;                          added English notes for hackaday.io 1K contest
; Vesrion 1.2 10/12/2016 - optimize code size and timing, make code relocatable
;                        - TXD pin changed to Port1 Trigger A (pin 6)
;                        - hook code moved to unused RS232 queue



; Released under GNU GPL 2.0
;
; tniASM website:
; http://www.tni.nl/products/tniasm.html
;
; 
; 
;
; ------------------------------------------------------------------------------
; Definitions
;
; Possible BaudRates
; It might be necessary to trim these values
; for machines from other countries due to
; differences in Z80 clock which is usually
; tied to chroma subcarrier
;
;
T1200:   EQU 170  ;  1200 bauds
T2400:   EQU  83  ;  2400 bauds
T4800:   EQU  39  ;  4800 bauds
T9600:   EQU  17  ;  9600 bauds
T14400:  EQU  10  ; 14400 bauds
T19200:  EQU   6  ; 19200 bauds



;
;  Bit assignment in PSG register 15
;       7     6     5     4     3     2     1     0
;    +-----------------------------------------------+
;    ¦Kana ¦ Joy ¦Pulse¦Pulse¦PortB¦PortB¦PortA¦PortA¦
;    ¦ LED ¦ Sel ¦  B  ¦  A  ¦ pin7¦ pin6¦ pin7¦ pin6¦
;    +-----------------------------------------------+


; PSG IO addresses
PSGAD: EQU 0A0H
PSGWR: EQU 0A1H
PSGRD: EQU 0A2H

; ------------------------------------------------------------------------------
; 
;
; Tell the compiler which architecture is in use
CPU Z80

; Add header to make code loadable with 'bload' command
db 0x0FE
dw START, FINIS, INSTALL

;
; Address of execution. Can be changed to more convenient place
ORG 0E000H
START:


; ------------------------------------------------------------------------------
; Hook Code
;
; This routine is called from HLPT hook. At this point register A holds
; the character to be sent to printer port.
;

HOOK_PRNTJ232:
DI             ; disable interrupts as they can ruin the timing
PUSH AF        ; save registers used in the routine
PUSH BC
PUSH HL

LD L,A         ; Save register A which holds the byte to be printed

; Select PSG Register 15
LD A,15
OUT [PSGAD],A


; ------------------------------------------------------------------------------
; Bitbang code
;
; Send the character in register A through
; pin 6 from Joystick port B using 8N1 signaling
;
; Timing in MSX computers is tricky because the standard requires one wait state
; to be inserted at each machine cycle. Then it is necessary to check how many
; M1 cycles happens on each instruction and add them to to sum to know exactly
; how many clock cycles will be spent.


; Prepare stream of bits
LD H,255; Add stop bits
AND A   ; clear carry flag
RL L    ; Add start bit and send 7th bit to carry
RL H    ; Send 7th bit to H register
        ; HL register is now
        ; ------------ H -----------    ----------- L ---------
        ; 16 15 14 13 12 11 10  9  8    7  6  5  4  3  2  1  0
        ;  1  1  1  1  1  1  1 stp b7   b6 b5 b4 b3 b2 b1 b0 start


; Now loop through 10 bits [1 extra to compensate time at the end of the loop]
LD B,10+1  ; poke here with 12 to send two stop bits instead of only one

SEND_BITS:
   ; prepare mask ; Cycles  Accumul
   IN A,[PSGRD]   ;  14     24      save the present state of the bits from PSG register 15
   RES 0,A        ;  10             clear bit 0

   ; 16 bit rotate
   RR H           ;  10     20      H.0->Cy (bit 0 from H goes to carry)
   RR L           ;  10             Cy->L.7, L.0->Cy

   ; set TXD line state
   ADC A,0        ;   8     20      A.0 now equals Cy
   OUT [PSGWR],A  ;  12             write bit to output. Here starts the cycle counting

   ; delay 1 bit time
   LD C,T9600     ;   8     8      poke here to change the baud rate
   DELAY_C:
   DEC C          ; ( 5)
   JR NZ,DELAY_C  ; (12)(/7)
                  ;  (12+5)*(TDelay-1)+(7+5) = 17*TDelay - 17 + 12 = (17*Tdelay-5)

DJNZ SEND_BITS    ; 14(/9)         send next bit


                  ;Total: 8+17*Tdelay-5+14+24+20+20 cycles from start of the bit to the next
                  ;       except the last stop bit which takes 8+7+9 cycles.
                  ;
                  ;       in numbers each bit takes:         81+17*TDelay  cycles
                  ;       except last stop bit which takes   17+17*TDelay  cycles

                  ;
                  ; after the last bit we have:  8+(16*Tbaud) + 9
                  ;                              =  17 + (16*Tbaud) cycles
                  ;
                  ; we're missing 86-17 = 55 cycles that's why we added 1 to ensure that
                  ; at least 1 stop bit time has passed before we return

POP HL         ; restore used registers
POP BC
POP AF
AND A          ; Signal to BIOS that the byte was successfully printed

EI             ; Enable interrupts
INC SP         ; Discard stack to skip the original code that
INC SP         ; writes on printer port

RET
HOOK_END:




; ------------------------------------------------------------------------------

;
; Install bitbang routine on printer HOOK
; Borrowed from the book "+50 dicas para o MSX"
;
HLPT:  EQU 0FFB6H ; Printer hook entry
RS2IQ: EQU 0FAF5H ; RS232 queue, 64 bytes

;
INSTALL:
LD HL, HOOK_PRNTJ232             ; beginning of hook code
LD DE, RS2IQ                     ; destiny, unused rs232 queue
LD BC, HOOK_END-HOOK_PRNTJ232  ; block size
LDIR                             ; transfer hook code to its new location


LD HL,RS2IQ     ; Write the execution entry point for printer hook
LD [HLPT+1],HL
LD A,0C3H       ; then write the CALL instruction (0xC3)
LD [HLPT],A
RET


FINIS:
