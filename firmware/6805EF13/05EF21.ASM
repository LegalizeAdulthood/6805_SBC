        .TITLE  "6805 eForth"
        .PAGE
        .MSFIRST


;===============================================================
;       6805 eForth 2.01, 3/17/99, C. H. Ting
;       Subroutine thread model, optimized for speed.
;
;       6805 eForth 1.01, 3/12/99, C. H. Ting
;       This implementation is dervied from
;       8051 eForth 1.1 by C. H. Ting, 1990
;       RAFOS Forth 1.0 by Everett Carter, 1986
;
;       It is assembled by TASM (Squak Valley Software) using the commands:
;        TASM -05 -g2 -s EF.TXT
;       which produces a S19 object file for memory E000-FFFF.
;       
;       The entire Forth system is copied from E100 to 100H and
;       executed in the RAM region 0-2000H. A few words are self-modifying.
;       The data stack is in 2000-20FFH.
;       The return stack and TIB is in 2100-21FFH.
;       Dictionary is extended upward from 2200H.
;
;       6805 is a slow processor.  Do not expect great performance
;       of this implementation, considering that most words are in high
;       level.  Your are encouraged to recode some of the high level words
;       to optimize its performance.
;
;       Direct your questions and contributions to:
;
;        Dr. C. H. Ting
;        156 14th Avenue
;        San Mateo, CA 94402
;        (415) 571-7639
;
;===============================================================

;; Version control

VER        .EQU     02H        ;major release version
EXT        .EQU     01H        ;minor extension

;; Constants

COMPO        .EQU     040H        ;lexicon compile only bit
IMEDD        .EQU     080H        ;lexicon immediate bit
MASKK        .EQU     01F7FH        ;lexicon bit mask, big endian*****
COMP        .EQU     04000H        ;lexicon compile only bit
IMED        .EQU     08000H        ;lexicon immediate bit
         
CELLL        .EQU     2         ;size of a cell
BASEE        .EQU     10        ;default radix
VOCSS        .EQU     8         ;depth of vocabulary stack

BKSPP        .EQU     8         ;backspace
LF        .EQU     10        ;line feed
CRR        .EQU     13        ;carriage return
ERR        .EQU     27        ;error escape
TIC        .EQU     39        ;tick

CALLL        .EQU     0CDH        ;JSR opcodes******

;; Memory allocation    0//code>--//--<name//up>--<sp//tib>--rp//em

EM        .EQU     0A000H        ;top of RAM memory******
COLDD        .EQU     100H        ;cold start vector******

US        .EQU     100H        ;user area size in cells
RTS        .EQU     100H        ;return stack/TIB size
DTS        .EQU     100H        ;data stack size

UPP        .EQU     0100H        ;start of user area (UP0)
TIBB        .EQU     80H        ;terminal input buffer (TIB)
RPP        .EQU     2100H        ;start of return stack (RP0)
SPP        .EQU     2000H        ;start of data stack (SP0)
NAMEE        .EQU     1FEEH        ;initial name dictionary******
CODEE        .EQU     100H        ;initial code dictionary******

;CR       .EQU    $0D        ; CARRIAGE RETURN
BS       .EQU    $08        ;Back Space
DEL      .EQU    $7F        ;Delete
; 
DDR      .EQU    4        ;DATA DIRECTION REGISTER OFFSET 
; 
PORTA    .EQU    0        ;I/O PORT 0 
PORTB    .EQU    1        ;I/O PORT 1 
PUT      .EQU    PORTB        ;SERIAL I/O PORT
;
INITSP   .EQU    $7F        ;INITIAL STACK POINTER VALUE
STACK    .EQU    INITSP-5     ;TOP OF STACK 
MEMSIZ   .EQU    $2000        ;MEMORY ADDRESS SPACE SIZE
; 
SP0      .EQU    $2000 
RP0      .EQU    $2100 
; 
; 
; 
;     RAM VARIABLES 
; 
; 
SP       .EQU $10        ;THE FORTH INSTRUCTION POINTER
RP       .EQU $11        ;THE RETURN POINTER OFFSET
LP       .EQU $12        ;THE STACK POINTER OFFSET
ATEMP    .EQU    $13        ;TEMP USED IN PUTDEC
XTEMP    .EQU    $14        ;INDEX TEMPORARY
GETR     .EQU    $15        ;PICK & DROP TEMPORARY
COUNTT    .EQU    $16        ;NUMBER OF BITS LEFT TO get/send
CHARR     .EQU    $17        ;Current input/output character 
PH       .EQU $18        ;MISC SCRATCH AREAS 
PL       .EQU $19 
TEMPA    .EQU $1A 
TEMPB    .EQU $1B
QH       .EQU $1C
QL       .EQU $1D
TEMPC    .EQU $1E
OUTC    .EQU $1F
;


;; Initialize assembly variables

ULINK   = 0             ;force a null link
UNAME   = NAMEE            ;initialize name pointer
UCODE   = CODEE            ;initialize code pointer
UUSER   = 8            ;first user variable offset

;; Define assembly macros

;       Compile a code definition header.

#DEFINE CODE(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL

;       Compile a colon definition header.

#DEFINE COLON(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL DEC RP\ DEC RP
;       Compile a user variable header.

#DEFINE USER(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL JSR DOUSE\ .DW UUSER\UUSER .SET UUSER+2

#DEFINE RETURN JMP RTRN

;; Main entry points and COLD start data

        .ORG    COLDD

UZERO:  .DW     0,0,0,0
        .DW      0E0H        ;SP0
        .DW      100H        ;RP0, LP0
        .DW      QRX        ;'?KEY
        .DW      TXSTO        ;'EMIT
        .DW      ACCEP        ;'EXPECT
        .DW      KTAP        ;'TAP
        .DW      TXSTO        ;'ECHO
        .DW      DOTOK        ;'PROMPT
        .DW      BASEE        ;BASE
        .DW      0         ;tmp
        .DW      0         ;SPAN
        .DW      0         ;>IN
        .DW      0         ;#TIB
        .DW      TIBB        ;TIB
        .DW      0         ;CSP
        .DW      INTER        ;'EVAL
        .DW      NUMBQ        ;'NUMBER
        .DW      0         ;HLD
        .DW      0         ;HANDLER
        .DW      0         ;CONTEXT pointer
        .DW     0,0,0,0,0,0,0,0
        .DW      0         ;CURRENT pointer
        .DW      0         ;vocabulary link pointer
        .DW      CTOP         ;CP******
        .DW      SPP-DTS        ;NP
        .DW      LASTN        ;LAST
        .DW      LASTN        ;FORTH
        .DW      0,0       ;vocabulary link
ULAST:

START   BSET 3,$05        ;copy 192 bytes to RAM first
        BSET 3,PUT
        CLRX
SDAT    LDA 0E100H,X
        STA 100H,X
        DECX
        BNE SDAT
        BCLR 3,PUT
        JMP COPYROM        ;jump to RAM to--
        
COPYROM        ;copy rest of ROM to RAM
        LDA #1EH
        STA COUNTT
CPY1    CLRX
CPY2    LDA 0E200H,X
CPY3    STA 200H,X
        INCX
        BNE CPY2
        LDA CPY2+1
        INCA
        STA CPY2+1
        LDA CPY3+1
        INCA
        STA CPY3+1
;        AND #1
;        BNE CPY4
;        BCLR 3,PUT      ;toggle PUT.3 for monitoring
;        BRA CPY5
;CPY4    BSET 3,PUT
;CPY5
        DEC COUNTT
        BNE CPY1
        LDA #0E0H       ;SP 80-dfh
        STA SP
        LDA #080H       ;align to hardware stack
        STA RP          ;20-7fh
        CLRA
        STA LP          ;LP e0-ffh
        RSP
;TEST    LDA #41H        ;test serial port
;        JSR PUTC
;        LDA #CRR
;        JSR PUTC
;        LDA #LF
;        JSR PUTC        
        JMP COLD1       ;sign-on
WARM    LDA #0E0H       ;SP 80-dfh, abort to here
        STA SP
        LDA #080H       ;align to hardware stack
        STA RP          ;20-7fh
        CLRA
        STA LP          ;LP e0-ffh
        RSP
        JMP COLD2       ;skip sign-on


;
LOAD    STA SP0,X         ;STA (HERE),X
        RTS           ;move A to HERE+X
;
GET     LDA SP0,X         ;LDA (HERE),X
        RTS           ;get HERE+X into A
;
RTRN    INC RP
        INC RP
        RTS

;; The kernel

;   doLIT       ( -- w )
;        Push an inline literal.

        CODE(COMPO+5,"doLIT",DOLIT)
	LDX RP		;read address from return stack
	DECX
	LDA ,X
	STA GET+2
	DECX
	LDA ,X
	STA GET+1
	LDX #1		;get incline data
	JSR GET
	LDX SP		;push on data stack
	DECX
	STA ,X
	CLRX
	JSR GET
	LDX SP
	DECX
	DECX
	STA ,X
	STX SP
BUMP	LDX RP		;bump address on return stack
	DECX
	LDA ,X
        ADD #2
	STA ,X
	DECX
	LDA ,X
	ADC #0
	STA ,X
	RTS

;   doLIST      ( a -- )
;        Process colon list.
;	Not needed in subroutine thread code.

;   next        ( -- )
;        Run time code for the single index loop.
;        : next ( -- ) \ hilevel model
;        r> r> dup if 1 - >r @ >r exit then drop cell+ >r ;

        CODE(COMPO+4,"next",DONXT)
        LDX LP
        LDA ,X
        INCX
        ORA ,X
        TSTA
        BEQ NXT1
        LDA ,X
        SUB #1
        STA ,X
        DECX
        LDA ,X
        SBC #0
        STA ,X
        JMP BRAN
NXT1    INCX 
	STX LP 
	JMP BUMP

;   ?branch     ( f -- )
;        Branch if flag is zero.

        CODE(COMPO+7,"?branch",QBRAN)
        LDX SP
        LDA ,X
        INCX
        ORA ,X
        INCX
        STX SP
        TSTA
        BEQ BRAN
        JMP BUMP

;   branch      ( -- )
;        Branch to an inline address.

        CODE(COMPO+6,"branch",BRAN)
	LDX RP		;read address from return stack
	DECX
	LDA ,X
	STA GET+2
	DECX
	LDA ,X
	STA GET+1
	LDX #1		;get incline data
	JSR GET
	LDX RP		;push on data stack
	DECX
	STA ,X
	CLRX
	JSR GET
	LDX RP
	DECX
	DECX
	STA ,X
	RTS

;   EXECUTE     ( ca -- )
;        Execute the word at ca.

        CODE(7,"EXECUTE",EXECU)
        LDX SP        ;Pop SP into W (NEXT1+1)
        LDA ,X        ;First high byte
        INCX
        STA EXE1+1
        LDA ,X        ;Then low byte
        INCX
        STA EXE1+2
        STX SP
EXE1    JMP LOAD


;   EXIT        ( -- )
;        Terminate a colon definition.
;	RTS will do.


;   !        ( w a -- )
;        Pop the data stack to memory.

        CODE(1,"!",STORE)
        LDX SP        ;move addr to Load
        LDA ,X
        INCX
        STA LOAD+1
        LDA ,X
        INCX
        STA LOAD+2
        LDA ,X        ;now move data to addr
        INCX        ;high byte first
        STX SP
        CLRX
        JSR LOAD
        LDX SP
        LDA ,X        ;now the low byte
        INCX
        STX SP
        LDX #1
        JMP LOAD

