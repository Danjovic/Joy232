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
; Version 1.1 25/11/2016 - cleanup, modified for tniASM and 
; added English notes for hackaday.io 1K contest

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
;BAUD: EQU 6   ; 19200 Bauds, (6)
;BAUD: EQU 10  ; 14400 Bauds, (10)
BAUD: EQU 18   ;  9600 Bauds, (17-19)
;BAUD: EQU 42  ;  4800 Bauds, (41-43)
;BAUD: EQU 92  ;  2400 Bauds, (90-93)
;BAUD: EQU 190 ;  1200 Bauds, (188-191)


;
;  Bits used in PSG register 15
;       7     6     5     4     3     2     1     0
;    +-----------------------------------------------+
;    ¦Kana ¦ Joy ¦Pulse¦Pulse¦PortB¦PortB¦PortA¦PortA¦
;    ¦ LED ¦ Sel ¦  B  ¦  A  ¦ pin7¦ pin6¦ pin7¦ pin6¦
;    +-----------------------------------------------+

BTXD:  EQU 2  ; bit 2 is the pin 6 from port B


; PSG IO addresses
PSGAD: EQU 0A0H
PSGWR: EQU 0A1H
PSGRD: EQU 0A2H

; ------------------------------------------------------------------------------
; 
;
; Tell the compiler which architecture is in use
CPU MSX

; Add header to make code loadable with 'bload' command
db 0x0FE
dw START, FINIS, INSTALA

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

PRNTJ232:
DI             ; disable interrupts as they can ruin the timing
PUSH AF        ; save registers used in the routine
PUSH BC
PUSH HL

LD C,A         ; Save register A which holds the byte to be printed
LD H,BAUD      ; Load delay value in register H

CALL SND232    ; Send the character through serial port

POP HL         ; restore used registers
POP BC
POP AF
AND A          ; Signal to BIOS that the byte was successfully printed

EI             ; Enable interrupts
INC SP         ; Discard stack to skip the original code that
INC SP         ; writes on printer port
RET

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

SND232:
; Inputs:
; C: Byte to be sent
; H: Delay balue for each bit. It defines the Baud Rate

LD A,15        ; Select PSG Register 15
OUT [PSGAD],A  ; 
IN A,[PSGRD]   ; save the present state of the bits from PSG register 15
		
;
; Send Start bit  (txd=0)
;
LD L,H        ; 4+1
CALL SND0     ; 17+1 + (SEND0)

;
; 8 bits to send, LSbit first
; takes the same time to send bits 0 or 1
;
LD B,08H      ; 7+1
S20:
LD L,H        ; 4+1
RRC C         ; 8+2
CALL C,SND1   ; 17+1 + (SEND0)/ 10+1 F   nice trick to keep time
CALL NC,SND0  ; 17+1 + (SEND0)/ 10+1 F   constant time
DJNZ S20      ; 13+1 b


;
; Send Stopbit - return txd line to IDLE
;
LD L,BAUD     ; 8
CALL SND1     ; 17+1  + (SEND1)
LD B,A        ; 4+1
RET           ; 10+1

;
; Send a bit 0
;
SND0:          ; txd=0
RES BTXD,A     ; 8+2
OUT [PSGWR],A  ; 11+1
S01: DEC L     ; 4+1
 JP NZ,S01     ; 10+1
RET            ; 10+1

;
; Send a bit 1
;
SND1:          ; txd=1
SET BTXD,A     ; 8+2
OUT [PSGWR],A  ; 11+1
S11: DEC L     ; 4+1
 JP NZ,S11     ; 10+1
RET            ; 10+1

; ------------------------------------------------------------------------------

;
; Install bitbang routine on printer HOOK
; Borrowed from the book "+50 dicas para o MSX"
;
HLPT: EQU 0FFB6H
;
INSTALA:
LD HL,PRNTJ232  ; Write the routine address first
LD [HLPT+1],HL
LD A,0C3H       ; then write the CALL instruction (0xC3)
LD [HLPT],A
RET


FINIS:
