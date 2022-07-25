        .TITLE  "6805 eForth"
        .PAGE
        .MSFIRST


;===============================================================
;       6805 eForth 1.03, 3/15/99, C. H. Ting
;       Make FIND a code word to speed up theinterpreter.
;
;	6805 eForth 1.02, 3/13/99, C. H. Ting
;	Move data stack to 0F8H, and return stack to 06FH.  TIB at 80H.
;
;	6805 eForth 1.01, 3/12/99, C. H. Ting
;	This implementation is derived from the following two sources:
;     8051 eForth 1.1 by C. H. Ting, 1990
;	RAFOS Forth 1.0 by Everett Carter, 1986
;
;	It is assembled by TASM from Squak Valley Software using the commands:
;		TASM -05 -g2 -s EF.TXT
;	which produces a S19 object file for memory E000-FFFF.
;	
;	The entire Forth system is copied from E100 to 100H and
;	executed in the RAM region 0-2000H. A few words are self-modifying.
;	The data stack is in 2000-20FFH.
;	The return stack and TIB is in 2100-21FFH.
;	Dictionary is extended upward from 2200H.
;
;	6805 is a slow processor.  Do not expect great performance
;	of this implementation, considering that most words are in high
;	level.  Your are encouraged to recode some of the high level words
;	to optimize its performance.
;
;	Direct your questions and contributions to:
;
;               Dr. C. H. Ting
;               156 14th Avenue
;               San Mateo, CA 94402
;               (415) 571-7639
;
;===============================================================

;; Version control

VER             .EQU     01H                     ;major release version
EXT             .EQU     03H                     ;minor extension

;; Constants

COMPO           .EQU     040H                    ;lexicon compile only bit
IMEDD           .EQU     080H                    ;lexicon immediate bit
MASKK           .EQU     01F7FH                  ;lexicon bit mask, big endian*****
COMP           .EQU     04000H                    ;lexicon compile only bit
IMED           .EQU     08000H                    ;lexicon immediate bit

CELLL           .EQU     2                       ;size of a cell
BASEE           .EQU     10                      ;default radix
VOCSS           .EQU     8                       ;depth of vocabulary stack

BKSPP           .EQU     8                       ;backspace
LF              .EQU     10                      ;line feed
CRR             .EQU     13                      ;carriage return
ERR             .EQU     27                      ;error escape
TIC             .EQU     39                      ;tick

JUMP            .EQU     0CCH                   ;JMP opcodes******
LISTT           .EQU     01EFH                   ;DOLST******

;; Memory allocation    0//code>--//--<name//up>--<sp//tib>--rp//em

EM              .EQU     0A000H                  ;top of RAM memory******
COLDD           .EQU     100H                  ;cold start vector******

US              .EQU     100H            ;user area size in cells
RTS             .EQU     100H            ;return stack/TIB size
DTS             .EQU     100H            ;data stack size

UPP             .EQU     0100H           ;start of user area (UP0)
TIBB            .EQU     0080H                 ;terminal input buffer (TIB)
RPP             .EQU     006FH           ;start of return stack (RP0)
SPP             .EQU     00F8H         ;start of data stack (SP0)
NAMEE           .EQU     1FEEH                ;initial name dictionary******
CODEE           .EQU     100H         ;initial code dictionary******

;CR       .EQU    $0D         ; CARRIAGE RETURN
BS       .EQU    $08          ;Back Space
DEL      .EQU    $7F          ;Delete
; 
DDR      .EQU    4            ;DATA DIRECTION REGISTER OFFSET 
; 
PORTA    .EQU    0            ;I/O PORT 0 
PORTB    .EQU    1            ;I/O PORT 1 
PUT      .EQU    PORTB        ;SERIAL I/O PORT
;
INITSP   .EQU    $7F          ;INITIAL STACK POINTER VALUE
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
IP       .EQU $10             ;THE FORTH INSTRUCTION POINTER
RP       .EQU $12             ;THE RETURN POINTER OFFSET
SP       .EQU $13             ;THE STACK POINTER OFFSET
UP       .EQU $14             ;THE USER AREA POINTER, HIGH BYTE
ATEMP    .EQU    $15          ;TEMP USED IN PUTDEC
XTEMP    .EQU    $16          ;INDEX TEMPORARY
GETR     .EQU    $17          ;PICK & DROP TEMPORARY
COUNTT    .EQU    $18          ;NUMBER OF BITS LEFT TO get/send
CHARR     .EQU    $19          ;Current input/output character 
; 
BYTCNT   .EQU    $1A          ;bytcnt.
WTIME    .EQU    $20          ;TIMER INTERRUPT FROM WAIT STATE
;
;
PH       .EQU $21          ;MISC SCRATCH AREAS 
PL       .EQU $22 
TEMPA    .EQU $23 
TEMPB    .EQU $24
QH       .EQU $25
QL       .EQU $26
TEMPC    .EQU $27
;


;; Initialize assembly variables

ULINK   = 0                                     ;force a null link
UNAME   = NAMEE                                 ;initialize name pointer
UCODE   = CODEE                                 ;initialize code pointer
UUSER   = 0                               ;first user variable offset

;; Define assembly macros

;	Compile a code definition header.

#DEFINE CODE(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL

;	Compile a colon definition header.

#DEFINE COLON(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL JMP DOLST
;	Compile a user variable header.

#DEFINE USER(LEX,NAME,LABEL) .DW ULINK \ULINK .SET $\ .DB LEX,NAME\LABEL JMP DOUSE\ .DW UUSER\UUSER .SET UUSER+2


;; Main entry points and COLD start data

        .ORG    COLDD

UZERO:
                .DW      0F8H                     ;SP0
                .DW      06FH                     ;RP0
                .DW      QRX                     ;'?KEY
                .DW      TXSTO                   ;'EMIT
                .DW      ACCEP                   ;'EXPECT
                .DW      KTAP                    ;'TAP
                .DW      TXSTO                   ;'ECHO
                .DW      DOTOK                   ;'PROMPT
                .DW      BASEE                   ;BASE
                .DW      0                       ;tmp
                .DW      0                       ;SPAN
                .DW      0                       ;>IN
                .DW      0                       ;#TIB
                .DW      TIBB                    ;TIB
                .DW      0                       ;CSP
                .DW      INTER                   ;'EVAL
                .DW      NUMBQ                   ;'NUMBER
                .DW      0                       ;HLD
                .DW      0                       ;HANDLER
                .DW      0                       ;CONTEXT pointer
                .DW     0,0,0,0,0,0,0,0
                .DW      0                       ;CURRENT pointer
                .DW      0                       ;vocabulary link pointer
                .DW      CTOP                    ;CP******
                .DW      SPP-DTS                 ;NP
                .DW      LASTN                   ;LAST
                .DW      LASTN                   ;FORTH
                .DW      0                       ;vocabulary link
ULAST:

START BSET 3,$05         ;copy 192 bytes to RAM first
      BSET 3,PUT
      CLRX
SDAT  LDA 0E100H,X
      STA 100H,X
      DECX
      BNE SDAT
      BCLR 3,PUT
        JMP COPYROM              ;jump to RAM to--
        
COPYROM			;copy rest of ROM to RAM
        LDA #1EH
	STA COUNTT
CPY1	CLRX
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
        AND #1
        BNE CPY4
        BCLR 3,PUT
        BRA CPY5
CPY4    BSET 3,PUT
CPY5
        DEC COUNTT
        BNE CPY1
WARM    LDA #0F8H
	STA SP
        LDA #06FH
	STA RP
        LDA #1
        STA UP                          ;INIT TO 100H
	LDA #COLDHI
	STA IP
	LDA #COLDLO
	STA IP+1
TEST    LDA #41H
        JSR PUTC
        LDA #CRR
        JSR PUTC
        LDA #LF
        JSR PUTC        
;        JMP TEST
	JMP NEXT


;
LOAD     STA SP0,X                       ;STA (HERE),X
         RTS                             ;move A to HERE+X
;
GET      LDA SP0,X                       ;LDA (HERE),X
         RTS                             ;get HERE+X into A

;; The kernel

;   doLIT       ( -- w )
;               Push an inline literal.

                CODE(COMPO+5,"doLIT",DOLIT)
      LDA IP               ;move IP to Get
      STA GET+1
      LDA IP+1
      STA GET+2
      LDX #1               ;move low byte to stack
      JSR GET
      LDX SP
      DECX
      STA ,X
      STX SP
      CLRX                 ;and then the high byte
      JSR GET
      LDX SP
      DECX
      STA ,X
      STX SP
      LDA #2               ; now bump IP
      ADD IP+1
      STA IP+1
      CLRA
      ADC IP
      STA IP
      JMP NEXT

;   doLIST      ( a -- )
;               Process colon list.

                CODE(COMPO+6,"doLIST",DOLST)
DOCOL  LDX RP               ;             * Push IP to RS
DOCOL1 .EQU DOCOL
       DECX 
       LDA IP+1 
       STA ,X 
       DECX 
       LDA IP 
       STA ,X 
       STX RP 
       LDA NEXT1+2
       ADD #3
       STA IP+1 
       LDA NEXT1+1
       ADC #0
       STA IP 

NEXT   LDA IP+1              ;     NEXT The Inner Interpreter 
       STA CA+2              ;     SELF-MODIFYING
       LDA IP 
       STA CA+1 
CA     LDA SP0               ;    -- SP0 is a dummy
       STA NEXT1+1
       LDA IP+1 
       ADD #1
       STA CA2+2
       LDA IP 
       ADC #0
       STA CA2+1
CA2    LDA SP0               ;      -- SP0 is a dummy
       STA NEXT1+2
       LDA IP+1 
       ADD #2
       STA IP+1 
       LDA IP 
       ADC #0
       STA IP 
NEXT1  JMP COLD              ;      -- COLD is a dummy