;   @        ( a -- w )
;        Push memory location to the data stack.

        CODE(1,"@",AT)
       LDX SP
       LDA ,X
       INCX
       STA GET+1
       LDA ,X
       STA GET+2
       STX SP
       LDX #1        ;get low byte
       JSR GET
       LDX SP
       STA ,X
       CLRX        ;get high byte
       JSR GET
       LDX SP
       DECX
       STA ,X
       STX SP
       RTS

;   C!        ( c b -- )
;        Pop the data stack to byte memory.

        CODE(2,"C!",CSTOR)
      LDX SP        ;move addr to Load
      LDA ,X
      INCX
      STA LOAD+1
      LDA ,X
      INCX
      STA LOAD+2
      INCX        ;drop high data byte
      LDA ,X        ;and move low byte
      INCX
      STX SP
      CLRX
      JMP LOAD

;   C@        ( b -- c )
;        Push byte memory location to the data stack.

        CODE(2,"C@",CAT)
       LDX SP
       LDA ,X
       INCX
       STA GET+1
       LDA ,X
       STA GET+2
       STX SP
       CLRX        ;get the byte
       JSR GET
       LDX SP
       STA ,X
       CLRA        ;zero high byte
       DECX
       STA ,X
       STX SP
       RTS

;   >R        ( w -- )
;        Push the data stack to the return stack.

        CODE(COMPO+2,">R",TOR)
       LDX SP
       LDA ,X
       INCX
       STA ATEMP
       LDA ,X
       INCX
       STX SP
       LDX LP
       DECX
       STA ,X
       LDA ATEMP
       DECX
       STA ,X
       STX LP
       RTS

;   R@        ( -- w )
;        Copy top of return stack to the data stack.

        CODE(2,"R@",RAT)
       LDX LP
       LDA ,X       ;pop high
       INCX
       STA ATEMP
       LDA ,X       ;pop low
       LDX SP
       DECX
       STA ,X       ;push low
       LDA ATEMP
       DECX
       STA ,X       ;push high
       STX SP
       RTS

;   R>        ( -- w )
;        Pop the return stack to the data stack.

        CODE(2,"R>",RFROM)
       LDX LP
       LDA ,X
       INCX
       STA ATEMP
       LDA ,X
       INCX
       STX LP
       LDX SP
       DECX
       STA ,X
       LDA ATEMP
       DECX
       STA ,X
       STX SP
       RTS

;   RP@        ( -- a )
;        Push the current RP to the data stack.

        CODE(3,"RP@",RPAT)
        LDX SP
        DECX
        LDA LP
        STA ,X
        DECX
        STX SP
        CLRA
        STA ,X
        RTS

;   RP!        ( a -- )
;        Set the return stack pointer.

        CODE(COMPO+3,"RP!",RPSTO)
        LDX SP
        INCX
        LDA ,X
        STA LP
        INCX
        STX SP
        RTS

;   SP@        ( -- a )
;        Push the current data stack pointer.

        CODE(3,"SP@",SPAT)
        LDX SP
        DECX
        LDA SP
        STA ,X
        DECX
        STX SP
        CLRA
        STA ,X
        RTS

;   SP!        ( a -- )
;        Set the data stack pointer.

        CODE(3,"SP!",SPSTO)
        LDX SP
        INCX        
        LDA ,X
        STA SP
        RTS

;   DUP        ( w -- w w )
;        Duplicate the top stack item.

        CODE(3,"DUP",DUPP)
      LDX SP
      LDA ,X        ;get high byte
      DECX        ;and bump SP to point to new location
      DECX
      STA ,X        ;then store it
      LDX SP
      INCX        ;get low byte
      LDA ,X
      DECX        ;bump SP for it too
      DECX
      STA ,X        ;and store it
      DECX        ;update SP
      STX SP
      RTS

;   DROP        ( w -- )
;        Discard top stack item.

        CODE(4,"DROP",DROP)
       LDX SP
       INCX
       INCX
       STX SP
       RTS

;   SWAP        ( w1 w2 -- w2 w1 )
;        Exchange top two stack items.

        CODE(4,"SWAP",SWAP)
      LDX SP
      LDA ,X
      INCX
      STA PH
      LDA ,X
      INCX
      STA PL
      LDA ,X
      INCX
      STA QH
      LDA ,X
      STA QL
      LDA PL
      STA ,X
      LDA PH
      DECX
      STA ,X
      LDA QL
      DECX
      STA ,X
      LDA QH
      DECX
      STA ,X
      RTS

;   OVER        ( w1 w2 -- w1 w2 w1 )
;        Copy second stack item to top.

        CODE(4,"OVER",OVER)
       LDX SP
       INCX
       INCX
       LDA ,X
       INCX
       STA ATEMP
       LDA ,X
       LDX SP
       DECX
       STA ,X
       LDA ATEMP
       DECX
       STA ,X
       STX SP
       RTS

;   0<        ( n -- t )
;        Return true if n is negative.

        CODE(2,"0<",ZLESS)
       LDX SP
       LDA ,X
       TSTA
       BPL ZLPOS
       LDA #$FF
       BRA ZLXIT
ZLPOS  CLRA
ZLXIT  STA ,X
       INCX
       STA ,X
       RTS

;   AND        ( w w -- w )
;        Bitwise AND.

        CODE(3,"AND",ANDD)
       LDX SP
       LDA ,X
       INCX
       INCX
       AND ,X
       STA ,X
       DECX
       LDA ,X
       INCX
       INCX
       AND ,X
       STA ,X
       DECX
       STX SP
       RTS

;   OR        ( w w -- w )
;        Bitwise inclusive OR.

        CODE(2,"OR",ORR)
       LDX SP
       LDA ,X
       INCX
       INCX
       ORA ,X
       STA ,X
       DECX
       LDA ,X
       INCX
       INCX
       ORA ,X
       STA ,X
       DECX
       STX SP
       RTS

;   XOR        ( w w -- w )
;        Bitwise exclusive OR.

        CODE(3,"XOR",XORR)
       LDX SP
       LDA ,X
       INCX
       INCX
       EOR ,X
       STA ,X
       DECX
       LDA ,X
       INCX
       INCX
       EOR ,X
       STA ,X
       DECX
       STX SP
       RTS

;   UM+        ( w w -- w cy )
;        Add two numbers, return the sum and carry flag.

        CODE(3,"UM+",UPLUS)
       LDX SP
       LDA ,X
       STA PH
       INCX
       LDA ,X
       INCX
       INCX        ;point to low on stack
       ADD ,X
       STA ,X
       DECX
       LDA PH
       ADC ,X
       STA ,X
        DECX
        CLRA
        ADC #0
        STA ,X
        CLRA
        DECX
        STA ,X
       RTS

;; Device dependent I/O

;
DELAYS   .DB  $20        ; 300 BAUD
        .DB  $08        ;1200 BAUD
        .DB  $01        ;9600 BAUD
;
;     GETCHAR/GETC --- GET A CHARACTER FROM THE TERMINAL
; 
;     A GETS THE CHARACTER TYPED, X IS UNCHANGED
; 
GETC     STX XTEMP
GETCHAR  .EQU GETC
        LDA #8
        STA COUNTT
GETC4    CLI
        SEI
        BRSET 2,PUT,GETC4
        LDA #1        ;1200 baud, was LDA PUT
        AND #%11
        TAX
        LDX DELAYS,X     ;        load Baud delay
GETC3    LDA #4
GETC2    DECA
        BNE GETC2
        TSTA
        DECX
        BNE GETC3
        BRSET 2,PUT,GETC4
        TST ,X
        TST ,X
GETC7    BSR  DELAY
        BRCLR 2,PUT,GETC6
GETC6    TST ,X
        ROR CHARR
        DEC COUNTT
        BNE GETC7
        CLI
        BSR DELAY
        LDA CHARR
        AND    #$7F       ;  Mask the eighth bit. 
        LDX XTEMP
        RTS
; 
; 
; 
;     OUTCHAR/PUTC --- PRINT A ON THE TERMINAL
; 
;     X AND A UNCHANGED 
; 
PUTC     STA CHARR
OUTCHAR  .EQU PUTC
        STA ATEMP
        STX XTEMP
        LDA #9
        STA COUNTT
        CLRX
        CLC
        SEI
        BRA PUTC2
PUTC5    ROR CHARR
PUTC2    BCC PUTC3
        BSET 3,PUT
        BRA PUTC4
PUTC3    BCLR 3,PUT
        BRA PUTC4
PUTC4    JSR DELAY,X
        DEC COUNTT
        BNE PUTC5
        BSET 2,PUT
        BSET 3,PUT
        CLI
        BSR DELAY
        LDX XTEMP
        LDA ATEMP
        RTS
; 
; 
;     WAIT --- PRECISE DELAY
;        A AND X ARE ZERO AT EXIT. 
; 
WAIT     LDA    #1        ; ADJUST FOR FIRST TIME
DELAY    .EQU WAIT
        AND #%11
        TAX
        LDX DELAYS,X
        LDA #$F9
DEL3     ADD #$08
DEL2     DECA
        BNE DEL2
        TSTX
        BSET 1,PUT
        DECX
        BNE DEL3
        LDA #0
        RTS

;   ?RX        ( -- c T | F )
;        Return input character and true, or a false if no input.

        CODE(3,"?RX",QRX)
        JSR GETC
;        LDA #$0D
        LDX SP
        DECX
        STA ,X
        DECX
        CLRA
        STA ,X
        DECX
        DECA
        STA ,X
        DECX
        STX SP
        STA ,X
        RTS

;   TX!        ( c -- )
;        Send character c to the output device.

        CODE(3,"TX!",TXSTO)
        LDX SP
        INCX
        LDA ,X
        INCX
        STX SP
        JSR PUTC
;        LDX OUTC
;        STA $2000,X
;        INC OUTC
        RTS



;; System and user variables

;   doVAR       ( -- a )
;        Run time routine for VARIABLE and CREATE.

        CODE(COMPO+5,"doVAR",DOVAR)
        DEC RP
        DEC RP
	LDX RP
	DECX
	LDA ,X
	STA ATEMP
	DECX
	LDA ,X
	LDX SP
	DECX
	DECX
	STA ,X
	STX SP
	INCX
	LDA ATEMP
	STA ,X
BACK    LDA #(UNFOLD-(UNFOLD/100H*100H)) ;get rid of the return address
	LDX RP
	DECX 
	STA ,X
        LDA #UNFOLD/100H
	DECX
	STA ,X
        INC RP
        INC RP
UNFOLD	RTS

;  doUSER      ( -- a )
;        Run time routine for user variables.

        CODE(COMPO+6,"doUSER",DOUSE)
        DEC RP
        DEC RP
	LDX RP		;read address from return stack
	DECX
	LDA ,X
	STA GET+2
	DECX
	LDA ,X
	STA GET+1
	LDX #1		;get incline data
	JSR GET
	LDX SP		;push on data stack
	DECX
        STA ,X
        DECX
	LDA #1		;user area at 100H
	STA ,X
	STX SP
	JMP BACK		;get rid of the return address

;   SP0        ( -- a )
;        Pointer to bottom of the data stack.

        USER(3,"SP0",SZERO)

;   RP0        ( -- a )
;        Pointer to bottom of the return stack.

        USER(3,"RP0",RZERO)

;   '?KEY       ( -- a )
;        Execution vector of ?KEY.

        USER(5,"\047?KEY",TQKEY)

;   'EMIT       ( -- a )
;        Execution vector of EMIT.

        USER(5,"\047EMIT",TEMIT)

;   'EXPECT     ( -- a )
;        Execution vector of EXPECT.

        USER(7,"\047EXPECT",TEXPE)

;   'TAP        ( -- a )
;        Execution vector of TAP.

        USER(4,"\047TAP",TTAP)

;   'ECHO       ( -- a )
;        Execution vector of ECHO.

        USER(5,"\047ECHO",TECHO)

;   'PROMPT     ( -- a )
;        Execution vector of PROMPT.

        USER(7,"\047PROMPT",TPROM)

;   BASE        ( -- a )
;        Storage of the radix base for numeric I/O.

        USER(4,"BASE",BASE)

;   tmp        ( -- a )
;        A temporary storage location used in parse and find.

        USER(COMPO+3,"tmp",TEMP)

;   SPAN        ( -- a )
;        Hold character count received by EXPECT.

        USER(4,"SPAN",SPAN)

;   >IN        ( -- a )
;        Hold the character pointer while parsing input stream.

        USER(3,">IN",INN)

;   #TIB        ( -- a )
;        Hold the current count and address of the terminal input buffer.

        USER(4,"#TIB",NTIB)
UUSER   .SET UUSER+CELLL

;   CSP        ( -- a )
;        Hold the stack pointer for error checking.

        USER(3,"CSP",CSP)

;   'EVAL       ( -- a )
;        Execution vector of EVAL.

        USER(5,"\047EVAL",TEVAL)

;   'NUMBER     ( -- a )
;        Execution vector of NUMBER?.

        USER(7,"\047NUMBER",TNUMB)

;   HLD        ( -- a )
;        Hold a pointer in building a numeric output string.

        USER(3,"HLD",HLD)

;   HANDLER     ( -- a )
;        Hold the return stack pointer for error handling.

        USER(7,"HANDLER",HANDL)

;   CONTEXT     ( -- a )
;        A area to specify vocabulary search order.

        USER(7,"CONTEXT",CNTXT)
UUSER   .SET UUSER+16       ;vocabulary stack

;   CURRENT     ( -- a )
;        Point to the vocabulary to be extended.

        USER(7,"CURRENT",CRRNT)
UUSER   .SET UUSER+CELLL        ;vocabulary link pointer

;   CP        ( -- a )
;        Point to the top of the code dictionary.

        USER(2,"CP",CP)

;   NP        ( -- a )
;        Point to the bottom of the name dictionary.

        USER(2,"NP",NP)

;   LAST        ( -- a )
;        Point to the last name in the name dictionary.

        USER(4,"LAST",LAST)

;   forth       ( -- a )
;        Point to the last name in the name dictionary.

        USER(5,"forth",VFRTH)

;; Common functions

;   FORTH       ( -- )
;        Make FORTH the context vocabulary.

        COLON(5,"FORTH",FORTH)
        JSR      VFRTH
        JSR     CNTXT
        JSR     STORE
        RETURN

;   ?DUP        ( w -- w w | 0 )
;        Dup tos if its is not zero.

        COLON(4,"?DUP",QDUP)
        JSR      DUPP
        JSR      QBRAN
        .DW     QDUP1
        JSR      DUPP
QDUP1:        RETURN

;   ROT        ( w1 w2 w3 -- w2 w3 w1 )
;        Rot 3rd item to top.

        COLON(3,"ROT",ROT)
        JSR      TOR
        JSR     SWAP
        JSR     RFROM
        JSR     SWAP
        RETURN

;   2DROP       ( w w -- )
;        Discard two items on stack.

        COLON(5,"2DROP",DDROP)
        JSR      DROP
        JSR     DROP
        RETURN

;   2DUP        ( w1 w2 -- w1 w2 w1 w2 )
;        Duplicate top two items.

        COLON(4,"2DUP",DDUP)
        JSR      OVER
        JSR     OVER
        RETURN

;   +        ( w w -- sum )
;        Add top two items.

        CODE(1,"+",PLUS)
       LDX SP
       LDA ,X
       INCX
       STA PH
       LDA ,X
       INCX
       STX SP
       INCX        ;point to low on stack
       ADD ,X
       STA ,X
       LDX SP
       LDA PH
       ADC ,X
       STA ,X
       RTS

;   NOT        ( w -- w )
;        One"s complement of tos.

        COLON(3,"NOT",INVER)
        JSR      DOLIT
        .DW     -1
        JSR     XORR
        RETURN

;   NEGATE      ( n -- -n )
;        Two"s complement of tos.

        COLON(6,"NEGATE",NEGAT)
        JSR      INVER
        JSR     DOLIT
        .DW     1
        JSR     PLUS
        RETURN

;   DNEGATE     ( d -- -d )
;        Two"s complement of top double.

        COLON(7,"DNEGATE",DNEGA)
        JSR      INVER
        JSR     TOR
        JSR     INVER
        JSR      DOLIT
        .DW     1
        JSR     UPLUS
        JSR      RFROM
        JSR     PLUS
        RETURN

;   -        ( n1 n2 -- n1-n2 )
;        Subtraction.

        CODE(1,"-",SUBB)
       LDX SP
       LDA ,X
       INCX
       STA PH
       LDA ,X
       INCX
       STA PL
       STX SP
       INCX        ;point to low on stack
       LDA ,X
       SUB PL
       STA ,X
       LDX SP
       LDA ,X
       SBC PH
       STA ,X
       RTS

;   ABS        ( n -- n )
;        Return the absolute value of n.

        COLON(3,"ABS",ABSS)
        JSR      DUPP
        JSR     ZLESS
        JSR      QBRAN
        .DW     ABS1
        JSR      NEGAT
ABS1:        RETURN

;   =        ( w w -- t )
;        Return true if top two are equal.

        COLON(1,"=",EQUAL)
        JSR      XORR
        JSR      QBRAN
        .DW     EQU1
        JSR      DOLIT
        .DW     0
        RETURN        ;false flag
EQU1:        JSR      DOLIT
        .DW     -1
        RETURN        ;true flag

;   U<        ( u u -- t )
;        Unsigned compare of top two items.

        COLON(2,"U<",ULESS)
        JSR      DDUP
        JSR     XORR
        JSR     ZLESS
        JSR      QBRAN
        .DW     ULES1
        JSR      SWAP
        JSR     DROP
        JSR     ZLESS
        RETURN
ULES1:        JSR      SUBB
        JSR     ZLESS
        RETURN

;   <        ( n1 n2 -- t )
;        Signed compare of top two items.

        COLON(1,"<",LESS)
        JSR      DDUP
        JSR     XORR
        JSR     ZLESS
        JSR      QBRAN
        .DW     LESS1
        JSR      DROP
        JSR     ZLESS
        RETURN
LESS1:        JSR      SUBB
        JSR     ZLESS
        RETURN

;   MAX        ( n n -- n )
;        Return the greater of two top stack items.

        COLON(3,"MAX",MAX)
        JSR      DDUP
        JSR     LESS
        JSR      QBRAN
        .DW     MAX1
        JSR      SWAP
MAX1:        JSR      DROP
        RETURN

;   MIN        ( n n -- n )
;        Return the smaller of top two stack items.

        COLON(3,"MIN",MIN)
        JSR      DDUP
        JSR     SWAP
        JSR     LESS
        JSR      QBRAN
        .DW     MIN1
        JSR      SWAP
MIN1:        JSR      DROP
        RETURN

;   WITHIN      ( u ul uh -- t )
;        Return true if u is within the range of ul and uh.

        COLON(6,"WITHIN",WITHI)
        JSR      OVER
        JSR     SUBB
        JSR     TOR        ;ul <= u < uh
        JSR      SUBB
        JSR     RFROM
        JSR     ULESS
        RETURN

;; Divide

SEC    .EQU PH

;   UM/MOD      ( udl udh u -- ur uq )
;        Unsigned divide of a double by a single. Return mod and quotient.

        CODE(6,"UM/MOD",UMMOD)
       LDX SP
       LDA ,X
       INCX
       STA QH        ;divisor to Q
       LDA ,X
       INCX
       STA QL
       LDA ,X
       INCX
       STA SEC+1        ;high word to P
       LDA ,X        ;(SEC +1, +0)
       INCX
       STA SEC
       LDA ,X
       INCX
       STA SEC+3        ;low word to TEMPA/B
       LDA ,X        ;(SEC +3, +2)
       STA SEC+2
       STX SP
       BSR DIV16
       LDX SP
       LDA SEC+2        ;push remainder
       STA ,X        ;(HL: SEC+3, +2)
       LDA SEC+3
       DECX
       STA ,X
       LDA SEC        ;push quotient
       DECX        ;(HL: SEC+1, +0)
       STA ,X
       LDA SEC+1
       DECX
       STA ,X
       STX SP
       RTS

DIV16  LDA SEC+2        ;Dividend: (H to L)
       LDX SEC        ;PL,PH,TEMPB,TEMPA
       STX SEC+2        ;(SEC +1,+0,+3,+2)
       LSLA
       STA SEC
       LDA SEC+3        ;Divisor is QH,QL
       LDX SEC+1
       STX SEC+3
       ROLA
       STA SEC+1
       LDA #$10
       STA TEMPC
DBEG   ROL SEC+2
       ROL SEC+3
       LDA SEC+2
       SUB QL
       TAX
       LDA SEC+3
       SBC QH
       BCS DSKIP
       STX SEC+2
       STA SEC+3
       SEC
       BRA DSKIP+1
DSKIP  CLC
       ROL SEC        ;Quotient (H,L) is
       ROL SEC+1      ;   SEC+1,SEC
       DEC TEMPC       ;Remainder (H,L) is
       BNE DBEG       ;   SEC+3,SEC+2
       RTS

;   M/MOD       ( d n -- r q )
;        Signed floored divide of double by single. Return mod and quotient.

        CODE(5,"M/MOD",MSMOD)
       LDX SP
       LDA ,X
       INCX
       STA QH        ;divisor to Q
       LDA ,X
       INCX
       STA QL
       LDA ,X
       INCX
       STA SEC+1        ;high word to P
       LDA ,X        ;(SEC +1, +0)
       INCX
       STA SEC
       LDA ,X
       INCX
       STA SEC+3        ;low word to TEMPA/B
       LDA ,X        ;(SEC +3, +2)
       STA SEC+2
       STX SP
       BSR DIV16
       LDX SP
       LDA SEC+2        ;push remainder
       STA ,X        ;(HL: SEC+3, +2)
       LDA SEC+3
       DECX
       STA ,X
       LDA SEC        ;push quotient
       DECX        ;(HL: SEC+1, +0)
       STA ,X
       LDA SEC+1
       DECX
       STA ,X
       STX SP
       RTS

;   /MOD        ( n n -- r q )
;        Signed divide. Return mod and quotient.

        COLON(4,"/MOD",SLMOD)
        JSR      OVER
        JSR     ZLESS
        JSR     SWAP
        JSR     MSMOD
        RETURN

;   MOD        ( n n -- r )
;        Signed divide. Return mod only.

        COLON(3,"MOD",MODD)
        JSR      SLMOD
        JSR     DROP
        RETURN

;   /        ( n n -- q )
;        Signed divide. Return quotient only.

        COLON(1,"/",SLASH)
        JSR      SLMOD
        JSR     SWAP
        JSR     DROP
        RETURN

;; Multiply