;   next        ( -- )
;               Run time code for the single index loop.
;               : next ( -- ) \ hilevel model
;                 r> r> dup if 1 - >r @ >r exit then drop cell+ >r ;

                CODE(COMPO+4,"next",DONXT)
       LDX RP
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
NXT1   LDA IP+1           ; bump IP past offset
       ADD #2
       STA IP+1
       LDA IP
       ADC #0
       STA IP
	 INCX
	 STX RP
       JMP NEXT

;   ?branch     ( f -- )
;               Branch if flag is zero.

                CODE(COMPO+7,"?branch",QBRAN)
       LDX SP
       LDA ,X
       INCX
       ORA ,X
       INCX
       STX SP
       TSTA
       BNE ZBREX
       JMP BRAN
ZBREX  LDA IP+1           ; bump IP past offset
       ADD #2
       STA IP+1
       LDA IP
       ADC #0
       STA IP
       JMP NEXT

;   branch      ( -- )
;               Branch to an inline address.

                CODE(COMPO+6,"branch",BRAN)
       LDA IP
       STA BRSC1+1
       STA BRSC2+1
       LDA IP+1
       STA BRSC1+2
       STA BRSC2+2
       LDX #1
BRSC1  LDA SP0,X
       STA IP+1
       CLRX
BRSC2  LDA SP0,X
       STA IP
       JMP NEXT

;   EXECUTE     ( ca -- )
;               Execute the word at ca.

                CODE(7,"EXECUTE",EXECU)
       LDX SP                   ;Pop SP into W (NEXT1+1)
       LDA ,X                ;First high byte
       INCX
       STA NEXT1+1
       LDA ,X                ;Then low byte
       INCX
       STA NEXT1+2
       STX SP
       JMP NEXT1

;   EXIT        ( -- )
;               Terminate a colon definition.

                CODE(4,"EXI",EXIT)
       LDX RP                   ;Pop RS into IP
       LDA ,X                ;High byte
       INCX
       STA IP
       LDA ,X                ;then low byte
       INCX
       STA IP+1
       STX RP
       JMP NEXT

;   !           ( w a -- )
;               Pop the data stack to memory.

                CODE(1,"!",STORE)
      LDX SP              ;move addr to Load
      LDA ,X
      INCX
      STA LOAD+1
      LDA ,X
      INCX
      STA LOAD+2
      LDA ,X           ;now move data to addr
      INCX                ;high byte first
      STX SP
      CLRX
      JSR LOAD
      LDX SP
      LDA ,X           ;now the low byte
      INCX
      STX SP
      LDX #1
      JSR LOAD
      JMP NEXT

;   @           ( a -- w )
;               Push memory location to the data stack.

                CODE(1,"@",AT)
       LDX SP
       LDA ,X
       INCX
       STA GET+1
       LDA ,X
       STA GET+2
       STX SP
       LDX #1              ;get low byte
       JSR GET
       LDX SP
       STA ,X
       CLRX                ;get high byte
       JSR GET
       LDX SP
       DECX
       STA ,X
       STX SP
       JMP NEXT

;   C!          ( c b -- )
;               Pop the data stack to byte memory.

                CODE(2,"C!",CSTOR)
      LDX SP              ;move addr to Load
      LDA ,X
      INCX
      STA LOAD+1
      LDA ,X
      INCX
      STA LOAD+2
      INCX                ;drop high data byte
      LDA ,X           ;and move low byte
      INCX
      STX SP
      CLRX
      JSR LOAD
      JMP NEXT

;   C@          ( b -- c )
;               Push byte memory location to the data stack.

                CODE(2,"C@",CAT)
       LDX SP
       LDA ,X
       INCX
       STA GET+1
       LDA ,X
       STA GET+2
       STX SP
       CLRX                ;get the byte
       JSR GET
       LDX SP
       STA ,X
       CLRA                ;zero high byte
       DECX
       STA ,X
       STX SP
       JMP NEXT

;   >R          ( w -- )
;               Push the data stack to the return stack.

                CODE(COMPO+2,">R",TOR)
       LDX SP
       LDA ,X
       INCX
       STA ATEMP
       LDA ,X
       INCX
       STX SP
       LDX RP
       DECX
       STA ,X
       LDA ATEMP
       DECX
       STA ,X
       STX RP
       JMP NEXT

;   R@          ( -- w )
;               Copy top of return stack to the data stack.

                CODE(2,"R@",RAT)
       LDX RP
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
       JMP NEXT

;   R>          ( -- w )
;               Pop the return stack to the data stack.

                CODE(2,"R>",RFROM)
       LDX RP
       LDA ,X
       INCX
       STA ATEMP
       LDA ,X
       INCX
       STX RP
       LDX SP
       DECX
       STA ,X
       LDA ATEMP
       DECX
       STA ,X
       STX SP
       JMP NEXT

;   RP@         ( -- a )
;               Push the current RP to the data stack.

                CODE(3,"RP@",RPAT)
	LDX SP
	DECX
	LDA RP
	STA ,X
	DECX
        STX SP
        CLRA
	STA ,X
	JMP NEXT

;   RP!         ( a -- )
;               Set the return stack pointer.

                CODE(COMPO+3,"RP!",RPSTO)
	LDX SP
        INCX
	LDA ,X
	STA RP
	INCX
	STX SP
	JMP NEXT

;   SP@         ( -- a )
;               Push the current data stack pointer.

                CODE(3,"SP@",SPAT)
	LDX SP
	DECX
	LDA SP
	STA ,X
        DECX
        STX SP
        CLRA
	STA ,X
	JMP NEXT

;   SP!         ( a -- )
;               Set the data stack pointer.

                CODE(3,"SP!",SPSTO)
	LDX SP
        INCX        
	LDA ,X
	STA SP
	JMP NEXT

;   DUP         ( w -- w w )
;               Duplicate the top stack item.

                CODE(3,"DUP",DUPP)
      LDX SP
      LDA ,X           ;get high byte
      DECX                ;and bump SP to point to new location
      DECX
      STA ,X           ;then store it
      LDX SP
      INCX                ;get low byte
      LDA ,X
      DECX                ;bump SP for it too
      DECX
      STA ,X           ;and store it
      DECX                ;update SP
      STX SP
      JMP NEXT

;   DROP        ( w -- )
;               Discard top stack item.

                CODE(4,"DROP",DROP)
       LDX SP
       INCX
       INCX
       STX SP
       JMP NEXT

;   SWAP        ( w1 w2 -- w2 w1 )
;               Exchange top two stack items.

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
      JMP NEXT

;   OVER        ( w1 w2 -- w1 w2 w1 )
;               Copy second stack item to top.

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
       JMP NEXT

;   0<          ( n -- t )
;               Return true if n is negative.

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
       JMP NEXT

;   AND         ( w w -- w )
;               Bitwise AND.

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
       JMP NEXT

;   OR          ( w w -- w )
;               Bitwise inclusive OR.

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
       JMP NEXT

;   XOR         ( w w -- w )
;               Bitwise exclusive OR.

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
       JMP NEXT

;   UM+         ( w w -- w cy )
;               Add two numbers, return the sum and carry flag.

                CODE(3,"UM+",UPLUS)
       LDX SP
       LDA ,X
       STA PH
       INCX
       LDA ,X
       INCX
       INCX            ;point to low on stack
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
       JMP NEXT

;; Device dependent I/O

;
DELAYS   .DB  $20         ; 300 BAUD
         .DB  $08         ;1200 BAUD
         .DB  $01         ;9600 BAUD
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
         LDA #1			;1200 baud, was LDA PUT
         AND #%11
         TAX
         LDX DELAYS,X     ;             load Baud delay
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
;              A AND X ARE ZERO AT EXIT. 
; 
WAIT     LDA    #1          ; ADJUST FOR FIRST TIME
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


;   !IO         ( -- )
;               Initialize the serial I/O devices.

                CODE(3,"!IO",STOIO)
	JMP NEXT

;   ?RX         ( -- c T | F )
;               Return input character and true, or a false if no input.

                CODE(3,"?RX",QRX)
	JSR GETC
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
	JMP NEXT

;   TX!         ( c -- )
;               Send character c to the output device.

               CODE(3,"TX!",TXSTO)
	LDX SP
	INCX
	LDA ,X
	INCX
	STX SP
	JSR PUTC
	JMP NEXT


;; System and user variables

;   doVAR       ( -- a )
;               Run time routine for VARIABLE and CREATE.

                CODE(COMPO+5,"doVAR",DOVAR)
       LDX SP
       LDA NEXT1+2      ;low byte of W
       ADD #3
       DECX
       STA ,X
       LDA NEXT1+1      ;high byte of W
       ADC #0
       DECX
       STA ,X
       STX SP
       JMP NEXT

;  doUSER      ( -- a )
;               Run time routine for user variables.

                CODE(COMPO+6,"doUSER",DOUSE)
       LDA NEXT1+2      ;put W+2 into GET
       ADD #3
       STA GET+2
       LDA NEXT1+1
       ADC #0
       STA GET+1
       LDX #1
       JSR GET         ;get low byte of constant
       LDX SP
       DECX
       STA ,X
       DECX
;      LDA UP
       LDA #1
       STA ,X
       STX SP
       JMP NEXT

;   SP0         ( -- a )
;               Pointer to bottom of the data stack.

                USER(3,"SP0",SZERO)

;   RP0         ( -- a )
;               Pointer to bottom of the return stack.

                USER(3,"RP0",RZERO)

;   '?KEY       ( -- a )
;               Execution vector of ?KEY.

                USER(5,"\047?KEY",TQKEY)

;   'EMIT       ( -- a )
;               Execution vector of EMIT.

                USER(5,"\047EMIT",TEMIT)

;   'EXPECT     ( -- a )
;               Execution vector of EXPECT.

                USER(7,"\047EXPECT",TEXPE)

;   'TAP        ( -- a )
;               Execution vector of TAP.

                USER(4,"\047TAP",TTAP)

;   'ECHO       ( -- a )
;               Execution vector of ECHO.

                USER(5,"\047ECHO",TECHO)

;   'PROMPT     ( -- a )
;               Execution vector of PROMPT.

                USER(7,"\047PROMPT",TPROM)

;   BASE        ( -- a )
;               Storage of the radix base for numeric I/O.

                USER(4,"BASE",BASE)

;   tmp         ( -- a )
;               A temporary storage location used in parse and find.

                USER(COMPO+3,"tmp",TEMP)

;   SPAN        ( -- a )
;               Hold character count received by EXPECT.

                USER(4,"SPAN",SPAN)

;   >IN         ( -- a )
;               Hold the character pointer while parsing input stream.

                USER(3,">IN",INN)

;   #TIB        ( -- a )
;               Hold the current count and address of the terminal input buffer.

                USER(4,"#TIB",NTIB)
UUSER   .SET UUSER+CELLL

;   CSP         ( -- a )
;               Hold the stack pointer for error checking.

                USER(3,"CSP",CSP)

;   'EVAL       ( -- a )
;               Execution vector of EVAL.

                USER(5,"\047EVAL",TEVAL)

;   'NUMBER     ( -- a )
;               Execution vector of NUMBER?.

                USER(7,"\047NUMBER",TNUMB)

;   HLD         ( -- a )
;               Hold a pointer in building a numeric output string.

                USER(3,"HLD",HLD)

;   HANDLER     ( -- a )
;               Hold the return stack pointer for error handling.

                USER(7,"HANDLER",HANDL)

;   CONTEXT     ( -- a )
;               A area to specify vocabulary search order.

                USER(7,"CONTEXT",CNTXT)
UUSER   .SET UUSER+16       ;vocabulary stack

;   CURRENT     ( -- a )
;               Point to the vocabulary to be extended.

                USER(7,"CURRENT",CRRNT)
UUSER   .SET UUSER+CELLL             ;vocabulary link pointer

;   CP          ( -- a )
;               Point to the top of the code dictionary.

                USER(2,"CP",CP)

;   NP          ( -- a )
;               Point to the bottom of the name dictionary.

                USER(2,"NP",NP)

;   LAST        ( -- a )
;               Point to the last name in the name dictionary.

                USER(4,"LAST",LAST)

;   forth       ( -- a )
;               Point to the last name in the name dictionary.

                USER(5,"forth",VFRTH)

;; Common functions

;   FORTH       ( -- )
;               Make FORTH the context vocabulary.

                COLON(5,"FORTH",FORTH)
                .DW      VFRTH,CNTXT,STORE,EXIT

;   ?DUP        ( w -- w w | 0 )
;               Dup tos if its is not zero.

                COLON(4,"?DUP",QDUP)
                .DW      DUPP
                .DW      QBRAN,QDUP1
                .DW      DUPP
QDUP1:          .DW      EXIT

;   ROT         ( w1 w2 w3 -- w2 w3 w1 )
;               Rot 3rd item to top.

                COLON(3,"ROT",ROT)
                .DW      TOR,SWAP,RFROM,SWAP,EXIT

;   2DROP       ( w w -- )
;               Discard two items on stack.

                COLON(5,"2DROP",DDROP)
                .DW      DROP,DROP,EXIT

;   2DUP        ( w1 w2 -- w1 w2 w1 w2 )
;               Duplicate top two items.

                COLON(4,"2DUP",DDUP)
                .DW      OVER,OVER,EXIT

;   +           ( w w -- sum )
;               Add top two items.

                CODE(1,"+",PLUS)
       LDX SP
       LDA ,X
       INCX
       STA PH
       LDA ,X
       INCX
       STX SP
       INCX            ;point to low on stack
       ADD ,X
       STA ,X
       LDX SP
       LDA PH
       ADC ,X
       STA ,X
       JMP NEXT

;   D+          ( d d -- d )
;               Double addition, as an example using UM+.
;
;               COLON(2,"D+",DPLUS)
;               .DW      TOR,SWAP,TOR,UPLUS
;               .DW      RFROM,RFROM,PLUS,PLUS,EXIT

;   NOT         ( w -- w )
;               One"s complement of tos.

                COLON(3,"NOT",INVER)
                .DW      DOLIT,-1,XORR,EXIT

;   NEGATE      ( n -- -n )
;               Two"s complement of tos.

                COLON(6,"NEGATE",NEGAT)
                .DW      INVER,DOLIT,1,PLUS,EXIT

;   DNEGATE     ( d -- -d )
;               Two"s complement of top double.

                COLON(7,"DNEGATE",DNEGA)
                .DW      INVER,TOR,INVER
                .DW      DOLIT,1,UPLUS
                .DW      RFROM,PLUS,EXIT

;   -           ( n1 n2 -- n1-n2 )
;               Subtraction.

                CODE(1,"-",SUBB)
       LDX SP
       LDA ,X
       INCX
       STA PH
       LDA ,X
       INCX
       STA PL
       STX SP
       INCX            ;point to low on stack
       LDA ,X
       SUB PL
       STA ,X
       LDX SP
       LDA ,X
       SBC PH
       STA ,X
       JMP NEXT

;   ABS         ( n -- n )
;               Return the absolute value of n.

                COLON(3,"ABS",ABSS)
                .DW      DUPP,ZLESS
                .DW      QBRAN,ABS1
                .DW      NEGAT
ABS1:           .DW      EXIT

;   =           ( w w -- t )
;               Return true if top two are equal.

                COLON(1,"=",EQUAL)
                .DW      XORR
                .DW      QBRAN,EQU1
                .DW      DOLIT,0,EXIT            ;false flag
EQU1:           .DW      DOLIT,-1,EXIT           ;true flag

;   U<          ( u u -- t )
;               Unsigned compare of top two items.

                COLON(2,"U<",ULESS)
                .DW      DDUP,XORR,ZLESS
                .DW      QBRAN,ULES1
                .DW      SWAP,DROP,ZLESS,EXIT
ULES1:          .DW      SUBB,ZLESS,EXIT

;   <           ( n1 n2 -- t )
;               Signed compare of top two items.

                COLON(1,"<",LESS)
                .DW      DDUP,XORR,ZLESS
                .DW      QBRAN,LESS1
                .DW      DROP,ZLESS,EXIT
LESS1:          .DW      SUBB,ZLESS,EXIT

;   MAX         ( n n -- n )
;               Return the greater of two top stack items.

                COLON(3,"MAX",MAX)
                .DW      DDUP,LESS
                .DW      QBRAN,MAX1
                .DW      SWAP
MAX1:           .DW      DROP,EXIT

;   MIN         ( n n -- n )
;               Return the smaller of top two stack items.

                COLON(3,"MIN",MIN)
                .DW      DDUP,SWAP,LESS
                .DW      QBRAN,MIN1
                .DW      SWAP
MIN1:           .DW      DROP,EXIT

;   WITHIN      ( u ul uh -- t )
;               Return true if u is within the range of ul and uh.

                COLON(6,"WITHIN",WITHI)
                .DW      OVER,SUBB,TOR                   ;ul <= u < uh
                .DW      SUBB,RFROM,ULESS,EXIT

;; Divide

SEC    .EQU PH

;   UM/MOD      ( udl udh u -- ur uq )
;               Unsigned divide of a double by a single. Return mod and quotient.

                CODE(6,"UM/MOD",UMMOD)
       LDX SP
       LDA ,X
       INCX
       STA QH          ;divisor to Q
       LDA ,X
       INCX
       STA QL
       LDA ,X
       INCX
       STA SEC+1          ;high word to P
       LDA ,X          ;(SEC +1, +0)
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
       LDA SEC           ;push quotient
       DECX              ;(HL: SEC+1, +0)
       STA ,X
       LDA SEC+1
       DECX
       STA ,X
       STX SP
       JMP NEXT

DIV16  LDA SEC+2          ;Dividend: (H to L)
       LDX SEC            ;PL,PH,TEMPB,TEMPA
       STX SEC+2          ;(SEC +1,+0,+3,+2)
       LSLA
       STA SEC
       LDA SEC+3          ;Divisor is QH,QL
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
;               Signed floored divide of double by single. Return mod and quotient.

                CODE(5,"M/MOD",MSMOD)
       LDX SP
       LDA ,X
       INCX
       STA QH          ;divisor to Q
       LDA ,X
       INCX
       STA QL
       LDA ,X
       INCX
       STA SEC+1          ;high word to P
       LDA ,X          ;(SEC +1, +0)
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
       LDA SEC           ;push quotient
       DECX              ;(HL: SEC+1, +0)
       STA ,X
       LDA SEC+1
       DECX
       STA ,X
       STX SP
       JMP NEXT

;   /MOD        ( n n -- r q )
;               Signed divide. Return mod and quotient.

                COLON(4,"/MOD",SLMOD)
                .DW      OVER,ZLESS,SWAP,MSMOD,EXIT

;   MOD         ( n n -- r )
;               Signed divide. Return mod only.

                COLON(3,"MOD",MODD)
                .DW      SLMOD,DROP,EXIT

;   /           ( n n -- q )
;               Signed divide. Return quotient only.

                COLON(1,"/",SLASH)
                .DW      SLMOD,SWAP,DROP,EXIT

;; Multiply

MPY16  LDX #$10          ;16 bit X 16 bit multiply   32 bit result
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

;   UM*         ( u u -- ud )
;               Unsigned multiply. Return double product.

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
       LDA QL              ;push low word
       STA ,X
       LDA QH
       DECX
       STA ,X
       LDA TEMPB           ;push high word
       DECX
       STA ,X
       LDA TEMPA
       DECX
       STA ,X
       STX SP
       JMP NEXT

;   *           ( n n -- n )
;               Signed multiply. Return single product.

                COLON(1,"*",STAR)
                .DW      UMSTA,DROP,EXIT