MPY16  LDX #$10        ;16 bit X 16 bit multiply   32 bit result
       CLR TEMPA
       CLR TEMPB
       ROR QH
       ROR QL
MPYNXT BCC ROTAT
       LDA TEMPB
       ADD PL
       STA TEMPB
       LDA TEMPA
       ADC PH
       STA TEMPA
ROTAT  ROR TEMPA
       ROR TEMPB
       ROR QH
       ROR QL
       DECX
       BNE MPYNXT
       RTS

;   UM*        ( u u -- ud )
;        Unsigned multiply. Return double product.

        CODE(3,"UM*",UMSTA)
       LDX SP
       LDA ,X
       INCX
       STA PH
       LDA ,X
       INCX
       STA PL
       LDA ,X
       INCX
       STA QH
       LDA ,X
       STA QL
       STX XTEMP
       JSR MPY16
       LDX XTEMP
       LDA QL        ;push low word
       STA ,X
       LDA QH
       DECX
       STA ,X
       LDA TEMPB        ;push high word
       DECX
       STA ,X
       LDA TEMPA
       DECX
       STA ,X
       STX SP
       RTS

;   *        ( n n -- n )
;        Signed multiply. Return single product.

        COLON(1,"*",STAR)
        JSR      UMSTA
        JSR     DROP
        RETURN

;   M*        ( n n -- d )
;        Signed multiply. Return double product.

        COLON(2,"M*",MSTAR)
        JSR      DDUP
        JSR     XORR
        JSR     ZLESS
        JSR     TOR
        JSR      ABSS
        JSR     SWAP
        JSR     ABSS
        JSR     UMSTA
        JSR      RFROM
        JSR      QBRAN
        .DW     MSTA1
        JSR      DNEGA
MSTA1:        RETURN

;   */MOD       ( n1 n2 n3 -- r q )
;        Multiply n1 and n2, then divide by n3. Return mod and quotient.

        COLON(5,"*/MOD",SSMOD)
        JSR      TOR
        JSR     MSTAR
        JSR     RFROM
        JSR     MSMOD
        RETURN

;   */        ( n1 n2 n3 -- q )
;        Multiply n1 by n2, then divide by n3. Return quotient only.

        COLON(2,"*/",STASL)
        JSR      SSMOD
        JSR     SWAP
        JSR     DROP
        RETURN

;; Miscellaneous

;   CELL+       ( a -- a )
;        Add cell size in byte to address.

        COLON(5,"CELL+",CELLP)
        JSR      DOLIT
        .DW     CELLL
        JSR     PLUS
        RETURN

;   CELL-       ( a -- a )
;        Subtract cell size in byte from address.

        COLON(5,"CELL-",CELLM)
        JSR      DOLIT
        .DW     0-CELLL
        JSR     PLUS
        RETURN

;   CELLS       ( n -- n )
;        Multiply tos by cell size in bytes.

        COLON(5,"CELLS",CELLS)
        JSR      DOLIT
        .DW     CELLL
        JSR     STAR
        RETURN

;   ALIGNED     ( b -- a )
;        Align address to the cell boundary.

        CODE(7,"ALIGNED",ALGND)
        RTS

;   BL        ( -- 32 )
;        Return 32, the blank character.

        COLON(2,"BL",BLANK)
        JSR      DOLIT
        .DW     " "
        RETURN

;   >CHAR       ( c -- c )
;        Filter non-printing characters.

        COLON(5,">CHAR",TCHAR)
        JSR     DUPP    ;mask msb
        JSR      DOLIT
        .DW     127
        JSR     BLANK
        JSR     WITHI   ;check for printable
        JSR      QBRAN
        .DW     TCHA1
        JSR      DROP
        JSR     DOLIT
        .DW     "_"        ;replace non-printables
TCHA1:        RETURN

;   DEPTH       ( -- n )
;        Return the depth of the data stack.

        COLON(5,"DEPTH",DEPTH)
        JSR      SPAT
        JSR     SZERO
        JSR     AT
        JSR     SWAP
        JSR     SUBB
        JSR      DOLIT
        .DW     CELLL
        JSR     SLASH
        RETURN

;   PICK        ( ... +n -- ... w )
;        Copy the nth stack item to tos.

        COLON(4,"PICK",PICK)
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR     CELLS
        JSR      SPAT
        JSR     PLUS
        JSR     AT
        RETURN

;; Memory access

;   +!        ( n a -- )
;        Add n to the contents at address a.

        COLON(2,"+!",PSTOR)
        JSR      SWAP
        JSR     OVER
        JSR     AT
        JSR     PLUS
        JSR      SWAP
        JSR     STORE
        RETURN

;   2!        ( d a -- )
;        Store the double integer to address a.

        COLON(2,"2!",DSTOR)
        JSR      SWAP
        JSR     OVER
        JSR     STORE
        JSR      CELLP
        JSR     STORE
        RETURN

;   2@        ( a -- d )
;        Fetch double integer from address a.

        COLON(2,"2@",DAT)
        JSR      DUPP
        JSR     CELLP
        JSR     AT
        JSR      SWAP
        JSR     AT
        RETURN

;   COUNT       ( b -- b +n )
;        Return count byte of a string and add 1 to byte address.

        COLON(5,"COUNT",COUNT)
        JSR      DUPP
        JSR     DOLIT
        .DW     1
        JSR     PLUS
        JSR      SWAP
        JSR     CAT
        RETURN

;   HERE        ( -- a )
;        Return the top of the code dictionary.

        COLON(4,"HERE",HERE)
        JSR      CP
        JSR     AT
        RETURN

;   PAD        ( -- a )
;        Return the address of a temporary buffer.

        COLON(3,"PAD",PAD)
        JSR      HERE
        JSR     DOLIT
        .DW     80
        JSR     PLUS
        RETURN

;   TIB        ( -- a )
;        Return the address of the terminal input buffer.

        COLON(3,"TIB",TIB)
        JSR      NTIB
        JSR     CELLP
        JSR     AT
        RETURN

;   @EXECUTE    ( a -- )
;        Execute vector stored in address a.

        COLON(8,"@EXECUTE",ATEXE)
        JSR      AT
        JSR     QDUP        ;?address or zero
        JSR      QBRAN
        .DW     AEXE1
        JSR      EXECU        ;execute if non-zero
AEXE1:  RETURN        ;do nothing if zero

;   CMOVE       ( b1 b2 u -- )
;        Copy u bytes from b1 to b2.

        COLON(5,"CMOVE",CMOVE)
        JSR      TOR
        JSR      BRAN
        .DW     CMOV2
CMOV1:  JSR      TOR
        JSR     DUPP
        JSR     CAT
        JSR      RAT
        JSR     CSTOR
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR      RFROM
        JSR     DOLIT
        .DW     1
        JSR     PLUS
CMOV2:  JSR      DONXT
        .DW     CMOV1
        JSR      DDROP
        RETURN

;   FILL        ( b u c -- )
;        Fill u bytes of character c to area beginning at b.

        COLON(4,"FILL",FILL)
        JSR      SWAP
        JSR     TOR
        JSR     SWAP
        JSR      BRAN
        .DW     FILL2
FILL1:  JSR      DDUP
        JSR     CSTOR
        JSR     DOLIT
        .DW     1
        JSR     PLUS
FILL2:  JSR      DONXT
        .DW     FILL1
        JSR      DDROP
        RETURN

;   PACK$       ( b u a -- a )
;        Build a counted string with u characters from b. Null fill.

        COLON(5,"PACK$",PACKS)
        JSR      DUPP
        JSR     TOR        ;strings only on cell boundary
        JSR      DDUP
        JSR     CSTOR
        JSR     DOLIT
        .DW     1
        JSR     PLUS ;save count
        JSR      SWAP
        JSR     CMOVE
        JSR     RFROM
        RETURN   ;move string

;; Numeric output, single precision

;   DIGIT       ( u -- c )
;        Convert digit u to a character.

        COLON(5,"DIGIT",DIGIT)
        JSR      DOLIT
        .DW     9
        JSR     OVER
        JSR     LESS
        JSR      DOLIT
        .DW     7
        JSR     ANDD
        JSR     PLUS
        JSR      DOLIT
        .DW     "0"
        JSR     PLUS
        RETURN

;   EXTRACT     ( n base -- n c )
;        Extract the least significant digit from n.

        COLON(7,"EXTRACT",EXTRC)
        JSR      DOLIT
        .DW     0
        JSR     SWAP
        JSR     UMMOD
        JSR      SWAP
        JSR     DIGIT
        RETURN

;   <#        ( -- )
;        Initiate the numeric output process.

        COLON(2,"<#",BDIGS)
        JSR      PAD
        JSR     HLD
        JSR     STORE
        RETURN

;   HOLD        ( c -- )
;        Insert a character into the numeric output string.

        COLON(4,"HOLD",HOLD)
        JSR      HLD
        JSR     AT
        JSR     DOLIT
        .DW     1
        JSR     SUBB
        JSR      DUPP
        JSR     HLD
        JSR     STORE
        JSR     CSTOR
        RETURN

;   #        ( u -- u )
;        Extract one digit from u and append the digit to output string.

        COLON(1,"#",DIG)
        JSR      BASE
        JSR     AT
        JSR     EXTRC
        JSR     HOLD
        RETURN

;   #S        ( u -- 0 )
;        Convert u until all digits are added to the output string.

        COLON(2,"#S",DIGS)
DIGS1:        JSR      DIG
        JSR     DUPP
        JSR      QBRAN
        .DW     DIGS2
        JSR      BRAN
        .DW     DIGS1
DIGS2:        RETURN

;   SIGN        ( n -- )
;        Add a minus sign to the numeric output string.

        COLON(4,"SIGN",SIGN)
        JSR      ZLESS
        JSR      QBRAN
        .DW     SIGN1
        JSR      DOLIT
        .DW     "-"
        JSR     HOLD
SIGN1:        RETURN

;   #>        ( w -- b u )
;        Prepare the output string to be TYPE"d.

        COLON(2,"#>",EDIGS)
        JSR      DROP
        JSR     HLD
        JSR     AT
        JSR      PAD
        JSR     OVER
        JSR     SUBB
        RETURN

;   str        ( n -- b u )
;        Convert a signed integer to a numeric string.

        COLON(3,"str",STR)
        JSR      DUPP
        JSR     TOR
        JSR     ABSS
        JSR      BDIGS
        JSR     DIGS
        JSR     RFROM
        JSR      SIGN
        JSR     EDIGS
        RETURN

;   HEX        ( -- )
;        Use radix 16 as base for numeric conversions.

        COLON(3,"HEX",HEX)
        JSR      DOLIT
        .DW     16
        JSR     BASE
        JSR     STORE
        RETURN

;   DECIMAL     ( -- )
;        Use radix 10 as base for numeric conversions.

        COLON(7,"DECIMAL",DECIM)
        JSR      DOLIT
        .DW     10
        JSR     BASE
        JSR     STORE
        RETURN

;; Numeric input, single precision

;   DIGIT?      ( c base -- u t )
;        Convert a character to its numeric value. A flag indicates success.

        COLON(6,"DIGIT?",DIGTQ)
        JSR      TOR
        JSR     DOLIT
        .DW     "0"
        JSR     SUBB
        JSR      DOLIT
        .DW     9
        JSR     OVER
        JSR     LESS
        JSR      QBRAN
        .DW     DGTQ1
        JSR      DOLIT
        .DW     7
        JSR     SUBB
        JSR      DUPP
        JSR     DOLIT
        .DW     10
        JSR     LESS
        JSR     ORR
DGTQ1:  JSR      DUPP
        JSR     RFROM
        JSR     ULESS
        RETURN

;   NUMBER?     ( a -- n T | a F )
;            Convert a number string to integer. Push a flag on tos.

        COLON(7,"NUMBER?",NUMBQ)
        JSR      BASE
        JSR     AT
        JSR     TOR
        JSR     DOLIT
        .DW     0
        JSR     OVER
        JSR     COUNT
        JSR      OVER
        JSR     CAT
        JSR     DOLIT
        .DW     "$"
        JSR     EQUAL
        JSR      QBRAN
        .DW     NUMQ1
        JSR      HEX
        JSR     SWAP
        JSR     DOLIT
        .DW     1
        JSR     PLUS
        JSR      SWAP
        JSR     DOLIT
        .DW     1
        JSR     SUBB
NUMQ1:  JSR      OVER
        JSR     CAT
        JSR     DOLIT
        .DW     "-"
        JSR     EQUAL
        JSR     TOR
        JSR      SWAP
        JSR     RAT
        JSR     SUBB
        JSR     SWAP
        JSR     RAT
        JSR     PLUS
        JSR     QDUP
        JSR      QBRAN
        .DW     NUMQ6
        JSR      DOLIT
        .DW     1
        JSR     SUBB
        JSR     TOR
NUMQ2:  JSR      DUPP
        JSR     TOR
        JSR     CAT
        JSR     BASE
        JSR     AT
        JSR     DIGTQ
        JSR      QBRAN
        .DW     NUMQ4
        JSR      SWAP
        JSR     BASE
        JSR     AT
        JSR     STAR
        JSR     PLUS
        JSR     RFROM
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR      DONXT
        .DW     NUMQ2
        JSR      RAT
        JSR     SWAP
        JSR     DROP
        JSR      QBRAN
        .DW     NUMQ3
        JSR      NEGAT
NUMQ3:  JSR      SWAP
        JSR      BRAN
        .DW     NUMQ5
NUMQ4:  JSR      RFROM
        JSR     RFROM
        JSR     DDROP
        JSR     DDROP
        JSR     DOLIT
        .DW     0
NUMQ5:  JSR      DUPP
NUMQ6:  JSR      RFROM
        JSR     DDROP
        JSR      RFROM
        JSR     BASE
        JSR     STORE
        RETURN

;; Basic I/O

;   ?KEY        ( -- c T | F )
;        Return input character and true, or a false if no input.

        COLON(4,"?KEY",QKEY)
        JMP     QRX

;   KEY        ( -- c )
;        Wait for and return an input character.

        CODE(3,"KEY",KEY)
        JSR GETC
;        LDA #$0D
        LDX SP
        DECX
        STA ,X
        DECX
        CLRA
        STA ,X
        STX SP
        RTS

;   EMIT        ( c -- )
;        Send a character to the output device.

        CODE(4,"EMIT",EMIT)
        JMP TXSTO

;   NUF?        ( -- t )
;        Return false if no input, else pause and if CR return true.

        COLON(4,"NUF?",NUFQ)
        JSR     DOLIT
        .DW     0
        RETURN

;   PACE        ( -- )
;        Send a pace character for the file downloading process.

        COLON(4,"PACE",PACE)
        JSR      DOLIT
        .DW     11
        JSR     EMIT
        RETURN

;   SPACE       ( -- )
;        Send the blank character to the output device.

        COLON(5,"SPACE",SPACE)
        JSR      BLANK
        JSR     EMIT
        RETURN

;   SPACES      ( +n -- )
;        Send n spaces to the output device.

        COLON(6,"SPACES",SPACS)
        JSR      DOLIT
        .DW     0
        JSR     MAX
        JSR     TOR
        JSR      BRAN
        .DW     CHAR2
CHAR1:  JSR      SPACE
CHAR2:  JSR      DONXT
        .DW     CHAR1
        RETURN

;   TYPE        ( b u -- )
;        Output u characters from b.

        COLON(4,"TYPE",TYPEE)
        JSR      TOR
        JSR      BRAN
        .DW     TYPE2
TYPE1:  JSR      DUPP
        JSR     CAT
        JSR     EMIT
        JSR      DOLIT
        .DW     1
        JSR     PLUS
TYPE2:  JSR      DONXT
        .DW     TYPE1
        JSR      DROP
        RETURN

;   CR        ( -- )
;        Output a carriage return and a line feed.

        COLON(2,"CR",CR)
        JSR      DOLIT
        .DW     CRR
        JSR     EMIT
        JSR      DOLIT
        .DW     LF
        JSR     EMIT
        RETURN

;   do$        ( -- a )
;        Return the address of a compiled string.

        CODE(COMPO+3,"do$",DOSTR)
	LDX RP		;read address from return stack
        LDA ,X          ;  from one level down
        STA ATEMP
        STA GET+1
        INCX
        LDA ,X
        STA GET+2
        LDX SP          ;push it on the data stack
        DECX
        STA ,X
        LDA ATEMP
        DECX
        STA ,X
        STX SP
        CLRX
        JSR GET         ;get count
        INCA            ;count+1
        LDX RP
        INCX
        ADD ,X          ;addr+count+1
        STA ,X          ;replace old address on return stack
        DECX
        CLRA
        ADC ,X
        STA ,X
        RTS

;   $"|        ( -- a )
;        Run time routine compiled by $". Return address of a compiled string.

        COLON(COMPO+3,"$\42|",STRQP)
        JSR      DOSTR
        RETURN        ;force a call to do$

;   ."|        ( -- )
;        Run time routine of ." . Output a compiled string.

        COLON(COMPO+3,".\042|",DOTQP)
        JSR      DOSTR
        JSR     COUNT
        JSR     TYPEE
        RETURN

;   .R        ( n +n -- )
;        Display an integer in a field of n columns, right justified.

        COLON(2,".R",DOTR)
        JSR      TOR
        JSR     STR
        JSR     RFROM
        JSR     OVER
        JSR     SUBB
        JSR      SPACS
        JSR     TYPEE
        RETURN

;   U.R        ( u +n -- )
;        Display an unsigned integer in n column, right justified.

        COLON(3,"U.R",UDOTR)
        JSR      TOR
        JSR     BDIGS
        JSR     DIGS
        JSR     EDIGS
        JSR      RFROM
        JSR     OVER
        JSR     SUBB
        JSR      SPACS
        JSR     TYPEE
        RETURN

;   U.        ( u -- )
;        Display an unsigned integer in free format.

        COLON(2,"U.",UDOT)
        JSR      BDIGS
        JSR     DIGS
        JSR     EDIGS
        JSR      SPACE
        JSR     TYPEE
        RETURN

;   .        ( w -- )
;        Display an integer in free format, preceeded by a space.

        COLON(1,".",DOT)
        JSR      BASE
        JSR     AT
        JSR     DOLIT
        .DW     10
        JSR     XORR   ;?decimal
        JSR      QBRAN
        .DW     DOT1
        JSR      UDOT
        RETURN        ;no, display unsigned
DOT1:   JSR      STR
        JSR     SPACE
        JSR     TYPEE
        RETURN    ;yes, display signed

;   ?        ( a -- )
;        Display the contents in a memory cell.

        COLON(1,"?",QUEST)
        JSR      AT
        JSR     DOT
        RETURN

;; Parsing

;   parse       ( b u c -- b u delta ; <string> )
;        Scan string delimited by c. Return found string and its offset.

        COLON(5,"parse",PARS)
        JSR      TEMP
        JSR     STORE
        JSR     OVER
        JSR     TOR
        JSR     DUPP
        JSR      QBRAN
        .DW     PARS8
        JSR      DOLIT
        .DW     1
        JSR     SUBB
        JSR     TEMP
        JSR     AT
        JSR     BLANK
        JSR     EQUAL
        JSR      QBRAN
        .DW     PARS3
        JSR      TOR
PARS1:  JSR      BLANK
        JSR     OVER
        JSR     CAT        ;skip leading blanks ONLY
        JSR      SUBB
        JSR     ZLESS
        JSR     INVER
        JSR      QBRAN
        .DW     PARS2
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR      DONXT
        .DW     PARS1
        JSR      RFROM
        JSR     DROP
        JSR     DOLIT
        .DW     0
        JSR     DUPP
        RETURN
PARS2:  JSR      RFROM
PARS3:  JSR      OVER
        JSR     SWAP
        JSR      TOR
PARS4:  JSR      TEMP
        JSR     AT
        JSR     OVER
        JSR     CAT
        JSR     SUBB   ;scan for delimiter
        JSR      TEMP
        JSR     AT
        JSR     BLANK
        JSR     EQUAL
        JSR      QBRAN
        .DW     PARS5
        JSR      ZLESS
PARS5:  JSR      QBRAN
        .DW     PARS6
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR      DONXT
        .DW     PARS4
        JSR      DUPP
        JSR     TOR
        JSR      BRAN
        .DW     PARS7
PARS6:  JSR      RFROM
        JSR     DROP
        JSR     DUPP
        JSR      DOLIT
        .DW     1
        JSR     PLUS
        JSR     TOR
PARS7:  JSR      OVER
        JSR     SUBB
        JSR      RFROM
        JSR     RFROM
        JSR     SUBB
        RETURN
PARS8:  JSR      OVER
        JSR     RFROM
        JSR     SUBB
        RETURN

;   PARSE       ( c -- b u ; <string> )
;        Scan input stream and return counted string delimited by c.

        COLON(5,"PARSE",PARSE)
        JSR      TOR
        JSR     TIB
        JSR     INN
        JSR     AT
        JSR     PLUS     ;current input buffer pointer
        JSR      NTIB
        JSR     AT
        JSR     INN
        JSR     AT
        JSR     SUBB     ;remaining count
        JSR      RFROM
        JSR     PARS
        JSR     INN
        JSR     PSTOR
        RETURN

;   .(        ( -- )
;        Output following string up to next ) .

        COLON(IMEDD+2,".(",DOTPR)
        JSR      DOLIT
        .DW     ")"
        JSR     PARSE
        JSR     TYPEE
        RETURN

;   (        ( -- )
;        Ignore following string up to next ) . A comment.

        COLON(IMEDD+1,"(",PAREN)
        JSR      DOLIT
        .DW     ")"
        JSR     PARSE
        JSR     DDROP
        RETURN

;   \        ( -- )
;        Ignore following text till the end of line.

        COLON(IMEDD+1,"\134",BKSLA)
        JSR      NTIB
        JSR     AT
        JSR     INN
        JSR     STORE
        RETURN

;   CHAR        ( -- c )
;        Parse next word and return its first character.

        COLON(4,"CHAR",CHAR)
        JSR      BLANK
        JSR     PARSE
        JSR     DROP
        JSR     CAT
        RETURN

;   TOKEN       ( -- a ; <string> )
;        Parse a word from input stream and copy it to name dictionary.

        COLON(5,"TOKEN",TOKEN)
        JSR      BLANK
        JSR     PARSE
        JSR     DOLIT
        .DW     31
        JSR     MIN
        JSR      CP
        JSR     AT
        JSR     CELLP  ;combined dictionary
        JSR      PACKS
        RETURN

;   WORD        ( c -- a ; <string> )
;        Parse a word from input stream and copy it to code dictionary.

        COLON(4,"WORD",WORDD)
        JSR      PARSE
        JSR     HERE
        JSR     PACKS
        RETURN