;   M*          ( n n -- d )
;               Signed multiply. Return double product.

                COLON(2,"M*",MSTAR)
                .DW      DDUP,XORR,ZLESS,TOR
                .DW      ABSS,SWAP,ABSS,UMSTA
                .DW      RFROM
                .DW      QBRAN,MSTA1
                .DW      DNEGA
MSTA1:          .DW      EXIT

;   */MOD       ( n1 n2 n3 -- r q )
;               Multiply n1 and n2, then divide by n3. Return mod and quotient.

                COLON(5,"*/MOD",SSMOD)
                .DW      TOR,MSTAR,RFROM,MSMOD,EXIT

;   */          ( n1 n2 n3 -- q )
;               Multiply n1 by n2, then divide by n3. Return quotient only.

                COLON(2,"*/",STASL)
                .DW      SSMOD,SWAP,DROP,EXIT

;; Miscellaneous

;   CELL+       ( a -- a )
;               Add cell size in byte to address.

                COLON(5,"CELL+",CELLP)
                .DW      DOLIT,CELLL,PLUS,EXIT

;   CELL-       ( a -- a )
;               Subtract cell size in byte from address.

                COLON(5,"CELL-",CELLM)
                .DW      DOLIT,0-CELLL,PLUS,EXIT

;   CELLS       ( n -- n )
;               Multiply tos by cell size in bytes.

                COLON(5,"CELLS",CELLS)
                .DW      DOLIT,CELLL,STAR,EXIT

;   ALIGNED     ( b -- a )
;               Align address to the cell boundary.

                COLON(7,"ALIGNED",ALGND)
                .DW      EXIT
;                .DW      DUPP,DOLIT,0,DOLIT,CELLL
;                .DW      UMMOD,DROP,DUPP
;                .DW      QBRAN,ALGN1
;                .DW      DOLIT,CELLL,SWAP,SUBB
;ALGN1:          .DW      PLUS,EXIT

;   BL          ( -- 32 )
;               Return 32, the blank character.

                COLON(2,"BL",BLANK)
                .DW      DOLIT," ",EXIT

;   >CHAR       ( c -- c )
;               Filter non-printing characters.

                COLON(5,">CHAR",TCHAR)
                .DW      DOLIT,07FH,ANDD,DUPP    ;mask msb
                .DW      DOLIT,127,BLANK,WITHI   ;check for printable
                .DW      QBRAN,TCHA1
                .DW      DROP,DOLIT,"_"          ;replace non-printables
TCHA1:          .DW      EXIT

;   DEPTH       ( -- n )
;               Return the depth of the data stack.

                COLON(5,"DEPTH",DEPTH)
                .DW      SPAT,SZERO,AT,SWAP,SUBB
                .DW      DOLIT,CELLL,SLASH,EXIT

;   PICK        ( ... +n -- ... w )
;               Copy the nth stack item to tos.

                COLON(4,"PICK",PICK)
                .DW      DOLIT,1,PLUS,CELLS
;                .DW      DOLIT,1,PLUS
                .DW      SPAT,PLUS,AT,EXIT

;; Memory access

;   +!          ( n a -- )
;               Add n to the contents at address a.

                COLON(2,"+!",PSTOR)
                .DW      SWAP,OVER,AT,PLUS
                .DW      SWAP,STORE,EXIT

;   2!          ( d a -- )
;               Store the double integer to address a.

                COLON(2,"2!",DSTOR)
                .DW      SWAP,OVER,STORE
                .DW      CELLP,STORE,EXIT

;   2@          ( a -- d )
;               Fetch double integer from address a.

                COLON(2,"2@",DAT)
                .DW      DUPP,CELLP,AT
                .DW      SWAP,AT,EXIT

;   COUNT       ( b -- b +n )
;               Return count byte of a string and add 1 to byte address.

                COLON(5,"COUNT",COUNT)
                .DW      DUPP,DOLIT,1,PLUS
                .DW      SWAP,CAT,EXIT

;   HERE        ( -- a )
;               Return the top of the code dictionary.

                COLON(4,"HERE",HERE)
                .DW      CP,AT,EXIT

;   PAD         ( -- a )
;               Return the address of a temporary buffer.

                COLON(3,"PAD",PAD)
                .DW      HERE,DOLIT,80,PLUS,EXIT

;   TIB         ( -- a )
;               Return the address of the terminal input buffer.

                COLON(3,"TIB",TIB)
                .DW      NTIB,CELLP,AT,EXIT

;   @EXECUTE    ( a -- )
;               Execute vector stored in address a.

                COLON(8,"@EXECUTE",ATEXE)
                .DW      AT,QDUP                 ;?address or zero
                .DW      QBRAN,EXE1
                .DW      EXECU                   ;execute if non-zero
EXE1:           .DW      EXIT                    ;do nothing if zero

;   CMOVE       ( b1 b2 u -- )
;               Copy u bytes from b1 to b2.

                COLON(5,"CMOVE",CMOVE)
                .DW      TOR
                .DW      BRAN,CMOV2
CMOV1:          .DW      TOR,DUPP,CAT
                .DW      RAT,CSTOR
                .DW      DOLIT,1,PLUS
                .DW      RFROM,DOLIT,1,PLUS
CMOV2:          .DW      DONXT,CMOV1
                .DW      DDROP,EXIT

;   FILL        ( b u c -- )
;               Fill u bytes of character c to area beginning at b.

                COLON(4,"FILL",FILL)
                .DW      SWAP,TOR,SWAP
                .DW      BRAN,FILL2
FILL1:          .DW      DDUP,CSTOR,DOLIT,1,PLUS
FILL2:          .DW      DONXT,FILL1
                .DW      DDROP,EXIT

;   -TRAILING   ( b u -- b u )
;               Adjust the count to eliminate trailing white space.

                COLON(9,"-TRAILING",DTRAI)
                .DW      TOR
                .DW      BRAN,DTRA2
DTRA1:          .DW      BLANK,OVER,RAT,PLUS,CAT,LESS
                .DW      QBRAN,DTRA2
                .DW      RFROM,DOLIT,1,PLUS,EXIT ;adjusted count
DTRA2:          .DW      DONXT,DTRA1
                .DW      DOLIT,0,EXIT            ;count=0

;   PACK$       ( b u a -- a )
;               Build a counted string with u characters from b. Null fill.

                COLON(5,"PACK$",PACKS)
                .DW      DUPP,TOR          ;strings only on cell boundary
;                .DW      OVER,DUPP,DOLIT,0
;                .DW      DOLIT,CELLL,UMMOD,DROP  ;count mod cell
;                .DW      SUBB,OVER,PLUS
;                .DW      DOLIT,0,SWAP,STORE      ;null fill cell
                .DW      DDUP,CSTOR,DOLIT,1,PLUS ;save count
                .DW      SWAP,CMOVE,RFROM,EXIT   ;move string

;; Numeric output, single precision

;   DIGIT       ( u -- c )
;               Convert digit u to a character.

                COLON(5,"DIGIT",DIGIT)
                .DW      DOLIT,9,OVER,LESS
                .DW      DOLIT,7,ANDD,PLUS
                .DW      DOLIT,"0",PLUS,EXIT

;   EXTRACT     ( n base -- n c )
;               Extract the least significant digit from n.

                COLON(7,"EXTRACT",EXTRC)
                .DW      DOLIT,0,SWAP,UMMOD
                .DW      SWAP,DIGIT,EXIT

;   <#          ( -- )
;               Initiate the numeric output process.

                COLON(2,"<#",BDIGS)
                .DW      PAD,HLD,STORE,EXIT

;   HOLD        ( c -- )
;               Insert a character into the numeric output string.

                COLON(4,"HOLD",HOLD)
                .DW      HLD,AT,DOLIT,1,SUBB
                .DW      DUPP,HLD,STORE,CSTOR,EXIT

;   #           ( u -- u )
;               Extract one digit from u and append the digit to output string.

                COLON(1,"#",DIG)
                .DW      BASE,AT,EXTRC,HOLD,EXIT

;   #S          ( u -- 0 )
;               Convert u until all digits are added to the output string.

                COLON(2,"#S",DIGS)
DIGS1:          .DW      DIG,DUPP
                .DW      QBRAN,DIGS2
                .DW      BRAN,DIGS1
DIGS2:          .DW      EXIT

;   SIGN        ( n -- )
;               Add a minus sign to the numeric output string.

                COLON(4,"SIGN",SIGN)
                .DW      ZLESS
                .DW      QBRAN,SIGN1
                .DW      DOLIT,"-",HOLD
SIGN1:          .DW      EXIT

;   #>          ( w -- b u )
;               Prepare the output string to be TYPE"d.

                COLON(2,"#>",EDIGS)
                .DW      DROP,HLD,AT
                .DW      PAD,OVER,SUBB,EXIT

;   str         ( n -- b u )
;               Convert a signed integer to a numeric string.

                COLON(3,"str",STR)
                .DW      DUPP,TOR,ABSS
                .DW      BDIGS,DIGS,RFROM
                .DW      SIGN,EDIGS,EXIT

;   HEX         ( -- )
;               Use radix 16 as base for numeric conversions.

                COLON(3,"HEX",HEX)
                .DW      DOLIT,16,BASE,STORE,EXIT

;   DECIMAL     ( -- )
;               Use radix 10 as base for numeric conversions.

                COLON(7,"DECIMAL",DECIM)
                .DW      DOLIT,10,BASE,STORE,EXIT

;; Numeric input, single precision

;   DIGIT?      ( c base -- u t )
;               Convert a character to its numeric value. A flag indicates success.

                COLON(6,"DIGIT?",DIGTQ)
                .DW      TOR,DOLIT,"0",SUBB
                .DW      DOLIT,9,OVER,LESS
                .DW      QBRAN,DGTQ1
                .DW      DOLIT,7,SUBB
                .DW      DUPP,DOLIT,10,LESS,ORR