;; Dictionary search

;   NAME>       ( na -- ca )
;        Return a code address given a name address.
;       6805 byte compare*****

        COLON(5,"NAME>",NAMET)
        JSR      COUNT
        JSR     DOLIT
        .DW     31
        JSR     ANDD
        JSR     PLUS
        RETURN

;   SAME?       ( a a u -- a a f \ -0+ )
;        Compare u cells in two strings. Return 0 if identical.
;	6805 byte compare*****

        CODE(5,"SAME?",SAMEQ)
        LDX SP        ;setup compare addresses
        LDA ,X
        INCX
        ORA ,X
        BNE SAME1
        RTS
SAME1   LDA ,X
        STA XTEMP
        INCX
        LDA ,X
        STA SAME2+1
        INCX
        LDA ,X
        STA SAME2+2
        INCX
        LDA ,X
        STA SAME3+1
        INCX
        LDA ,X
        STA SAME3+2
        LDX XTEMP
SAME2   LDA SP0,X
SAME3   CMP SP0,X
        BNE SAME4       ;if bytes not equal, exit
        DECX
        BNE SAME2       ;if count not exhausted, repeat
SAME5   LDX SP        ;matched names
        CLRA        ;return 0 byte
        BRA SAME6
SAME4   LDX SP        ;name not matched
        LDA #0FFH       ;return FF
SAME6   STA ,X
        INCX
        STA ,X
        RTS

;   find        ( a va -- ca na | a F )
;        Search a vocabulary for a string. Return ca and na if succeeded.

        CODE(4,"find",FIND)
        LDX SP
        INCX        ;get address of text string
        INCX
        LDA ,X
        STA FIND4+1     ;put text address in FIND4
        INCX
        LDA ,X
        STA FIND4+2
FIND0   LDX SP        ;if va=0, end of vocabulary, exit
        LDA ,X
        INCX
        ORA ,X
        BNE FIND1
        RTS
FIND1   LDX SP        ;put name address in FIND3
        LDA ,X
        STA FIND3+1
        INCX
        LDA ,X
        STA FIND3+2
FIND3   LDA SP0        ;compare count
        AND #1FH
FIND4   CMP SP0
        BNE FIND7       ;count equal, compare name
FIND6   LDX SP        ;count equal, compare name
        DECX
        STA ,X        ;pass count to SAME?
        INCA
        STA ATEMP       ;save count+1
        DECX
        CLR ,X
        STX SP
        JSR SAMEQ       ;do comparing
        LDX SP
        INCX
        TST ,X
        BEQ FIND5       ;0 is returned, word found
        INCX        ;returned not 0, mismatched
        STX SP
FIND7   LDX SP        ;count not equal, follow the link
        INCX
        LDA ,X
        SUB #2        ;fetch next word address at na-2
        STA GET+2
        DECX
        LDA ,X
        SBC #0
        STA GET+1
        LDX #1        ;replace old word address on stack
        JSR GET
        LDX SP
        INCX
        STA ,X
        CLRX
        JSR GET
        LDX SP
        STA ,X
        JMP FIND0       ;go compare next word
FIND5   INCX        ;match a word
        STX SP        ;replace a with ca=na+count+1
        INCX
        LDA ,X
        ADD ATEMP       ;count+1, saved in SAME?
        INCX
        INCX
        STA ,X
        LDX SP
        LDA ,X
        ADC #0
        INCX
        INCX
        STA ,X
        RTS

;   NAME?       ( a -- ca na | a F )
;        Search context vocabulary for a string.

        COLON(5,"NAME?",NAMEQ)
        JSR     CNTXT
        JSR     DUPP
        JSR     DAT
        JSR     XORR
        JSR     QBRAN
        .DW     NAMQ1
        JSR     CELLM   ;no
NAMQ1:  JSR     TOR
NAMQ2:  JSR     RFROM
        JSR     CELLP
        JSR     DUPP
        JSR     TOR;next in search order
        JSR     AT
        JSR     QDUP
        JSR     QBRAN
        .DW     NAMQ3
        JSR     FIND
        JSR     QDUP;search vocabulary
        JSR     QBRAN
        .DW     NAMQ2
        JSR     RFROM
        JSR     DROP
        RETURN;found name
NAMQ3:  JSR     RFROM
        JSR     DROP;name not found
        JSR     DOLIT
        .DW     0
        RETURN;false flag


;; Terminal response

;   ^H        ( bot eot cur -- bot eot cur )
;        Backup the cursor by one character.

        COLON(2,"^H",BKSP)
        JSR      TOR
        JSR     OVER
        JSR     RFROM
        JSR     SWAP
        JSR     OVER
        JSR     XORR
        JSR      QBRAN
        .DW     BACK1
        JSR      DOLIT
        .DW     BKSPP
        JSR     TECHO
        JSR     ATEXE
        JSR     DOLIT
        .DW     1
        JSR     SUBB
        JSR      BLANK
        JSR     TECHO
        JSR     ATEXE
        JSR      DOLIT
        .DW     BKSPP
        JSR     TECHO
        JSR     ATEXE
BACK1:  RETURN

;   TAP        ( bot eot cur c -- bot eot cur )
;        Accept and echo the key stroke and bump the cursor.

        COLON(3,"TAP",TAP)
        JSR      DUPP
        JSR     TECHO
        JSR     ATEXE
        JSR      OVER
        JSR     CSTOR
        JSR     DOLIT
        .DW     1
        JSR     PLUS
        RETURN

;   kTAP        ( bot eot cur c -- bot eot cur )
;        Process a key stroke, CR or backspace.

        COLON(4,"kTAP",KTAP)
        JSR      DUPP
        JSR     DOLIT
        .DW     CRR
        JSR     XORR
        JSR      QBRAN
        .DW     KTAP2
        JSR      DOLIT
        .DW     BKSPP
        JSR     XORR
        JSR      QBRAN
        .DW     KTAP1
        JSR      BLANK
        JSR     TAP
        RETURN
KTAP1:  JSR      BKSP
        RETURN
KTAP2:  JSR      DROP
        JSR     SWAP
        JSR     DROP
        JSR     DUPP
        RETURN

;   accept      ( b u -- b u )
;        Accept characters to input buffer. Return with actual count.

        COLON(6,"accept",ACCEP)
        JSR      OVER
        JSR     PLUS
        JSR     OVER
ACCP1:  JSR      DDUP
        JSR     XORR
        JSR      QBRAN
        .DW     ACCP4
        JSR      KEY
        JSR     DUPP
        JSR      BLANK
        JSR     DOLIT
        .DW     127
        JSR     WITHI
        JSR      QBRAN
        .DW     ACCP2
        JSR      TAP
        JSR      BRAN
        .DW     ACCP3
ACCP2:  JSR      TTAP
        JSR     ATEXE
ACCP3:  JSR      BRAN
        .DW     ACCP1
ACCP4:  JSR      DROP
        JSR     OVER
        JSR     SUBB
        RETURN

;   EXPECT      ( b u -- )
;        Accept input stream and store count in SPAN.

        COLON(6,"EXPECT",EXPEC)
        JSR      TEXPE
        JSR     ATEXE
        JSR     SPAN
        JSR     STORE
        JSR     DROP
        RETURN

;   QUERY       ( -- )
;        Accept input stream to terminal input buffer.

        COLON(5,"QUERY",QUERY)
        JSR      TIB
        JSR     DOLIT
        .DW     80
        JSR     TEXPE
        JSR     ATEXE
        JSR     NTIB
        JSR     STORE
        JSR      DROP
        JSR     DOLIT
        .DW     0
        JSR     INN
        JSR     STORE
        RETURN

;; Error handling
;       Since I cannot change the hardware stack pointer except to reset
;       it, it is impossible to recover with CATCH-THROW mechanism.
;       To abort, we now jump to WARM, which resets hardware stack with RSP,
;       and then go to COLD2 to re-initialize the Forth interpreter.
;       To minimize the changes, THROW is recoded to print the error
;       message and then jump directly to WARM.
;       QUIT is a simple loop.  Error processing is moved to THROW.
;       22mar99cht