DGTQ1:          .DW      DUPP,RFROM,ULESS,EXIT

;   NUMBER?     ( a -- n T | a F )
;               Convert a number string to integer. Push a flag on tos.

                COLON(7,"NUMBER?",NUMBQ)
                .DW      BASE,AT,TOR,DOLIT,0,OVER,COUNT
                .DW      OVER,CAT,DOLIT,"$",EQUAL
                .DW      QBRAN,NUMQ1
                .DW      HEX,SWAP,DOLIT,1,PLUS
                .DW      SWAP,DOLIT,1,SUBB
NUMQ1:          .DW      OVER,CAT,DOLIT,"-",EQUAL,TOR
                .DW      SWAP,RAT,SUBB,SWAP,RAT,PLUS,QDUP
                .DW      QBRAN,NUMQ6
                .DW      DOLIT,1,SUBB,TOR
NUMQ2:          .DW      DUPP,TOR,CAT,BASE,AT,DIGTQ
                .DW      QBRAN,NUMQ4
                .DW      SWAP,BASE,AT,STAR,PLUS,RFROM
                .DW      DOLIT,1,PLUS
                .DW      DONXT,NUMQ2
                .DW      RAT,SWAP,DROP
                .DW      QBRAN,NUMQ3
                .DW      NEGAT
NUMQ3:          .DW      SWAP
                .DW      BRAN,NUMQ5
NUMQ4:          .DW      RFROM,RFROM,DDROP,DDROP,DOLIT,0
NUMQ5:          .DW      DUPP
NUMQ6:          .DW      RFROM,DDROP
                .DW      RFROM,BASE,STORE,EXIT

;; Basic I/O

;   ?KEY        ( -- c T | F )
;               Return input character and true, or a false if no input.

                COLON(4,"?KEY",QKEY)
                .DW      TQKEY,ATEXE,EXIT

;   KEY         ( -- c )
;               Wait for and return an input character.

;                COLON(3,"KEY",KEY)
;KEY1:           .DW      QKEY
;                .DW      QBRAN,KEY1
;                .DW      EXIT
                CODE(3,"KEY",KEY)
        JSR GETC
;        BRA KEY
	LDX SP
	DECX
	STA ,X
	DECX
	CLRA
	STA ,X
	STX SP
	JMP NEXT

;   EMIT        ( c -- )
;               Send a character to the output device.

;                COLON(4,"EMIT",EMIT)
;               .DW      TEMIT,ATEXE,EXIT
                CODE(4,"EMIT",EMIT)
	LDX SP
	INCX
	LDA ,X
	INCX
	STX SP
        JSR PUTC
;EMIT1   BRA EMIT1
	JMP NEXT

;   NUF?        ( -- t )
;               Return false if no input, else pause and if CR return true.

                COLON(4,"NUF?",NUFQ)
		.DW	DOLIT,0,EXIT
;                .DW      QKEY,DUPP
;                .DW      QBRAN,NUFQ1
;                .DW      DDROP,KEY,DOLIT,CRR,EQUAL
;NUFQ1:          .DW      EXIT

;   PACE        ( -- )
;               Send a pace character for the file downloading process.

                COLON(4,"PACE",PACE)
                .DW      DOLIT,11,EMIT,EXIT

;   SPACE       ( -- )
;               Send the blank character to the output device.

                COLON(5,"SPACE",SPACE)
                .DW      BLANK,EMIT,EXIT

;   SPACES      ( +n -- )
;               Send n spaces to the output device.

                COLON(6,"SPACES",SPACS)
                .DW      DOLIT,0,MAX,TOR
                .DW      BRAN,CHAR2
CHAR1:          .DW      SPACE
CHAR2:          .DW      DONXT,CHAR1
                .DW      EXIT

;   TYPE        ( b u -- )
;               Output u characters from b.

                COLON(4,"TYPE",TYPEE)
                .DW      TOR
                .DW      BRAN,TYPE2
TYPE1:          .DW      DUPP,CAT,EMIT
                .DW      DOLIT,1,PLUS
TYPE2:          .DW      DONXT,TYPE1
                .DW      DROP,EXIT

;   CR          ( -- )
;               Output a carriage return and a line feed.

                COLON(2,"CR",CR)
                .DW      DOLIT,CRR,EMIT
                .DW      DOLIT,LF,EMIT,EXIT

;   do$         ( -- a )
;               Return the address of a compiled string.

                COLON(COMPO+3,"do$",DOSTR)
                .DW      RFROM,RAT,RFROM,COUNT,PLUS
                .DW      TOR,SWAP,TOR,EXIT

;   $"|         ( -- a )
;               Run time routine compiled by $". Return address of a compiled string.

                COLON(COMPO+3,"$\42|",STRQP)
                .DW      DOSTR,EXIT              ;force a call to do$

;   ."|         ( -- )
;               Run time routine of ." . Output a compiled string.

                COLON(COMPO+3,".\042|",DOTQP)
                .DW      DOSTR,COUNT,TYPEE,EXIT

;   .R          ( n +n -- )
;               Display an integer in a field of n columns, right justified.

                COLON(2,".R",DOTR)
                .DW      TOR,STR,RFROM,OVER,SUBB
                .DW      SPACS,TYPEE,EXIT

;   U.R         ( u +n -- )
;               Display an unsigned integer in n column, right justified.

                COLON(3,"U.R",UDOTR)
                .DW      TOR,BDIGS,DIGS,EDIGS
                .DW      RFROM,OVER,SUBB
                .DW      SPACS,TYPEE,EXIT

;   U.          ( u -- )
;               Display an unsigned integer in free format.

                COLON(2,"U.",UDOT)
                .DW      BDIGS,DIGS,EDIGS
                .DW      SPACE,TYPEE,EXIT

;   .           ( w -- )
;               Display an integer in free format, preceeded by a space.

                COLON(1,".",DOT)
                .DW      BASE,AT,DOLIT,10,XORR   ;?decimal
                .DW      QBRAN,DOT1
                .DW      UDOT,EXIT               ;no, display unsigned
DOT1:           .DW      STR,SPACE,TYPEE,EXIT    ;yes, display signed

;   ?           ( a -- )
;               Display the contents in a memory cell.

                COLON(1,"?",QUEST)
                .DW      AT,DOT,EXIT

;; Parsing

;   parse       ( b u c -- b u delta ; <string> )
;               Scan string delimited by c. Return found string and its offset.

                COLON(5,"parse",PARS)
                .DW      TEMP,STORE,OVER,TOR,DUPP
                .DW      QBRAN,PARS8
                .DW      DOLIT,1,SUBB,TEMP,AT,BLANK,EQUAL
                .DW      QBRAN,PARS3
                .DW      TOR
PARS1:          .DW      BLANK,OVER,CAT          ;skip leading blanks ONLY
                .DW      SUBB,ZLESS,INVER
                .DW      QBRAN,PARS2
                .DW      DOLIT,1,PLUS
                .DW      DONXT,PARS1
                .DW      RFROM,DROP,DOLIT,0,DUPP,EXIT
PARS2:          .DW      RFROM
PARS3:          .DW      OVER,SWAP
                .DW      TOR
PARS4:          .DW      TEMP,AT,OVER,CAT,SUBB   ;scan for delimiter
                .DW      TEMP,AT,BLANK,EQUAL
                .DW      QBRAN,PARS5
                .DW      ZLESS
PARS5:          .DW      QBRAN,PARS6
                .DW      DOLIT,1,PLUS
                .DW      DONXT,PARS4
                .DW      DUPP,TOR
                .DW      BRAN,PARS7
PARS6:          .DW      RFROM,DROP,DUPP
                .DW      DOLIT,1,PLUS,TOR
PARS7:          .DW      OVER,SUBB
                .DW      RFROM,RFROM,SUBB,EXIT
PARS8:          .DW      OVER,RFROM,SUBB,EXIT

;   PARSE       ( c -- b u ; <string> )
;               Scan input stream and return counted string delimited by c.

                COLON(5,"PARSE",PARSE)
                .DW      TOR,TIB,INN,AT,PLUS     ;current input buffer pointer
                .DW      NTIB,AT,INN,AT,SUBB     ;remaining count
                .DW      RFROM,PARS,INN,PSTOR,EXIT

;   .(          ( -- )
;               Output following string up to next ) .

                COLON(IMEDD+2,".(",DOTPR)
                .DW      DOLIT,")",PARSE,TYPEE,EXIT

;   (           ( -- )
;               Ignore following string up to next ) . A comment.

                COLON(IMEDD+1,"(",PAREN)
                .DW      DOLIT,")",PARSE,DDROP,EXIT

;   \           ( -- )
;               Ignore following text till the end of line.

                COLON(IMEDD+1,"\134",BKSLA)
                .DW      NTIB,AT,INN,STORE,EXIT

;   CHAR        ( -- c )
;               Parse next word and return its first character.

                COLON(4,"CHAR",CHAR)
                .DW      BLANK,PARSE,DROP,CAT,EXIT

;   TOKEN       ( -- a ; <string> )
;               Parse a word from input stream and copy it to name dictionary.

                COLON(5,"TOKEN",TOKEN)
                .DW      BLANK,PARSE,DOLIT,31,MIN
                .DW      CP,AT,CELLP  ;combined dictionary
                .DW      PACKS,EXIT

;   WORD        ( c -- a ; <string> )
;               Parse a word from input stream and copy it to code dictionary.

                COLON(4,"WORD",WORDD)
                .DW      PARSE,HERE,PACKS,EXIT

;; Dictionary search

;   NAME>       ( na -- ca )
;               Return a code address given a name address.
;			6805 byte compare*****

                COLON(5,"NAME>",NAMET)
                .DW      COUNT,DOLIT,31,ANDD,PLUS,EXIT

;   SAME?       ( a a u -- a a f \ -0+ )
;               Compare u cells in two strings. Return 0 if identical.
;			6805 byte compare*****

                CODE(5,"SAME?",SAMEQ)
                LDX SP          ;setup compare addresses
			LDA ,X
                INCX
			ORA ,X
			BNE SAME1
			RTS
SAME1			LDA ,X
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
SAME2           LDA SP0,X
SAME3           CMP SP0,X
                BNE SAME4       ;if bytes not equal, exit
                DECX
                BNE SAME2       ;if count not exhausted, repeat
SAME5           LDX SP          ;matched names
                CLRA            ;return 0 byte
			BRA SAME6
SAME4           LDX SP          ;name not matched
                LDA #0FFH       ;return FF
SAME6             STA ,X
			INCX
			STA ,X
                RTS

;   find        ( a va -- ca na | a F )
;               Search a vocabulary for a string. Return ca and na if succeeded.

                CODE(4,"find",FIND)
                LDX SP
                INCX            ;get address of text string
                INCX
                LDA ,X
                STA FIND4+1     ;put text address in FIND4
                INCX
                LDA ,X
                STA FIND4+2
FIND0           LDX SP          ;if va=0, end of vocabulary, exit
                LDA ,X
                INCX
                ORA ,X
                BNE FIND1
                JMP NEXT
FIND1           LDX SP          ;put name address in FIND3
                LDA ,X
                STA FIND3+1
                INCX
                LDA ,X
                STA FIND3+2
FIND3           LDA SP0         ;compare count
                AND #1FH
FIND4           CMP SP0
                BNE FIND7       ;count equal, compare name
FIND6           LDX SP          ;count equal, compare name
                DECX
                STA ,X          ;pass count to SAME?
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
                INCX            ;returned not 0, mismatched
                STX SP
FIND7           LDX SP          ;count not equal, follow the link
                INCX
                LDA ,X
                SUB #2          ;fetch next word address at na-2
                STA GET+2
                DECX
                LDA ,X
                SBC #0
                STA GET+1
                LDX #1          ;replace old word address on stack
                JSR GET
                LDX SP
                INCX
                STA ,X
                CLRX
                JSR GET
                LDX SP
                STA ,X
                JMP FIND0       ;go compare next word
FIND5           INCX            ;match a word
                STX SP          ;replace a with ca=na+count+1
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
                JMP NEXT

;   NAME?       ( a -- ca na | a F )
;               Search context vocabulary for a string.

                COLON(5,"NAME?",NAMEQ)
		.DW	CNTXT,DUPP,DAT,XORR	;?context=also
		.DW	QBRAN,NAMQ1
		.DW	CELLM			;no, start with context
NAMQ1:		.DW	TOR
NAMQ2:		.DW	RFROM,CELLP,DUPP,TOR	;next in search order
		.DW	AT,QDUP
		.DW	QBRAN,NAMQ3
		.DW	FIND,QDUP		;search vocabulary
		.DW	QBRAN,NAMQ2
		.DW	RFROM,DROP,EXIT		;found name
NAMQ3:		.DW	RFROM,DROP		;name not found
		.DW	DOLIT,0,EXIT		;false flag


;; Terminal response

;   ^H          ( bot eot cur -- bot eot cur )
;               Backup the cursor by one character.

                COLON(2,"^H",BKSP)
                .DW      TOR,OVER,RFROM,SWAP,OVER,XORR
                .DW      QBRAN,BACK1
                .DW      DOLIT,BKSPP,TECHO,ATEXE,DOLIT,1,SUBB
                .DW      BLANK,TECHO,ATEXE
                .DW      DOLIT,BKSPP,TECHO,ATEXE
BACK1:          .DW      EXIT

;   TAP         ( bot eot cur c -- bot eot cur )
;               Accept and echo the key stroke and bump the cursor.

                COLON(3,"TAP",TAP)
                .DW      DUPP,TECHO,ATEXE
                .DW      OVER,CSTOR,DOLIT,1,PLUS,EXIT

;   kTAP        ( bot eot cur c -- bot eot cur )
;               Process a key stroke, CR or backspace.

                COLON(4,"kTAP",KTAP)
                .DW      DUPP,DOLIT,CRR,XORR
                .DW      QBRAN,KTAP2
                .DW      DOLIT,BKSPP,XORR
                .DW      QBRAN,KTAP1
                .DW      BLANK,TAP,EXIT
KTAP1:          .DW      BKSP,EXIT
KTAP2:          .DW      DROP,SWAP,DROP,DUPP,EXIT

;   accept      ( b u -- b u )
;               Accept characters to input buffer. Return with actual count.

                COLON(6,"accept",ACCEP)
                .DW      OVER,PLUS,OVER
ACCP1:          .DW      DDUP,XORR
                .DW      QBRAN,ACCP4
                .DW      KEY,DUPP
;               .DW      BLANK,SUBB,DOLIT,95,ULESS
                .DW      BLANK,DOLIT,127,WITHI
                .DW      QBRAN,ACCP2
                .DW      TAP
                .DW      BRAN,ACCP3
ACCP2:          .DW      TTAP,ATEXE
ACCP3:          .DW      BRAN,ACCP1
ACCP4:          .DW      DROP,OVER,SUBB,EXIT

;   EXPECT      ( b u -- )
;               Accept input stream and store count in SPAN.

                COLON(6,"EXPECT",EXPEC)
                .DW      TEXPE,ATEXE,SPAN,STORE,DROP,EXIT

;   QUERY       ( -- )
;               Accept input stream to terminal input buffer.

                COLON(5,"QUERY",QUERY)
                .DW      TIB,DOLIT,80,TEXPE,ATEXE,NTIB,STORE
                .DW      DROP,DOLIT,0,INN,STORE,EXIT

;; Error handling