;   THROW       ( err# -- err# )
;        Reset system to current local error frame an update error flag.

        CODE(5,"THROW",THROW)
        JSR      TPROM
        JSR     AT
        JSR     SWAP        ;save input device
        JSR      CONSO
        JSR     NULLS
        JSR     OVER
        JSR     XORR   ;?display error message
        JSR      QBRAN
        .DW     THRW3
        JSR      SPACE
        JSR     COUNT
        JSR     TYPEE       ;error message
        JSR      DOTQP
        .DB     3," ? "        ;error prompt
THRW3:  JSR      DOLIT
        .DW     DOTOK
        JSR     XORR        ;?file input
        JSR      QBRAN
        .DW     THRW4
        JSR      DOLIT
        .DW     ERR
        JSR     EMIT        ;file error, tell host
THRW4:  JSR      PRESE        ;some cleanup
        JSR     WARM 

;   NULL$       ( -- a )
;        Return address of a null string with zero count.

        CODE(5,"NULL$",NULLS)
        JSR      DOVAR        ;emulate CREATE
        .DW      0
        .DB      99,111,121,111,116,101

;   ABORT       ( -- )
;        Reset data stack and jump to QUIT.

        COLON(5,"ABORT",ABORT)
        JSR      NULLS
        JMP     THROW

;   abort"      ( f -- )
;        Run time routine of ABORT" . Abort with a message.

        COLON(COMPO+6,"abort\042",ABORQ)
        JSR      QBRAN
        .DW     ABOR1        ;text flag
        JSR      DOSTR
        JMP     THROW        ;pass error string
ABOR1:  JSR      DOSTR
        JSR     DROP
        RETURN        ;drop error

;; The text interpreter

;   $INTERPRET  ( a -- )
;        Interpret a word. If failed, try to convert it to an integer.

        COLON(10,"$INTERPRET",INTER)
        JSR      NAMEQ
        JSR     QDUP        ;?defined
        JSR      QBRAN
        .DW     INTE1
        JSR      AT
        JSR     DOLIT
        .DW     COMP
	JSR	ANDD     ;?compile only lexicon bits
        JSR      ABORQ
        .DB     13," compile only"
        JSR      EXECU
        RETURN        ;execute defined word
INTE1:  JSR      TNUMB
        JSR     ATEXE        ;convert a number
        JSR      QBRAN
        .DW     INTE2
        RETURN
INTE2:  JMP      THROW        ;error

;   [        ( -- )
;        Start the text interpreter.

        COLON(IMEDD+1,"[",LBRAC)
        JSR      DOLIT
        .DW     INTER
        JSR     TEVAL
        JSR     STORE
        RETURN

;   .OK        ( -- )
;        Display "ok" only while interpreting.

        COLON(3,".OK",DOTOK)
        JSR      DOLIT
        .DW     INTER
        JSR     TEVAL
        JSR     AT
        JSR     EQUAL
        JSR      QBRAN
        .DW     DOTO1
        JSR      DOTQP
        .DB     3," ok"
DOTO1:  JSR      CR
        RETURN

;   ?STACK      ( -- )
;        Abort if the data stack underflows.

        COLON(6,"?STACK",QSTAC)
        JSR      DEPTH
        JSR     ZLESS        ;check only for underflow
        JSR      ABORQ
        .DB     10," underflow"
        RETURN

;   EVAL        ( -- )
;        Interpret the input stream.

        COLON(4,"EVAL",EVAL)
EVAL1:  JSR      TOKEN
        JSR     DUPP
        JSR     CAT        ;?input stream empty
        JSR      QBRAN
        .DW     EVAL2
        JSR      TEVAL
        JSR     ATEXE
        JSR     QSTAC       ;evaluate input check stack
        JSR      BRAN
        .DW     EVAL1
EVAL2:  JSR      DROP
        JSR   TPROM
        JSR   ATEXE
        RETURN

;; Shell

;   PRESET      ( -- )
;        Reset data stack pointer and the terminal input buffer.

        COLON(6,"PRESET",PRESE)
        JSR      SZERO
        JSR     AT
        JSR     SPSTO
        JSR      DOLIT
        .DW     TIBB
        JSR     NTIB
        JSR     CELLP
        JSR     STORE
        RETURN

;   xio        ( a a a -- )
;        Reset the I/O vectors "EXPECT, "TAP, "ECHO and "PROMPT.

        COLON(COMPO+3,"xio",XIO)
        JSR      DOLIT
        .DW     ACCEP
        JSR     TEXPE
        JSR     DSTOR
        JSR      TECHO
        JSR     DSTOR
        RETURN

;   FILE        ( -- )
;        Select I/O vectors for file download.

        COLON(4,"FILE",FILE)
        JSR      DOLIT
        .DW     PACE
        JSR     DOLIT
        .DW     DROP
        JSR      DOLIT
        .DW     KTAP
        JSR     XIO
        RETURN

;   HAND        ( -- )
;        Select I/O vectors for terminal interface.

        COLON(4,"HAND",HAND)
        JSR      DOLIT
        .DW     DOTOK
        JSR     DOLIT
        .DW     EMIT
        JSR      DOLIT
        .DW     KTAP
        JSR     XIO
        RETURN

;   I/O        ( -- a )
;        Array to store default I/O vectors.

        CODE(3,"I/O",ISLO)
        JSR      DOVAR        ;emulate CREATE
        .DW      QRX,TXSTO        ;default I/O vectors

;   CONSOLE     ( -- )
;        Initiate terminal interface.

        COLON(7,"CONSOLE",CONSO)
        JSR      ISLO
        JSR   DAT
        JSR   TQKEY
        JSR   DSTOR   ;restore default I/O device
        JSR      HAND
        RETURN        ;keyboard input

;   QUIT        ( -- )
;        Reset return stack pointer and start text interpreter.

        COLON(4,"QUIT",QUIT)
        JSR      RZERO
        JSR     AT
        JSR     RPSTO        ;reset return stack pointer
QUIT1:  JSR      LBRAC        ;start interpretation
QUIT2:  JSR      QUERY        ;get input
        JSR     EVAL
        JSR      BRAN
        .DW     QUIT2        ;continue till error

;; The compiler

;   '        ( -- ca )
;        Search context vocabularies for the next word in input stream.

        COLON(1,"\047",TICK)
        JSR      TOKEN
        JSR     NAMEQ        ;?defined
        JSR      QBRAN
        .DW     TICK1
        RETURN        ;yes, push code address
TICK1:  JMP      THROW        ;no, error

;   ALLOT       ( n -- )
;        Allocate n bytes to the code dictionary.

        COLON(5,"ALLOT",ALLOT)
        JSR      CP
        JSR     PSTOR
        RETURN        ;adjust code pointer

;   ,        ( w -- )
;        Compile an integer into the code dictionary.

        COLON(1,"\054",COMMA)
        JSR      HERE
        JSR     DUPP
        JSR     CELLP        ;cell boundary
        JSR      CP
        JSR     STORE
        JSR     STORE
        RETURN     ;adjust code pointer, compile

;   C,        ( b -- )
;        Compile a byte into the code dictionary.

        COLON(2,"C\054",CCOMMA)
        JSR      HERE
        JSR     DUPP
        JSR     DOLIT
        .DW     1
        JSR     PLUS        ;cell boundary
        JSR      CP
        JSR     STORE
        JSR     CSTOR
        RETURN     ;adjust code pointer, compile

;   [COMPILE]   ( -- ; <string> )
;        Compile the next immediate word into code dictionary.

        COLON(IMEDD+COMPO+9,"[COMPILE]",BCOMP)
        JSR      TICK
        JSR     CALLC
        RETURN

;   COMPILE     ( -- )
;        Compile the next address in colon list to code dictionary.

        COLON(COMPO+7,"COMPILE",COMPI)
        JSR      RFROM
        JSR     DUPP
        JSR     AT
        JSR     COMMA     ;compile address
        JSR      CELLP
        JSR     TOR
        RETURN        ;adjust return address

;   LITERAL     ( w -- )
;        Compile tos to code dictionary as an integer literal.

        COLON(IMEDD+COMPO+7,"LITERAL",LITER)
        JSR     DOLIT
        .DW     DOLIT
        JSR     CALLC
        JSR     COMMA
        RETURN

;   $,"        ( -- )
;        Compile a literal string up to next " .

        COLON(3,"$\054\042",STRCQ)
        JSR      DOLIT
        .DW     "\047"
        JSR     WORDD        ;move string to code dictionary
        JSR      COUNT
        JSR     PLUS        ;calculate aligned end of string
        JSR      CP
        JSR     STORE
        RETURN        ;adjust the code pointer

;   RECURSE     ( -- )
;        Make the current word available for compilation.

        COLON(IMEDD+COMPO+7,"RECURSE",RECUR)
        JSR      LAST
        JSR     AT
        JSR     NAMET
        JSR     COMMA
        RETURN

;; Structures

;   FOR        ( -- a )
;        Start a FOR-NEXT loop structure in a colon definition.

        COLON(IMEDD+COMPO+3,"FOR",FOR)
        JSR     DOLIT
        .DW     TOR
        JSR     CALLC
        JSR     HERE
        RETURN

;   BEGIN       ( -- a )
;        Start an infinite or indefinite loop structure.

        COLON(IMEDD+COMPO+5,"BEGIN",BEGIN)
        JSR      HERE
        RETURN

;   NEXT        ( a -- )
;        Terminate a FOR-NEXT loop structure.

        COLON(IMEDD+COMPO+4,"NEXT",NEXTT)
        JSR     DOLIT
        .DW     DONXT
        JSR     CALLC
        JSR     COMMA
        RETURN

;   UNTIL       ( a -- )
;        Terminate a BEGIN-UNTIL indefinite loop structure.

        COLON(IMEDD+COMPO+5,"UNTIL",UNTIL)
        JSR     DOLIT
        .DW     QBRAN
        JSR     CALLC
        JSR     COMMA
        RETURN

;   AGAIN       ( a -- )
;        Terminate a BEGIN-AGAIN infinite loop structure.

        COLON(IMEDD+COMPO+5,"AGAIN",AGAIN)
        JSR     DOLIT
        .DW     BRAN
        JSR     CALLC
        JSR     COMMA
        RETURN

;   IF        ( -- A )
;        Begin a conditional branch structure.

        COLON(IMEDD+COMPO+2,"IF",IFF)
        JSR     DOLIT
        .DW     QBRAN
        JSR     CALLC
        JSR     HERE
        JSR     DOLIT
        .DW     0
        JSR     COMMA
        RETURN

;   AHEAD       ( -- A )
;        Compile a forward branch instruction.

        COLON(IMEDD+COMPO+5,"AHEAD",AHEAD)
        JSR     DOLIT
        .DW     BRAN
        JSR     CALLC
        JSR     HERE
        JSR     DOLIT
        .DW     0
        JSR     COMMA
        RETURN

;   REPEAT      ( A a -- )
;        Terminate a BEGIN-WHILE-REPEAT indefinite loop.

        COLON(IMEDD+COMPO+6,"REPEAT",REPEA)
        JSR     AGAIN
        JSR     HERE
        JSR     SWAP
        JSR     STORE
        RETURN

;   THEN        ( A -- )
;        Terminate a conditional branch structure.

        COLON(IMEDD+COMPO+4,"THEN",THENN)
        JSR     HERE
        JSR     SWAP
        JSR     STORE
        RETURN

;   AFT        ( a -- a A )
;        Jump to THEN in a FOR-AFT-THEN-NEXT loop the first time through.

        COLON(IMEDD+COMPO+3,"AFT",AFT)
        JSR     DROP
        JSR     AHEAD
        JSR     BEGIN
        JSR     SWAP
        RETURN

;   ELSE        ( A -- A )
;        Start the false clause in an IF-ELSE-THEN structure.

        COLON(IMEDD+COMPO+4,"ELSE",ELSEE)
        JSR     AHEAD
        JSR     SWAP
        JSR     THENN
        RETURN

;   WHILE       ( a -- A a )
;        Conditional branch out of a BEGIN-WHILE-REPEAT loop.

        COLON(IMEDD+COMPO+5,"WHILE",WHILE)
        JSR     IFF
        JSR     SWAP
        RETURN

;   ABORT"      ( -- ; <string> )
;        Conditional abort with an error message.

        COLON(IMEDD+COMPO+6,"ABORT\042",ABRTQ)
        JSR     DOLIT
        .DW     ABORQ
        JSR     CALLC
        JSR     STRCQ
        RETURN

;   $"        ( -- ; <string> )
;        Compile an inline string literal.

        COLON(IMEDD+COMPO+2,"$\042",STRQ)
        JSR     DOLIT
        .DW     STRQP
        JSR     CALLC
        JSR     STRCQ
        RETURN

;   ."        ( -- ; <string> )
;        Compile an inline string literal to be typed out at run time.

        COLON(IMEDD+COMPO+2,".\-42",DOTQ)
        JSR     DOLIT
        .DW     DOTQP
        JSR     CALLC
        JSR     STRCQ
        RETURN

;; Name compiler

;   ?UNIQUE     ( a -- a )
;        Display a warning message if the word already exists.

        COLON(7,"?UNIQUE",UNIQU)
        JSR      DUPP
        JSR     NAMEQ        ;?name exists
        JSR      QBRAN
        .DW     UNIQ1        ;redefinitions are OK
        JSR      DOTQP
        .DB     7," reDef "        ;but warn the user
        JSR      OVER
        JSR     COUNT
        JSR     TYPEE        ;just in case its not planned
UNIQ1:  JSR      DROP
        RETURN

;   $,n        ( na -- )
;        Build a new dictionary name using the string at na.

        COLON(3,"$\054n",SNAME)
        JSR      DUPP
        JSR     CAT        ;?null input
        JSR      QBRAN
        .DW     PNAM1
        JSR      UNIQU        ;?redefinition
        JSR      DUPP
        JSR     LAST
        JSR     STORE        ;save na for vocabulary link
	JSR	DUPP
        JSR     COUNT
        JSR     PLUS
	JSR	CP
        JSR     STORE
        JSR      CELLM        ;link address
        JSR      CRRNT
        JSR     AT
        JSR     AT
        JSR     SWAP
        JSR     STORE
	RETURN
PNAM1:  JSR      STRQP
        .DB     5," name"        ;null input
        JMP      THROW

;; FORTH compiler

;   $COMPILE    ( a -- )
;        Compile next word to code dictionary as a token or literal.

        COLON(8,"$COMPILE",SCOMP)
        JSR      NAMEQ
        JSR     QDUP        ;?defined
        JSR      QBRAN
        .DW     SCOM2
        JSR      AT
        JSR     DOLIT
        .DW     IMED
        JSR     ANDD     ;?immediate
        JSR      QBRAN
        .DW     SCOM1
        JSR      EXECU
        RETURN        ;its immediate, execute
SCOM1:  JSR      CALLC
        RETURN        ;its not immediate, compile
SCOM2:  JSR      TNUMB
        JSR     ATEXE        ;try to convert to number
        JSR      QBRAN
        .DW     SCOM3
        JSR      LITER
        RETURN        ;compile number as integer
SCOM3:  JMP      THROW        ;error

;   OVERT       ( -- )
;        Link a new word into the current vocabulary.

        COLON(5,"OVERT",OVERT)
        JSR      LAST
        JSR     AT
        JSR     CRRNT
        JSR     AT
        JSR     STORE
        RETURN

;   ;        ( -- )
;        Terminate a colon definition.

        COLON(IMEDD+COMPO+1,"\073",SEMIS)
        JSR      DOLIT
        INC RP
        JSR     DUPP
        JSR     COMMA
        JSR     COMMA
        JSR     DOLIT
        RTS
        RTS
        JSR     CCOMMA
        JSR     LBRAC
        JSR     OVERT
        RETURN

;   ]        ( -- )
;        Start compiling the words in the input stream.

        COLON(1,"]",RBRAC)
        JSR      DOLIT
        .DW     SCOMP
        JSR     TEVAL
        JSR     STORE
        RETURN

;   call,       ( ca -- )
;        Assemble a jump instruction to ca.

        COLON(5,"call\054",CALLC)
        JSR      DOLIT
        .DW     CALLL
        JSR     CCOMMA       ;Direct Threaded Code
        JSR      COMMA
        RETURN      ;DTC 6805 relative call

;   :        ( -- ; <string> )
;        Start a new colon definition using next word as its name.

        COLON(1,"\072",COLO)
        JSR      TOKEN
        JSR     SNAME
        JSR   DOLIT
        DEC RP
        JSR DUPP
        JSR   COMMA
        JSR   COMMA
        JSR     RBRAC
        RETURN

;   IMMEDIATE   ( -- )
;        Make the last compiled word an immediate word.

        COLON(9,"IMMEDIATE",IMMED)
        JSR      DOLIT
        .DW     IMED
        JSR     LAST
        JSR     AT
        JSR     AT
        JSR     ORR
        JSR      LAST
        JSR     AT
        JSR     STORE
        RETURN

;; Defining words

;   USER        ( u -- ; <string> )
;        Compile a new user variable.

        COLON(4,"USER",USER)
        JSR      TOKEN
        JSR     SNAME
        JSR     OVERT
        JSR      DOLIT
        .DW     DOUSE
        JSR     CALLC
        JSR      COMMA
        RETURN

;   CREATE      ( -- ; <string> )
;        Compile a new array entry without allocating code space.

        COLON(6,"CREATE",CREAT)
        JSR      TOKEN
        JSR     SNAME
        JSR     OVERT
        JSR      DOLIT
        .DW     DOVAR
        JSR     CALLC
        RETURN

;   VARIABLE    ( -- ; <string> )
;        Compile a new variable initialized to 0.

        COLON(8,"VARIABLE",VARIA)
        JSR      CREAT
        JSR     DOLIT
        .DW     0
        JSR     COMMA
        RETURN

;; Tools

;   _TYPE       ( b u -- )
;        Display a string. Filter non-printing characters.

        COLON(5,"_TYPE",UTYPE)
        JSR      TOR        ;start count down loop
        JSR      BRAN
        .DW     UTYP2        ;skip first pass
UTYP1:  JSR      DUPP
        JSR     CAT
        JSR     TCHAR
        JSR     EMIT     ;display only printable
        JSR      DOLIT
        .DW     1
        JSR     PLUS        ;increment address
UTYP2:  JSR      DONXT
        .DW     UTYP1        ;loop till done
        JSR      DROP
        RETURN

;   dm+        ( a u -- a )
;        Dump u bytes from , leaving a+u on the stack.

        COLON(3,"dm+",DMP)
        JSR      OVER
        JSR     DOLIT
        .DW     4
        JSR     UDOTR      ;display address
        JSR      SPACE
        JSR     TOR        ;start count down loop
        JSR      BRAN
        .DW     PDUM2        ;skip first pass
PDUM1:  JSR      DUPP
        JSR     CAT
        JSR     DOLIT
        .DW     3
        JSR     UDOTR  ;display numeric data
        JSR      DOLIT
        .DW     1
        JSR     PLUS        ;increment address
PDUM2:  JSR      DONXT
        .DW     PDUM1        ;loop till done
        RETURN

;   DUMP        ( a u -- )
;        Dump u bytes from a, in a formatted manner.

        COLON(4,"DUMP",DUMP)
        JSR      BASE
        JSR     AT
        JSR     TOR
        JSR     HEX        ;save radix
        JSR      DOLIT
        .DW     16
        JSR     SLASH        ;change count to lines
        JSR      TOR        ;start count down loop
DUMP1:  JSR      CR
        JSR     DOLIT
        .DW     16
        JSR     DDUP
        JSR     DMP    ;display numeric
        JSR      ROT
        JSR     ROT
        JSR      SPACE
        JSR     SPACE
        JSR     UTYPE       ;display printable characters
        JSR      NUFQ
        JSR     INVER        ;user control
        JSR      QBRAN
        .DW     DUMP2
        JSR      DONXT
        .DW     DUMP1        ;loop till done
        JSR      BRAN
        .DW     DUMP3
DUMP2:  JSR      RFROM
        JSR     DROP        ;cleanup loop stack
DUMP3:  JSR      DROP
        JSR     RFROM
        JSR     BASE
        JSR     STORE   ;restore radix
        RETURN

;   .S        ( ... -- ... )
;        Display the contents of the data stack.

        COLON(2,".S",DOTS)
        JSR      CR
        JSR     DEPTH        ;stack depth
        JSR      TOR        ;start count down loop
        JSR      BRAN
        .DW     DOTS2        ;skip first pass
DOTS1:  JSR      RAT
        JSR     PICK
        JSR     DOT        ;index stack
DOTS2:  JSR      DONXT
        .DW     DOTS1        ;loop till done
        JSR      DOTQP
        .DB     4," <sp"
        RETURN

;   >NAME       ( ca -- na | F )
;        Convert code address to a name address.

        COLON(5,">NAME",TNAME)
        JSR      CRRNT        ;vocabulary link
TNAM1:  JSR      CELLP
        JSR     AT
        JSR     QDUP        ;check all vocabularies
        JSR      QBRAN
        .DW     TNAM4
        JSR      DDUP
TNAM2:  JSR      AT
        JSR     DUPP        ;?last word in a vocabulary
        JSR      QBRAN
        .DW     TNAM3
        JSR      DDUP
        JSR     NAMET
        JSR     XORR        ;compare
        JSR      QBRAN
        .DW     TNAM3
        JSR      CELLM        ;continue with next word
        JSR      BRAN
        .DW     TNAM2
TNAM3:  JSR      SWAP
        JSR     DROP
        JSR     QDUP
        JSR      QBRAN
        .DW     TNAM1
        JSR      SWAP
        JSR     DROP
        JSR     SWAP
        JSR     DROP
        RETURN
TNAM4:  JSR      DROP
        JSR     DOLIT
        .DW     0
        RETURN       ;false flag

;   .ID        ( na -- )
;        Display the name at address.

        COLON(3,".ID",DOTID)
        JSR      QDUP        ;if zero no name
        JSR      QBRAN
        .DW     DOTI1
        JSR      COUNT
        JSR     DOLIT
        .DW     01FH
        JSR     ANDD   ;mask lexicon bits
        JSR      UTYPE
        RETURN        ;display name string
DOTI1:  JSR      DOTQP
        .DB     9," {noName}"
        RETURN

;   SEE        ( n -- ; <string> )
;        A simple decompiler. n is steps to decompile.
;       Cannot use NUF? to stop decompiling.
;       Skip 4 bytes of DOCOL.  Look for JSR to decompile.

        COLON(3,"SEE",SEE)
        JSR     TICK        ;starting address
        JSR     CR
        JSR     CELLP		
        JSR     CELLP
        JSR     SWAP
        JSR     DOLIT
        .DW     20
        JSR     MAX
        JSR     TOR
SEE1:   JSR     COUNT
        JSR     DUPP
        JSR     DOLIT
        .DW     CALLL
        JSR     XORR
        JSR     QBRAN
        .DW     SEE2
        JSR     DOT        ;display number
        JSR     BRAN
        .DW     SEE4
SEE2:   JSR     DROP        ;name address or zero
        JSR     DUPP
        JSR     AT
        JSR     TNAME        ;?is it a name
        JSR     SPACE
        JSR     DOTID        ;display name
        JSR     CELLP
SEE4    JSR     DONXT
        .DW     SEE1
        JSR     DROP
        RETURN

;   WORDS       ( -- )
;        Display the names in the context vocabulary.

        COLON(5,"WORDS",WORDS)
        JSR      CR
        JSR     CNTXT
        JSR     AT        ;only in context
WORS1:  JSR      AT
        JSR     QDUP        ;?at end of list
        JSR      QBRAN
        .DW     WORS2
        JSR      DUPP
        JSR     SPACE
        JSR     DOTID        ;display a name
        JSR      CELLM
        JSR     NUFQ        ;user control
        JSR      QBRAN
        .DW     WORS1
        JSR      DROP
WORS2:  RETURN

;; Hardware reset

;   VER        ( -- n )
;        Return the version number of this implementation.

        COLON(3,"VER",VERSN)
        JSR      DOLIT
        .DW     VER*256+EXT
        RETURN

;   hi        ( -- )
;        Display the sign-on message of eForth.

        COLON(2,"hi",HI)
        JSR     CR
        JSR     DOTQP
        .DB     8,"eForth v"        ;model
        JSR      BASE
        JSR     AT
        JSR     HEX        ;save radix
        JSR      VERSN
        JSR     BDIGS
        JSR     DIG
        JSR     DIG
        JSR      DOLIT
        .DW     "."
        JSR     HOLD
        JSR      DIGS
        JSR     EDIGS
        JSR     TYPEE        ;format version number
        JSR      BASE
        JSR     STORE
        JSR     CR
        RETURN      ;restore radix

;   'BOOT       ( -- a )
;        The application startup vector.

        CODE(5,"\047BOOT",TBOOT)
        JSR      DOVAR
        .DW      HI        ;application to boot

;   COLD        ( -- )
;        The hilevel cold start sequence.

        CODE(4,"COLD",COLD)
COLD1   JSR      PRESE
        JSR      TBOOT
        JSR     ATEXE        ;application boot
COLD2   JSR      FORTH
        JSR     CNTXT
        JSR     AT
        JSR     DUPP     ;initialize search order
        JSR      CRRNT
        JSR     DSTOR
        JSR     OVERT
        JSR      QUIT        ;start interpretation
        JMP     COLD1

COLDH   .EQU    COLD1/100H*100H
COLDLO  .EQU    COLD1-COLDH
COLDHI  .EQU    COLD1/100H

IRQV    RTI

;===============================================================

LASTN   .EQU     ULINK        ;last name address

NTOP    .EQU     $        ;next available memory in name dictionary
CTOP    .EQU     $         ;next available memory in code dictionary

        .ORG    1FF6H
        .DW     IRQV+0E000H
        .DW     IRQV+0E000H
        .DW     IRQV+0E000H
        .DW     WARM
        .DW     START+0E000H
        .FILL   200H(0)
        .END

;===============================================================