;   CATCH       ( ca -- 0 | err# )
;               Execute word at ca and set up an error frame for it.

                COLON(5,"CATCH",CATCH)
                .DW      SPAT,TOR,HANDL,AT,TOR   ;save error frame
                .DW      RPAT,HANDL,STORE,EXECU  ;execute
                .DW      RFROM,HANDL,STORE       ;restore error frame
                .DW      RFROM,DROP,DOLIT,0,EXIT ;no error

;   THROW       ( err# -- err# )
;               Reset system to current local error frame an update error flag.

                COLON(5,"THROW",THROW)
                .DW      HANDL,AT,RPSTO          ;restore return stack
                .DW      RFROM,HANDL,STORE       ;restore handler frame
                .DW      RFROM,SWAP,TOR,SPSTO    ;restore data stack
                .DW      DROP,RFROM,EXIT

;   NULL$       ( -- a )
;               Return address of a null string with zero count.

                CODE(5,"NULL$",NULLS)
                JMP      DOVAR                   ;emulate CREATE
                .DW      0
                .DB      99,111,121,111,116,101

;   ABORT       ( -- )
;               Reset data stack and jump to QUIT.

                COLON(5,"ABORT",ABORT)
                .DW      NULLS,THROW

;   abort"      ( f -- )
;               Run time routine of ABORT" . Abort with a message.

                COLON(COMPO+6,"abort\042",ABORQ)
                .DW      QBRAN,ABOR1             ;text flag
                .DW      DOSTR,THROW             ;pass error string
ABOR1:          .DW      DOSTR,DROP,EXIT         ;drop error

;; The text interpreter

;   $INTERPRET  ( a -- )
;               Interpret a word. If failed, try to convert it to an integer.

                COLON(10,"$INTERPRET",INTER)
                .DW      NAMEQ,QDUP              ;?defined
                .DW      QBRAN,INTE1
                .DW      AT,DOLIT,COMP,ANDD     ;?compile only lexicon bits
                .DW      ABORQ
                .DB     13," compile only"
                .DW      EXECU,EXIT              ;execute defined word
INTE1:          .DW      TNUMB,ATEXE             ;convert a number
                .DW      QBRAN,INTE2
                .DW      EXIT
INTE2:          .DW      THROW                   ;error

;   [           ( -- )
;               Start the text interpreter.

                COLON(IMEDD+1,"[",LBRAC)
                .DW      DOLIT,INTER,TEVAL,STORE,EXIT

;   .OK         ( -- )
;               Display "ok" only while interpreting.

                COLON(3,".OK",DOTOK)
                .DW      DOLIT,INTER,TEVAL,AT,EQUAL
                .DW      QBRAN,DOTO1
                .DW      DOTQP
                .DB     3," ok"
DOTO1:          .DW      CR,EXIT

;   ?STACK      ( -- )
;               Abort if the data stack underflows.

                COLON(6,"?STACK",QSTAC)
                .DW      DEPTH,ZLESS             ;check only for underflow
                .DW      ABORQ
                .DB     10," underflow"
                .DW      EXIT

;   EVAL        ( -- )
;               Interpret the input stream.

                COLON(4,"EVAL",EVAL)
EVAL1:          .DW      TOKEN,DUPP,CAT          ;?input stream empty
                .DW      QBRAN,EVAL2
                .DW      TEVAL,ATEXE,QSTAC       ;evaluate input, check stack
                .DW      BRAN,EVAL1
EVAL2:          .DW      DROP,TPROM,ATEXE,EXIT   ;prompt

;; Shell

;   PRESET      ( -- )
;               Reset data stack pointer and the terminal input buffer.

                COLON(6,"PRESET",PRESE)
                .DW      SZERO,AT,SPSTO
                .DW      DOLIT,TIBB,NTIB,CELLP,STORE,EXIT

;   xio         ( a a a -- )
;               Reset the I/O vectors "EXPECT, "TAP, "ECHO and "PROMPT.

                COLON(COMPO+3,"xio",XIO)
                .DW      DOLIT,ACCEP,TEXPE,DSTOR
                .DW      TECHO,DSTOR,EXIT

;   FILE        ( -- )
;               Select I/O vectors for file download.

                COLON(4,"FILE",FILE)
                .DW      DOLIT,PACE,DOLIT,DROP
                .DW      DOLIT,KTAP,XIO,EXIT

;   HAND        ( -- )
;               Select I/O vectors for terminal interface.

                COLON(4,"HAND",HAND)
                .DW      DOLIT,DOTOK,DOLIT,EMIT
                .DW      DOLIT,KTAP,XIO,EXIT

;   I/O         ( -- a )
;               Array to store default I/O vectors.

                CODE(3,"I/O",ISLO)
                JMP      DOVAR                   ;emulate CREATE
                .DW      QRX,TXSTO               ;default I/O vectors

;   CONSOLE     ( -- )
;               Initiate terminal interface.

                COLON(7,"CONSOLE",CONSO)
                .DW      ISLO,DAT,TQKEY,DSTOR    ;restore default I/O device
                .DW      HAND,EXIT               ;keyboard input

;   QUIT        ( -- )
;               Reset return stack pointer and start text interpreter.

                COLON(4,"QUIT",QUIT)
                .DW      RZERO,AT,RPSTO          ;reset return stack pointer
QUIT1:          .DW      LBRAC                   ;start interpretation
QUIT2:          .DW      QUERY                   ;get input
                .DW      DOLIT,EVAL,CATCH,QDUP   ;evaluate input
                .DW      QBRAN,QUIT2             ;continue till error
                .DW      TPROM,AT,SWAP           ;save input device
                .DW      CONSO,NULLS,OVER,XORR   ;?display error message
                .DW      QBRAN,QUIT3
                .DW      SPACE,COUNT,TYPEE       ;error message
                .DW      DOTQP
                .DB     3," ? "             ;error prompt
QUIT3:          .DW      DOLIT,DOTOK,XORR        ;?file input
                .DW      QBRAN,QUIT4
                .DW      DOLIT,ERR,EMIT          ;file error, tell host
QUIT4:          .DW      PRESE                   ;some cleanup
                .DW      BRAN,QUIT1

;; The compiler

;   "           ( -- ca )
;               Search context vocabularies for the next word in input stream.

                COLON(1,"\047",TICK)
                .DW      TOKEN,NAMEQ             ;?defined
                .DW      QBRAN,TICK1
                .DW      EXIT                    ;yes, push code address
TICK1:          .DW      THROW                   ;no, error

;   ALLOT       ( n -- )
;               Allocate n bytes to the code dictionary.

                COLON(5,"ALLOT",ALLOT)
                .DW      CP,PSTOR,EXIT           ;adjust code pointer

;   ,           ( w -- )
;               Compile an integer into the code dictionary.

                COLON(1,"\054",COMMA)
                .DW      HERE,DUPP,CELLP         ;cell boundary
                .DW      CP,STORE,STORE,EXIT     ;adjust code pointer, compile

;   C,           ( b -- )
;               Compile a byte into the code dictionary.

                COLON(2,"C\054",CCOMMA)
                .DW      HERE,DUPP,DOLIT,1,PLUS         ;cell boundary
                .DW      CP,STORE,CSTOR,EXIT     ;adjust code pointer, compile

;   [COMPILE]   ( -- ; <string> )
;               Compile the next immediate word into code dictionary.

                COLON(IMEDD+COMPO+9,"[COMPILE]",BCOMP)
                .DW      TICK,COMMA,EXIT

;   COMPILE     ( -- )
;               Compile the next address in colon list to code dictionary.

                COLON(COMPO+COMPO+7,"COMPILE",COMPI)
                .DW      RFROM,DUPP,AT,COMMA     ;compile address
                .DW      CELLP,TOR,EXIT          ;adjust return address

;   LITERAL     ( w -- )
;               Compile tos to code dictionary as an integer literal.

                COLON(IMEDD+COMPO+7,"LITERAL",LITER)
                .DW      COMPI,DOLIT,COMMA,EXIT

;   $,"         ( -- )
;               Compile a literal string up to next " .

                COLON(3,"$\054\042",STRCQ)
                .DW      DOLIT,"\047",WORDD         ;move string to code dictionary
                .DW      COUNT,PLUS        ;calculate aligned end of string
                .DW      CP,STORE,EXIT           ;adjust the code pointer

;   RECURSE     ( -- )
;               Make the current word available for compilation.

                COLON(IMEDD+COMPO+7,"RECURSE",RECUR)
                .DW      LAST,AT,NAMET,COMMA,EXIT

;; Structures

;   FOR         ( -- a )
;               Start a FOR-NEXT loop structure in a colon definition.

                COLON(IMEDD+COMPO+3,"FOR",FOR)
                .DW      COMPI,TOR,HERE,EXIT

;   BEGIN       ( -- a )
;               Start an infinite or indefinite loop structure.

                COLON(IMEDD+COMPO+5,"BEGIN",BEGIN)
                .DW      HERE,EXIT

;   NEXT        ( a -- )
;               Terminate a FOR-NEXT loop structure.

                COLON(IMEDD+COMPO+4,"NEXT",NEXTT)
                .DW      COMPI,DONXT,COMMA,EXIT

;   UNTIL       ( a -- )
;               Terminate a BEGIN-UNTIL indefinite loop structure.

                COLON(IMEDD+COMPO+5,"UNTIL",UNTIL)
                .DW      COMPI,QBRAN,COMMA,EXIT

;   AGAIN       ( a -- )
;               Terminate a BEGIN-AGAIN infinite loop structure.

                COLON(IMEDD+COMPO+5,"AGAIN",AGAIN)
                .DW      COMPI,BRAN,COMMA,EXIT

;   IF          ( -- A )
;               Begin a conditional branch structure.

                COLON(IMEDD+COMPO+2,"IF",IFF)
                .DW      COMPI,QBRAN,HERE
                .DW      DOLIT,0,COMMA,EXIT

;   AHEAD       ( -- A )
;               Compile a forward branch instruction.

                COLON(IMEDD+COMPO+5,"AHEAD",AHEAD)
                .DW      COMPI,BRAN,HERE,DOLIT,0,COMMA,EXIT

;   REPEAT      ( A a -- )
;               Terminate a BEGIN-WHILE-REPEAT indefinite loop.

                COLON(IMEDD+COMPO+6,"REPEAT",REPEA)
                .DW      AGAIN,HERE,SWAP,STORE,EXIT

;   THEN        ( A -- )
;               Terminate a conditional branch structure.

                COLON(IMEDD+COMPO+4,"THEN",THENN)
                .DW      HERE,SWAP,STORE,EXIT

;   AFT         ( a -- a A )
;               Jump to THEN in a FOR-AFT-THEN-NEXT loop the first time through.

                COLON(IMEDD+COMPO+3,"AFT",AFT)
                .DW      DROP,AHEAD,BEGIN,SWAP,EXIT

;   ELSE        ( A -- A )
;               Start the false clause in an IF-ELSE-THEN structure.

                COLON(IMEDD+COMPO+4,"ELSE",ELSEE)
                .DW      AHEAD,SWAP,THENN,EXIT

;   WHILE       ( a -- A a )
;               Conditional branch out of a BEGIN-WHILE-REPEAT loop.

                COLON(IMEDD+COMPO+5,"WHILE",WHILE)
                .DW      IFF,SWAP,EXIT

;   ABORT"      ( -- ; <string> )
;               Conditional abort with an error message.

                COLON(IMEDD+COMPO+6,"ABORT\042",ABRTQ)
                .DW      COMPI,ABORQ,STRCQ,EXIT

;   $"          ( -- ; <string> )
;               Compile an inline string literal.

                COLON(IMEDD+COMPO+2,"$\042",STRQ)
                .DW      COMPI,STRQP,STRCQ,EXIT

;   ."          ( -- ; <string> )
;               Compile an inline string literal to be typed out at run time.

                COLON(IMEDD+COMPO+2,".\-42",DOTQ)
                .DW      COMPI,DOTQP,STRCQ,EXIT

;; Name compiler

;   ?UNIQUE     ( a -- a )
;               Display a warning message if the word already exists.

                COLON(7,"?UNIQUE",UNIQU)
                .DW      DUPP,NAMEQ              ;?name exists
                .DW      QBRAN,UNIQ1             ;redefinitions are OK
                .DW      DOTQP
                .DB     7," reDef "         ;but warn the user
                .DW      OVER,COUNT,TYPEE        ;just in case its not planned
UNIQ1:          .DW      DROP,EXIT

;   $,n         ( na -- )
;               Build a new dictionary name using the string at na.

                COLON(3,"$\054n",SNAME)
                .DW      DUPP,CAT                ;?null input
                .DW      QBRAN,PNAM1
                .DW      UNIQU                   ;?redefinition
                .DW      DUPP,LAST,STORE         ;save na for vocabulary link
			.DW	DUPP,COUNT,PLUS
			.DW	CP,STORE
                .DW      CELLM                   ;link address
                .DW      CRRNT,AT,AT,SWAP,STORE
			.DW	EXIT
PNAM1:          .DW      STRQP
                .DB     5," name"           ;null input
                .DW      THROW

;; FORTH compiler

;   $COMPILE    ( a -- )
;               Compile next word to code dictionary as a token or literal.

                COLON(8,"$COMPILE",SCOMP)
                .DW      NAMEQ,QDUP              ;?defined
                .DW      QBRAN,SCOM2
                .DW      AT,DOLIT,IMED,ANDD     ;?immediate
                .DW      QBRAN,SCOM1
                .DW      EXECU,EXIT              ;its immediate, execute
SCOM1:          .DW      COMMA,EXIT              ;its not immediate, compile
SCOM2:          .DW      TNUMB,ATEXE             ;try to convert to number
                .DW      QBRAN,SCOM3
                .DW      LITER,EXIT              ;compile number as integer
SCOM3:          .DW      THROW                   ;error

;   OVERT       ( -- )
;               Link a new word into the current vocabulary.

                COLON(5,"OVERT",OVERT)
                .DW      LAST,AT,CRRNT,AT,STORE,EXIT

;   ;           ( -- )
;               Terminate a colon definition.

                COLON(IMEDD+COMPO+1,"\073",SEMIS)
                .DW      COMPI,EXIT,LBRAC,OVERT,EXIT

;   ]           ( -- )
;               Start compiling the words in the input stream.

                COLON(1,"]",RBRAC)
                .DW      DOLIT,SCOMP,TEVAL,STORE,EXIT

;   jump,       ( ca -- )
;               Assemble a jump instruction to ca.

                COLON(5,"jump\054",JUMPC)
                .DW      DOLIT,JUMP,CCOMMA       ;Direct Threaded Code
                .DW      COMMA,EXIT      		;DTC 6805 relative call

;   :           ( -- ; <string> )
;               Start a new colon definition using next word as its name.

                COLON(1,"\072",COLO)
                .DW      TOKEN,SNAME,DOLIT,DOLST
                .DW      JUMPC,RBRAC,EXIT

;   IMMEDIATE   ( -- )
;               Make the last compiled word an immediate word.

                COLON(9,"IMMEDIATE",IMMED)
                .DW      DOLIT,IMED,LAST,AT,AT,ORR
                .DW      LAST,AT,STORE,EXIT

;; Defining words

;   USER        ( u -- ; <string> )
;               Compile a new user variable.

                COLON(4,"USER",USER)
                .DW      TOKEN,SNAME,OVERT
                .DW      DOLIT,DOUSE,JUMPC
                .DW      COMMA,EXIT

;   CREATE      ( -- ; <string> )
;               Compile a new array entry without allocating code space.

                COLON(6,"CREATE",CREAT)
                .DW      TOKEN,SNAME,OVERT
                .DW      DOLIT,DOVAR,JUMPC
                .DW      EXIT

;   VARIABLE    ( -- ; <string> )
;               Compile a new variable initialized to 0.

                COLON(8,"VARIABLE",VARIA)
                .DW      CREAT,DOLIT,0,COMMA,EXIT

;; Tools

;   _TYPE       ( b u -- )
;               Display a string. Filter non-printing characters.

                COLON(5,"_TYPE",UTYPE)
                .DW      TOR                     ;start count down loop
                .DW      BRAN,UTYP2              ;skip first pass
UTYP1:          .DW      DUPP,CAT,TCHAR,EMIT     ;display only printable
                .DW      DOLIT,1,PLUS            ;increment address
UTYP2:          .DW      DONXT,UTYP1             ;loop till done
                .DW      DROP,EXIT

;   dm+         ( a u -- a )
;               Dump u bytes from , leaving a+u on the stack.

                COLON(3,"dm+",DMP)
                .DW      OVER,DOLIT,4,UDOTR      ;display address
                .DW      SPACE,TOR               ;start count down loop
                .DW      BRAN,PDUM2              ;skip first pass
PDUM1:          .DW      DUPP,CAT,DOLIT,3,UDOTR  ;display numeric data
                .DW      DOLIT,1,PLUS            ;increment address
PDUM2:          .DW      DONXT,PDUM1             ;loop till done
                .DW      EXIT

;   DUMP        ( a u -- )
;               Dump u bytes from a, in a formatted manner.

                COLON(4,"DUMP",DUMP)
                .DW      BASE,AT,TOR,HEX         ;save radix, set hex
                .DW      DOLIT,16,SLASH          ;change count to lines
                .DW      TOR                     ;start count down loop
DUMP1:          .DW      CR,DOLIT,16,DDUP,DMP    ;display numeric
                .DW      ROT,ROT
                .DW      SPACE,SPACE,UTYPE       ;display printable characters
                .DW      NUFQ,INVER              ;user control
                .DW      QBRAN,DUMP2
                .DW      DONXT,DUMP1             ;loop till done
                .DW      BRAN,DUMP3
DUMP2:          .DW      RFROM,DROP              ;cleanup loop stack, early exit
DUMP3:          .DW      DROP,RFROM,BASE,STORE   ;restore radix
                .DW      EXIT

;   .S          ( ... -- ... )
;               Display the contents of the data stack.

                COLON(2,".S",DOTS)
                .DW      CR,DEPTH                ;stack depth
                .DW      TOR                     ;start count down loop
                .DW      BRAN,DOTS2              ;skip first pass
DOTS1:          .DW      RAT,PICK,DOT            ;index stack, display contents
DOTS2:          .DW      DONXT,DOTS1             ;loop till done
                .DW      DOTQP
                .DB     4," <sp"
                .DW      EXIT

;   !CSP        ( -- )
;               Save stack pointer in CSP for error checking.

                COLON(4,"!CSP",STCSP)
                .DW      SPAT,CSP,STORE,EXIT     ;save pointer

;   ?CSP        ( -- )
;               Abort if stack pointer differs from that saved in CSP.

                COLON(4,"?CSP",QCSP)
                .DW      SPAT,CSP,AT,XORR        ;compare pointers
                .DW      ABORQ
                .DB     6,"stacks"          ;abort if different
                .DW      EXIT

;   >NAME       ( ca -- na | F )
;               Convert code address to a name address.

                COLON(5,">NAME",TNAME)
                .DW      CRRNT                   ;vocabulary link
TNAM1:          .DW      CELLP,AT,QDUP           ;check all vocabularies
                .DW      QBRAN,TNAM4
                .DW      DDUP
TNAM2:          .DW      AT,DUPP                 ;?last word in a vocabulary
                .DW      QBRAN,TNAM3
                .DW      DDUP,NAMET,XORR         ;compare
                .DW      QBRAN,TNAM3
                .DW      CELLM                   ;continue with next word
                .DW      BRAN,TNAM2
TNAM3:          .DW      SWAP,DROP,QDUP
                .DW      QBRAN,TNAM1
                .DW      SWAP,DROP,SWAP,DROP,EXIT
TNAM4:          .DW      DROP,DOLIT,0,EXIT       ;false flag

;   .ID         ( na -- )
;               Display the name at address.

                COLON(3,".ID",DOTID)
                .DW      QDUP                    ;if zero no name
                .DW      QBRAN,DOTI1
                .DW      COUNT,DOLIT,01FH,ANDD   ;mask lexicon bits
                .DW      UTYPE,EXIT              ;display name string
DOTI1:          .DW      DOTQP
                .DB     9," {noName}"
                .DW      EXIT

;   SEE         ( n -- ; <string> )
;               A simple decompiler. n is steps to decompile.

                COLON(3,"SEE",SEE)
                .DW      TICK                    ;starting address
                .DW      CR,DOLIT,1,PLUS
		.DW	SWAP,DOLIT,20,MAX,TOR
SEE1:           .DW      CELLP,DUPP,AT,DUPP      ;?does it contain a zero
                .DW      QBRAN,SEE2
                .DW      TNAME                   ;?is it a name
SEE2:           .DW      QDUP                    ;name address or zero
                .DW      QBRAN,SEE3
                .DW      SPACE,DOTID             ;display name
                .DW      BRAN,SEE4
SEE3:           .DW      DUPP,CAT,DOT            ;display number
		.DW	DOLIT,-1,PLUS
SEE4:           .DW      DONXT,SEE1
                .DW      DROP,EXIT

;   WORDS       ( -- )
;               Display the names in the context vocabulary.

                COLON(5,"WORDS",WORDS)
                .DW      CR,CNTXT,AT             ;only in context
WORS1:          .DW      AT,QDUP                 ;?at end of list
                .DW      QBRAN,WORS2
                .DW      DUPP,SPACE,DOTID        ;display a name
                .DW      CELLM,NUFQ              ;user control
                .DW      QBRAN,WORS1
                .DW      DROP
WORS2:          .DW      EXIT

;; Har.DWare reset

;   VER         ( -- n )
;               Return the version number of this implementation.

                COLON(3,"VER",VERSN)
                .DW      DOLIT,VER*256+EXT,EXIT

;   hi          ( -- )
;               Display the sign-on message of eForth.

                COLON(2,"hi",HI)
                .DW      STOIO,CR                ;initialize I/O
                .DW      DOTQP
                .DB     8,"eForth v"        ;model
                .DW      BASE,AT,HEX             ;save radix
                .DW      VERSN,BDIGS,DIG,DIG
                .DW      DOLIT,".",HOLD
                .DW      DIGS,EDIGS,TYPEE        ;format version number
                .DW      BASE,STORE,CR,EXIT      ;restore radix

;   'BOOT       ( -- a )
;               The application startup vector.

                CODE(5,"\047BOOT",TBOOT)
                JMP      DOVAR
                .DW      HI                      ;application to boot

;   COLD        ( -- )
;               The hilevel cold start sequence.

                COLON(4,"COLD",COLD)
COLD1:          .DW      PRESE                   ;initialize stack and TIB
                .DW      TBOOT,ATEXE             ;application boot
                .DW      FORTH,CNTXT,AT,DUPP     ;initialize search order
                .DW      CRRNT,DSTOR,OVERT
                .DW      QUIT                    ;start interpretation
                .DW      BRAN,COLD1              ;just in case


COLDH   .EQU    COLD1/100H*100H
COLDLO  .EQU    COLD1-COLDH
COLDHI  .EQU    COLD1/100H

IRQV	RTI


;===============================================================

LASTN           .EQU     ULINK                 ;last name address

NTOP            .EQU     $                 ;next available memory in name dictionary
CTOP            .EQU     $                     ;next available memory in code dictionary

        .ORG    1FF6H
        .DW     IRQV+0E000H
        .DW     IRQV+0E000H
        .DW     IRQV+0E000H
	.DW	WARM
        .DW     START+0E000H
        .FILL   200H(0)
        .END

;===============================================================

