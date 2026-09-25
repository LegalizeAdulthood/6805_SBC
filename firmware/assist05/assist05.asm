        NAM     ASSIST05
*************************************************
* MONITOR FOR THE AUSTIN 6805 EVALUATION MODULE *
* (C) COPYRIGHT 1979 MOTOROLA INC.              *
*************************************************
*************************************************
*
* THE MONITOR HAS THE FOLLOWING COMMANDS:
*
* R -- PRINT REGISTERS
*
* A -- DISPLAY/CHANGE A REGISTER
*
* X -- DISPLAY/CHANGE X REGISTER
*
* C -- DISPLAY/CHANGE CONDITION CODE
*
* P -- DISPLAY/CHANGE PROGRAM COUNTER
*
* L -- LOAD TAPE FILE INTO MEMORY
*
* W XXXX YYYY -- WRITE MEMORY TO TAPE FILE
*
* B -- DISPLAY BREAKPOINTS
* B N XXXX -- SET BREAKPOINT NUMBER N
* B N O -- CLEAR BREAKPOINT NUMBER N
*
* T -- TRACE ONE INSTRUCTION
* T XXXX -- TRACE XXX INSTRUCTIONS
*
* M XXXX -- MEMORY EXAMINE/CHANGE.
* TYPE: ^ -- TO EXAMINE PREVIOUS
* LF -- TO EXAMINE NEXT
* HH -- CHANGE TO HEX DATA
* CR -- TERMINATE COMMAND
*
* G -- CONTINUE PROGRAM EXECUTION FROM
* CURRENT PROGRAM COUNTER.
* G XXXX -- GO EXECUTE PROGRAM AT SPECIFIED
* ADDRESS.
*
*************************************************
* MC146805E2 GLOBAL PARAMETERS                  *
*************************************************
MONSTR  EQU     $1800                   START OF MONITOR
PCMASK  EQU     $1F                     MASK OFF FOR 8K ADDRESS SPACE (E2)
NUMBKP  EQU     3                       NUMBER OF BREAKPOINTS
ACIA    EQU     $17F8                   ACIA ADDRESS
PROMPT  EQU     '>                      PROMPT CHARACTER
TIMER   EQU     8                       TIMER DATA REGISTER
TIMEC   EQU     9                       TIMER CONTROL REGISTER
*************************************************
* EQUATES                                       *
*************************************************
EOT     EQU     $04                     END OF TEXT
CR      EQU     $0D                     CARRIAGE RETURN
LF      EQU     $0A                     LINE FEED
DC1     EQU     $11                     READER ON CONTROL FUNCTION
DC2     EQU     $12                     PUNCH ON CONTROL FUNCTION
DC3     EQU     $13                     X-OFF CONTROL FUNCTION
DC4     EQU     $14                     STOP CONTROL FUNCTION
SP      EQU     $20                     SPACE
BELL    EQU     $07                     CONTROL-G (BELL)
SWIOP   EQU     $83                     SOFTWARE INTERRUPT OPCODE
JMPOP   EQU     $CC                     EXTENDED JUMP OPCODE
*************************************************
* MONITOR WORK AREA AT STACK BOTTOM
*************************************************
        ORG     $41                     BOTTOM OF STACK
BKPTBL  EQU     *-3*NUMBKP              BKPT TABLE UNDER STACK BOTTOM
SWIFLG  RMB     1                       SWI FUNCTION FLAG
WORK1   RMB     1                       CHRIN/LOAD/STORE/PUTBYT
WORK2   RMB     1                       LOAD/STORE/PUTBYT
ADDRH   RMB     1                       HIGH ADDRESS BYTE
ADDRL   RMB     1                       LOW ADDRESS BYTE
WORK3   RMB     1                       LOAD /STORE/ PUNCH
WORK4   RMB     1                       STORE/PUNCH
WORK5   RMB     1                       TRACE
WORK6   RMB     1                       TRACE
WORK7   RMB     1                       TRACE
PNCNT   RMB     1                       PUNCH BREAKPOINT
PNRCNT  RMB     2                       PUNCH
CHKSUM  RMB     1                       PUNCH
VECRAM  RMB     12                      VECTORS
        ORG     MONSTR                  START OF MONITOR
*************************************************
* MONITOR BASE STRING/TABLE PAGE
* (MUST BE AT THE BEGINNING OF A PAGE)
*************************************************
MBASE   EQU     *                       START OF WORK PAGE IN ROM
* MSGUP MUST BE FIRST IN PAGE
MSGUP   FCC     /ASSIST05 1.1/          FIREUP MESSAGE
MSGNUL  FCB     EOT                     END OF STRING
MSGERR  FCC     /? ERROR ?/
        FCB     EOT
MSGS1   FCB     'S,'1,EOT               S1 START RECORD TEXT
MSGS9   FCC     /S9030000FC/
        FCB     CR                      $9 RECORD TEXT
MSGMOF  FCB     DC4,DC3,EOT             MOTORS OFF TEXT
MSGWAS  FCC     /IS OPCODE/
        FCB     EOT
VECTAB  FCB     JMPOP
        FDB     TIRQ
        FCB     JMPOP
        FDB     TIRQ
        FCB     JMPOP
        FDB     IRQ
        FCB     JMPOP
        FDB     SWI
*************************************************
* GO --- START EXECUTION
*************************************************
CMDG    JSR     GETADR                  OBTAIN INPUT ADDRESS
        BCC     NEXT                    DO CONTINUE IF NONE
        LDA     ADDRH                   CHECK ADDRESS BOUNDARIES
        CMP     #$20                    FOR OVERRUN
        BLO     GADDR
        JMP     CMDERR                  ERROR IF $2000 OR LARGER
GADDR   JSR     LOCSTK                  OBTAIN CURRENT STACK ADDRESS-3
        LDA     ADDRH                   LOAD PC HIGH
        STA     7,X                     INTO STACK
        LDA     ADDRL                   LOAD PC LOW
        STA     8,X                     INTO STACK
NEXT    BRSET   7,WORK4,CONT
        JMP     CMD
CONT    JSR     SCNBKP                  INIT BREAKPOINT SCAN PARMS
GOINSB  LDA     ,X                      LOAD HI BYTE
        BMI     GONOB                   BRA EMPTY
        STA     ADDRH                   STORE HI ADDRESS
        LDA     1,X                     LOAD LOW
        STA     ADDRL                   STORE LOW
        JSR     LOAD                    LOAD OPCODE
        STA     2,X                     STORE INTO TABLE
        LDA     #SWIOP                  REPLACE WITH OPCODE
        JSR     STORE                   STORE IN PLACE
GONOB   INCX                            TO
        INCX                            NEXT
        INCX                            BREAKPOINT
        DEC     PNCNT                   COUNT DOWN
        BNE     GOINSB                  LOOP IF MORE
        COM     SWIFLG                  FLAG BREAKPOINTS ARE IN
****RESET USERS TIMER ENVIRONMENT* *****
        RTI                             RESTART PROGRAM
*************************************************
* CLBYTE - LOAD SUBROUTINE TO READ NEXT         *
* BYTE, ADJUST CHECKSUM,                        *
* DECREMENT COUNT.                              *
* OUTPUT: A=BYTE * L
* CC=REFLECTS COUNT DECREMENT                   *
*************************************************
CLBYTE  BSR     GETBYT                  OBTAIN NEXT BYTE
        BCC     CMDMIN                  ERROR IF NONE
        STA     WORK2                   SAVE VALUE
        ADD     CHKSUM                  ADD TO CHECKSUM
        STA     CHKSUM                  REPLACE
        LDA     WORK2                   RELOAD BYTE VALUE
        DECX                            COUNT DOWN
        RTS                             RETURN TO CALLER
*************************************************
* GETBYT - READ BYTE IN HEX SUBROUTINE          *
* OUTPUT: C=0, Z=1 NO NUMBER                    *
* C=0, Z=0 INVALID NUMBER                       *
* C=1, Z=1, A=BINARY BYTE VALUE                 *
*************************************************
GETBYT  JSR     GETNYB                  GET HEX DIGIT
        BCC     GETBRZ                  RETURN NO NUMBER
GETBY2  ASLA                            SHIFT
        ASLA                            OVER
        ASLA                            BY
        ASLA                            FOUR
        STA     WORK2                   SAVE HIGH HEX DIGIT
        JSR     GETNYB                  GET LOW HEX
        TSTA                            FORCE Z=0 (DELIMITER IF INVALID)
        BCC     GETBRT                  RETURN IF INVALID NUMBER
        ORA     WORK2                   COMBINE HEX DIGITS
GETBRZ  CLR     WORK2                   SET Z=1
GETBRT  RTS                             RETURN TO CALLER
*************************************************
* L -- LOAD FILE INTO MEMORY COMMAND            *
*************************************************
CMDL    JSR     CHRIN                   READ CARRIAGE RETURN
        LDA     #DC1                    TURN ON READER
        JSR     CHROUT                  WITH DC1 CONTROL CODE
* SEARCH FOR AN 'S'
CMDLT   JSR     CHRIN                   READ A CHARACTER
CMDLSS  CMP     #'S                     ? 'S'
        BNE     CMDLT                   LOOP IF NOT
        JSR     CHRIN                   READ SECOND CHARACTER
        CMP     #'9                     ? '$9' RECORD
        BEQ     CLEOF                   BRANCH END OF FILE
        CMP     #'1                     ? 'S1' RECORD
        BNE     CMDLSS                  NO, TRY 'S' AGAIN
* READ ADDRESS AND COUNT
        CLR     CHKSUM                  ZERO CHKSUM
        BSR     CLBYTE                  OBTAIN SIZE OF RECORD
        TAX                             START COUNTDOWN IN X REGISTER
        BSR     CLBYTE                  OBTAIN START OF ADDRESS
        STA     ADDRH                   STORE IT
        BSR     CLBYTE                  OBTAIN LOW ADDRESS
        STA     ADDRL                   STORE IT
* NOW LOAD TEXT
CLLOAD  BSR     CLBYTE                  NEXT CHARACTER
        BEQ     CLEOR                   BRANCH IF COUNT DONE
        JSR     STORE                   STORE CHARACTER
        JSR     PTRUP1                  UP ADDRESS POINTER
        BRA     CLLOAD                  LOOP UNTIL COUNT DEPLETED
* END OF RECORD
CLEOR   INC     CHKSUM                  TEST VALID CHECKSUM
        BEQ     CMDL                    CONTINUE IF SO
CMDMIN  JMP     CMDERR                  ERROR IF INVALID
* END OF FILE
        BSR     CLBYTE                  READ $9 LENGTH
        TAX                             PREPARE $9 FLUSH COUNT
CLEOFL  BSR     CLBYTE                  SKIP HEX PAIR
        BNE     CLEOFL                  BRANCH MORE
        LDX     #MSGMOF-MBASE           TURN MOTORS OUT
        JMP     CMDPDT                  SEND AND END COMMAND
*************************************************
* M -- EXAMINE/CHANGE MEMORY                    *
* MCHNGE -- REGISTER CHANGE ENTRY POINT         *
*************************************************
CMDM    JSR     GETADR                  OBTAIN ADDRESS VALUE
        BCC     CMDMIN                  INVALID IF NO ADDRESS
        LDA     ADDRH                   CHECK ADDRESS
        CMP     #$20                    FOR OVERRUN
        BLO     CMDMLP
        JMP     CMDERR                  ERROR IF $2000 OF LARGER
CMDMLP  JSR     PRTADR                  PRINT OUT ADDRESS AND SPACE
MCHNGE  BSR     LOAD                    LOAD BYTE INTO A REGISTER
        JSR     CRBYTS                  PRINT WITH SPACE
        JSR     GETNYB                  $EE IF CHANGE WANTED
        BCC     CMDMDL                  BRANCH NO
        BSR     GETBY2                  OBTAIN FULL BYTE
        BNE     CMDMIN                  TERMINATE IF INVALID HEX
        Bcc     CMDMDL                  BRANCH IF OTHER DELIMITER
        BSR     STORE                   STORE NEW VALUE
        BCS     CMDMIN                  BRANCH IF STORE FAILS
        JSR     CHRIN                   OBTAIN DELIMITER
* CHECK OUT DELIMITERS
CMDMDL  CMP     #LF                     ? TO NEXT BYTE
        BEQ     CMDMLF                  BRANCH IF SO
        CMP     #'h                     ? TO PREVIOUS BYTE
        BEQ     CMDMBK                  BRANCH YES
        JMP     CMDNNL                  ENTER COMMAND HANDLER
CMDMBK  TST     ADDRL                   ? LOW BYTE ZERO
        BNE     CMDMB2                  NO, JUST DOWN IT
        DEC     ADDRH                   DOWN HIGH FOR CARRY
        LDA     ADDRH                   CHECK ADDRESS
        CMP     #$FF                    FOR UNDERFLOW
        BNE     CMDMB2
        LDA     #$1F                    CLEAR ADDRESS ON UNDERFLOW
        STA     ADDRH
CMDMB2  DEC     ADDRL                   DOWN LOW BYTE
        BSR     PCRLF                   TO NEXT LINE
        BRA     CMDMLF                  TO NEXT BYTE
CMDMLF  LDA     #CR                     SEND JUST CARRIAGE RETURN
        JSR     CHROU2                  OUTPUT IT
        BSR     PTRUP1                  UP POINTER BY ONE
        LDA     ADDRH                   CHECK ADDRESS
        CMP     #$20                    FOR OVERRUN
BS      18F5    BLO                     CMDMLP
        CLR     ADDRH                   IF LARGER CLEAR
        CLR     ADDRL                   ADDRESS
        BRA     CMDMLP                  TO NEXT BYTE
*************************************************
* LOAD - LOAD INTO A FROM ADDRESS IN            *
* POINTER ADDRH/ADDRL                           *
* INPUT: ADDRH/ADDRL=ADDRESS                    *
* OUTPUT: A=BYTE FROM POINTED LOCATION          *
* X IS TRANSPARENT                              *
* WORK1,WORK2,WORK3 USED                        *
*************************************************
LOAD    STX     WORK1                   SAVE X
        LDX     #$C6                    C6=LDA 2-BYTE EXTENDED
LDSTCM  STX     WORK2                   PUT OPCODE IN PLACE
        LDX     #$81                    81=RTS
        STX     WORK3                   NOW THE RETURN
        JSR     WORK2                   EXECUTE BUILT ROUTINE
        LDX     WORK1                   RESTORE X
        RTS                             AND EXIT
*************************************************
* STORE - STORE A AT ADDRESS IN POINTER         *
* ADDRH/ADDRL                                   *
* INPUT: A=BYTE TO STORE                        *
* ADDRH/ADDRL=ADDRESS                           *
* OUTPUT: C=0 STORE WENT OK                     *
* C=1 STORE DID NOT TAKE (NOT RAM)              *
* REGISTERS TRANSPARENT                         *
* (A NOT TRANSPARENT ON INVALID STORE)          *
* WORK1 ,WORK2,WORK3,WORK4 USED                 *
*************************************************
STORE   STX     WORK1                   SAVE X
        LDX     #$C7                    C7=STA 2-EXTENDED
        BSR     LDSTCM                  CALL STORE ROUTINE
        STA     WORK4                   SAVE VALUE STORED
        BSR     LOAD                    ATTEMPT LOAD
        CMP     WORK4                   ? VALID STORE
        BEQ     STRTS                   BRANCH IF VALID
        SEC                             SHOW INVALID STORE
STRTS   RTS                             RETURN
*************************************************
* PTRUP1 - INCREMENT MEMORY POINTER             *
*************************************************
PTRUP1  INC     ADDRL                   INCREMENT LOW BYTE
        BNE     PRTRTS                  NON-ZERO MEANS NO CARRY
        INC     ADDRH                   INCREMENT HIGH BYTE
PRTRTS  RTS                             RETURN TO CALLER
*************************************************
* PUTBYT --- PRINT A IN HEX                     *
* X TRANSPARENT                                 *
* WORK1 USED                                    *
*************************************************
PUTBYT  STA     WORK1                   SAVE A
        LSRA                            SHIFT TO
        LSRA                            LEFT HEX
        LSRA                            DIGIT
        LSRA                            SHIFT HIGH NYBBLE DOWN
        BSR     PUTNYB                  PRINT IT
        LDA     WORK1
* FALL INTO PUTNYB
*************************************************
* PUTNYB --- PRINT LOWER NYBBLE OF A IN HEX     *
* A,X TRANSPARENT                               *
*************************************************
PUTNYB  AND     #$F                     MASK OFF HIGH NYBBLE
        ADD     #'0                     ADD ASCII ZERO
        CMP     #'9                     CHECK FOR A-F
        BLS     CHROUT                  OK, SEND OUT
        ADD     #'A-'9-1                ADJUSTMENT FOR HEX A-F
        BRA     CHROUT                  NOW SEND OUT
*************************************************
* PDATA - PRINT MONITOR STRING AFTER CR/LF
* PDATA1 - PRINT MONITOR STRING
* PCRLF - PRINT CARRIAGE RETURN AND LINE FEED
* INPUT: X=OFFSET TO STRING IN BASE PAGE (UNUSED FOR PCRLF)
*************************************************
PCRLF   LDX     #MSGNUL-MBASE           LOAD NULL STRING ADDRESS
PDATA   LDA     #CR                     PREPARE CARRIAGE RETURN
PDLOOP  BSR     CHROUT                  SEND NEXT CHARACTER
PDATA1  LDA     MBASE,X                 LOAD NEXT CHARACTER
        INCX                            BUMP POINTER UP ONE
        CMP     #EOT                    ? END OF STRING
        BNE     PDLOOP                  BRANCH NO
        RTS                             RETURN DONE
*************************************************
* GETNYB - OBTAIN NEXT HEX CHARACTER            *
* OUTPUT: C=0 NOT HEX INPUT, A=DELIMITER        *
* C=1 HEX INPUT, A=BINARY VALUE                 *
* X TRANSPARENT                                 *
* WORK1 IN USE                                  *
*************************************************
GETNYB  JSR     CHRIN                   OBTAIN CHARACTER
        CMP     #'0                     ? LOWER THAN ZERO
        BLO     BCC                     GETNCH BRANCH NOT HEX
        CMP     #'9                    ? HIGHER THAN NINE
        BLS     GETNHX                  BRANCH IF 0 THRU 9
        CMP     #'A                     ? LOWER THAN AN "A"
        BLO     BCC                     GETNCH BRANCH NOT HEX
        CMP     #'F                     ? HIGHER THAN AN "F"
        BHI     BCC                     GETNCH BRANCH NOT HEX
        SUB     #7                      ADJUST TO $A OFFSET
GETNHX  AND     #$0F                    CLEAR ASCII BITS
        SEC                             SET CARRY
        RTS                             RETURN
GETNCH  CLC                             CLEAR CARRY FOR NO HEX
        RTS                             RETURN
*************************************************
* GETADR - BUILD ANY SIZE BINARY                *
* NUMBER FROM INPUT.                            *
* LEADING BLANKS SKIPPED.                       *
* OUTPUT: CC=0 NO NUMBER ENTERED                *
* CC=1 ADDRH/ADDRL HAS NUMBER                   *
* A=DELIMITER                                   *
* A,X VOLATILE                                  *
* WORK1 IN USE
*************************************************
GETADR  JSR     PUTSP
        CLR     ADDRH                   CLEAR HIGH BYTE
        BSR     GETNYB                  OBTAIN FIRST HEX VALUE
        BCS     GETGTD                  BRANCH IF GOT IT
        CMP     #'                      ? SPACE
        BEQ     GETADR                  LOOP IF SO
        CLC                             CLC RETURN NO NUMBER
        RTS                             RETURN
GETGTD  STA     ADDRL                   INITIALIZE LOW VALUE
GETALP  BSR     GETNYB                  OBTAIN NEXT HEX
        BCC     GETARG                  BRANCH IF NONE
        ASLA                            OVER
        ASLA                            FOUR
        ASLA                            BITS
        ASLA                            FOR SHIFT
        LDX     #4                      LOOP FOUR TIMES
GETASF  ASLA                            SHIFT NEXT BIT
        ROL     ADDRL                   INTO LOW BYTE
        ROL     ADDRH                   INTO HIGH BYTE
        DECX                            COUNT DOWN
        BNE     GETASF                  LOOP UNTIL DONE
        BRA     GETALP                  NOW DO NEXT HEX
GETARG  $EC     SHOW                    NUMBER OBTAINED
        RTS                             RETURN TO CALLER
*************************************************
* CHRIN - OBTAIN NEXT INPUT CHARACTER           *
* OUTPUT: A=CHARACTER RECEIVED                  *
* X IS TRANSPARENT                              *
* NULLS AND RUBOUTS IGNORED                     *
* ALL CHARACTERS ECHOED OUT                     *
* WORK1 USED                                    *
*************************************************
CHRIN   LDA     ACIA                    LOAD STATUS REGISTER
        LSRA                            CHECK FOR INPUT
        BCC     CHRIN                   LOOP UNTIL SOME
        LDA     ACIA+1                  LOAD CHARACTER
        AND     #$7F                    AND OFF PARITY
        BEQ     CHRIN                   IGNORE NULLS
        CMP     #$7F                    ? DEL
        BEQ     CHRIN                   IGNORE DELETES
        STA     WORK1                   SAVE CHARACTER
        BSR     CHROUT                  ECHO CHARACTER
        LDA     WORK1                   RESTORE CHARACTER
        RTS                             RETURN TO CALLER
*************************************************
* PUTS --- PRINT A BLANK (SPACE)                *
* X UNCHANGED                                   *
*************************************************
PUTSP   LDA     #SP                     LOAD SPACE
* FALL INTO CHROUT
*************************************************
* CHROUT - SEND CHARACTER TO TERMINAL.          *
* A CARRIAGE RETURN HAS AN                      *
* ADDED LINE FEED.                              *
* INPUT: A=ASCII CHARACTER TO SEND              *
* A NOT TRANSPARENT                             *
*************************************************
CHROUT  CMP     #CR                     ? CARRIAGE RETURN
        BNE     CHROU2                  BRANCH NOT
Dodcon  19OEE   AD                      02 19F2 BSR CHROU2 RECURSIVE CALL FOR CR
        LDA     #LF                     NOW SEND LINE FEED
CHROU2  STA     ACIA+1                  STORE CHARACTER INTO PIC
CHROLP  LDA     ACIA                    LOAD STATUS REGISTER
        BIT     #$02                    ? READY FOR NEXT
        BEQ     CHROLP                  LOOP UNTIL READY
        RTS                             AND RETURN
KEKE    KKK
* RESET --- POWER ON RESET ROUTINE
*
* INITIALIZE ACIA, PUT OUT STARTUP MESSAGE
*************************************************
RESET   LDX     #11                     MOVE VECTOR TABLE
RST     LDA     VECTAB,X                TO RAM USING A
        STA     VECRAM,X                BLOCK MOVE ROUTINE
        DECX                            TO ALLOW CHANGES
        BPL     RST                     ON THE FLY
        LDA     #3                      RESET ACIA
        STA     ACIA                    TO INITIALIZE
        LDA     #$51                    8 BITS-NO PARITY-2 STOP BITS
        STA     ACIA                    SETUP ACIA PARAMETERS
        JSR     SCNBKP                  CLEAR BREAKPOINTS
        LDA     #$FF                    TURN HIGH BIT ON
REBCLR  STA     ,X                      SHOW SLOT EMPTY
        INCX                            TO
        INCX                            NEXT
        INCX                            SLOT
        DEC     PNCNT                   COUNT DOWN
        BNE     REBCLR                  CLEAR NEXT
RESREN  CLR     SWIFLG                  SETUP MONITOR ENTRANCE VALUE
        SWI                             ENTER MONITOR
        BRA     RESREN                  REENTER IF "G"
*************************************************
* COMMAND HANDLER                               *
*************************************************
CMDPDT  JSR     PDATA                   SEND MESSAGE OUT
CMD     JSR     PCRLF                   TO NEW LINE
CMDNNL  LDA     #PROMPT                 READY PROMPT CHR
        BSR     CHROUT                  SEND IT OUT
        JSR     REMBKP                  REMOVE BREAKPOINTS IF IN
        BSR     CHRIN                   GET NEXT CHARACTER
        CLRX                            ZERO FOR SOME COMMANDS
        CMP     #'C                     ? DISPLAY /CHANGE C REGISTER
        BEQ     CMDC                    BRANCH IF SO
        CMP     #'X                     ? DISPLAY/CHANGE X REGISTER
        BEQ     CMDX                    BRANCH IF SO
        CMP     #'A                    ? DISPLAY/CHANGE A REGISTER
        BEQ     CMDA                    BRANCH IF SO
        CMP     #'R                     ? REGISTER DISPLAY
        BEQ     REGR                    BRANCH YES
        CMP     #'L                     ? LOAD FILE
        BNE     NOTL                    NOPE
        JMP     CMDL                    BRANCH YES -
NOTL    CMP     #'G                     ? GO COMMAND
        BNE     NOTG                    BRANCH NOT
        BSET    7,WORK4
ISP     JMP     CMDG                    GO TO IT
NOTG    CMP     #'M                     2? MEMORY COMMAND
        BNE     NOTM                    BRANCH NOT
        JMP     CMDM                    GO TO MEMORY DISPLAY/CHANGE
NOTM    CMP     #'T                     ? TRACE
        BNE     NOTT                    ERROR IF NOT
        JMP     CMDT                    GO TO IT
NOTT    CMP     #'W                     ? WRITE MEMORY
        BNE     NOTW                    BRANCH NO
        JMP     CMDW                    GO TO IT
NOTW    CMP     #'B                     ? BREAKPOINT COMMAND
        BEQ     BPNT                    YES
        CMP     #'P                     2? PC COMMAND
        BNE     CMDERR
        BCLR    7,WORK4
        BRA     ISP
CMDERR  LDX     #MSGERR-MBASE           LOAD ERROR STRING
TOCPDT  BRA     CMDPDT                  AND SEND IT OUT
REGR    JMP     CMDR
BPNT    JMP     CMDB
*************************************************
* X -- DISPLAY/CHANGE X REGISTER                *
*************************************************
CMDX    INCX                            INCREMENT INDEX
* FALL THROUGH
*************************************************
* A -- DISPLAY/CHANGE A REGISTER
*************************************************
CMDA    INCX                            INCREMENT INDEX
* FALL THROUGH
*************************************************
* C -- DISPLAY/CHANGE CONDITION CODE REGISTER   *
*************************************************
CMDC    JSR     PUTSP                   SPACE BEFORE VALUE
        STX     WORK1                   SAVE INDEX VALUE
        JSR     LOCSTK                  LOCATE STACK ADDRESS
        TXA                             STACK-2 TO A
        ADD     WORK1                   ADD PROPER OFFSET
        ADD     #4                      MAKE UP FOR ADDRESS RETURN DIFFERE
        CLR     ADDRH                   SETUP ZERO HIGH BYTE
        STA     ADDRL                   AND SET IN LOW
TOMCHG  JMP     MCHNGE                  NOW ENTER MEMORY CHANGE COMMAND
*************************************************
* S W I HANDLER                                 *
* DETERMINE PROCESSING SWIFLG VALUE             *
*************************************************
SWI     CLRX                            DEFAULT TO STARTUP MESSAGE
        TST     SWIFLG                  IS THIS RESET
        BNE     SWICHK                  IF NOT REMOVE BREAKPOINTS
        INC     SWIFLG                  SHOW WE ARE NOW INITIALIZED
        BRA     CMDPDT                  TO COMMAND HANDLER
SWICHK  JSR     SCNBKP
SWIREP  LDA     ,X                      RESTORE OPCODES
        BMI     SWINOB
        STA     ADDRH
        LDA     1,X
        STA     ADDRL
        LDA     2,X
        JSR     STORE
SWINOB  INCX
        INCX
        INCX
        DEC     PNCNT
        BNE     SWIREP
* TRACE ONE INSTRUCTION IF PC AT A BREAKPOINT
        JSR     LOCSTK                  FIND STACK
        LDA     8,X                     GET PC AND ADJUST
        SUB     #1
        STA     WORK4                   SAVE PCL
        LDA     7,X
        SBC     #0
        STA     WORK3                   SAVE PCH
        STX     WORK5                   SAVE SP
        JSR     SCNBKP
SWITRY  LDA     0,X
        BMI     SWICMP
        CMP     WORK3
        BNE     SWICMP
        LDA     1,X
        CMP     WORK4
        BNE     SWICMP
        LDX     WORK5
        STA     8,X
        LDA     WORK3
        STA     7,X
        CLR     WORK7
        LDA     #1
        STA     WORK6
        JMP     TRACE
SWICMP  INCX
        INCX
        INCX
        DEC     PNCNT
        BNE     SWITRY
* FALL INTO REGISTER DISPLAY FOR BREAKPOINT
*************************************************
* R -- PRINT REGISTERS                          *
*************************************************
CMDR    JSR     PUTSP                   SPACE BEFORE DISPLAY
        BSR     LOCSTK                  LOCATE STACK-4
        LDA     7,X                     OFFSET FOR PC HIGH
        STA     7,X                     RESTORE INTO STACK
        JSR     PUTBYT                  PLACE BYTE OUT
        LDA     8,X                     OFFSET TO PC LOW
        BSR     CRBYTS                  TO HEX AND SPACE
        LDA     5,X                     NOW TO A REGISTER
        BSR     CRBYTS                  TO HEX AND SPACE
        LDA     6,X                     NOW X
        BSR     CRBYTS                  HEX AND SPACE
        LDA     4,X                     NOW CONDITION CODE
        ORA     #$E0                    SET ON UNUSED BITS
        STA     4,X                     RESTORE
        BSR     CRBYTS                  HEX AND SPACE
        TXA                             STACK POINTER-3
        ADD     #8                      TO USERS STACK POINTER
        BSR     CRBYTS                  TO HEX AND SPACE
GTOCMD  JMP     CMD                     BACK TO COMMAND HANDLER
* PRINT ADDRESS SUBROUTINE (X UNCHANGED)
PRTADR  LDA     ADDRH                   LOAD HIGH BYTE
        JSR     PUTBYT                  SEND OUT AS HEX
        LDA     ADDRL                   LOAD LOW BYTE
CRBYTS  JSR     PUTBYT                  PUT OUT IN HEX
        JMP     PUTSP                   FOLLOW WITH A SPACE
*************************************************
* LOCSTK - LOCATE CALLERS STACK POINTER         *
* RETURNS X=STACK POINTER-3                     *
* X VOLATILE                                    *
*************************************************
LOCSTK  BSR     LOCST2                  LEAVE ADDRESS ON STACK
STKHI   EQU     */256                   HI BYTE ON STACK
STKLOW  EQU     *-(*/256)*256           LOW BYTE ON STACK
        RTS                             RETURN WITH RESULT
LOCST2  LDX     #$7F                    LOAD HIGH STACK WORD ADDRESS
LOCLOP  LDA     #STKHI                  HIGH BYTE FOR COMPARE
LOCDWN  DECX                            TO NEXT LOWER BYTE IN STACK
        CMP     ,X                      ? THIS THE SAME
        BNE     LOCDWN                  IF NOT TRY NEXT LOWER
        LDA     #STKLOW                 COMPARE WITH LOW ADDRESS BYTE
        CMP     1,X                     ? FOUND RETURN ADDRESS
        BNE     LOCLOP                  LOOP IF NOT
        RTS                             RETURN WITH X SET
*************************************************
* B -- BREAKPOINT CLEAR, SET, OR DISPLAY        *
*************************************************
CMDB    JSR     CHRIN                   READ NEXT CHARACTER
        CMP     #'                      ? DISPLAY ONLY
        BEQ     BDSPLY                  BRANCH IF SO
        BSR     PGTADR                  OBTAIN BREAKPOINT NUMBER
        TSTX                            ? ANY HIGH BYTE VALUE
        BNE     BKERR                   ERROR IF SO
        DECA                            DOWN COUNT BY ONE
        CMP     #NUMBKP                 ? TO HIGH
        BHS     BKERR                   ERROR IF SO
        ASLA                            TIMES TWO
        ADD     ADDRL                   PLUS ONE FOR THREE TIMES
        ADD     #BKPTBL                 FIND TABLE ADDRESS
        STA     WORK2                   SAVE ADDRESS
        BSR     PGTADR                  OBTAIN ADDRESS
        CPX     #$20
        BHS     BKERR
        LDX     WORK2                   RELOAD ENTRY POINTER
        STA     1,X                     SAVE LOW ADDRESS
        BNE     BKNOCL                  BRANCH IF NOT ZERO
        LDA     ADDRH                   LOAD HIGH ADDRESS
        BNE     BKNCR                   BRANCH NOT NULL
        DECA                            COMA CREATE NEGATIVE VALUE
        STA     ,X                      STORE AS HIGH BYTE
        BRA     GTOCMD                  END COMMAND
BKNOCL  LDA     ADDRH                   LOAD HIGH ADDRESS
BKNCR   STA     ,X                      STORE HIGH BYTE
        JSR     LOAD                    LOAD BYTE AT THE ADDRESS
        COMA                            INVERT IT
        JSR     STORE                   ATTEMPT STORE
        BCS     BKERR                   ERROR IF DID NOT STORE
        COMA                            RESTORE PROPER VALUE
        JSR     STORE                   STORE IT BACK
        BRA     GTOCMD                  END COMMAND
* DISPLAY BREAKPOINTS
BDSPLY  JSR     SCNBKP                  PREPARE SCAN OF TABLE
BDSPLP  LDA     ,X                      OBTAIN HIGH BYTE
        BMI     BDSKP                   SKIP IF UNUSED SLOT
        JSR     PUTBYT                  PRINT OUT HIGHT BYTE
        LDA     1,X                     ' LOAD LOW BYTE
        BSR     CRBYTS                  PRINT IT OUT WITH A SPACE
BDSKP   INCX                            TO
        INCX                            NEXT
        INCX                            ENTRY
        DEC     PNCNT                   COUNT DOWN
        BNE     BDSPLP                  LOOP IF MORE
        BRA     GTOCMD                  END COMMAND
BKERR   JMP     CMDERR                  GIVE ERROR RESPONSE
*************************************************
* W -- WRITE MEMORY TO TAPE FILE $1/$9          *
*************************************************
PGTADR  JSR     GETADR                  OBTAIN INPUT ADDRESS
        BCC     BKERR                   ABORT IF NONE
        LDX     ADDRH                   READY HIGH BYTE
        LDA     ADDRL                   READY LOW BYTE
        RTS                             BACK TO PUNCH COMMAND
CMDW    BSR     PGTADR                  GET STARTING ADDRESS
        CPX     #$20
        BHS     BKERR
        STA     WORK4                   INTO WORK4
        STX     WORK3                   AND WORK3
        BSR     PGTADR                  GET ENDING ADDRESS
        CPx     #$20
        BHS     BKERR
        INCA                            ADD ONE TO INCLUDE TOP BYTE
        BNE     PUPHI                   BRANCH NO CARRY
        INCX                            UP HIGH BYTE AS WELL
PUPHI   SUB     WORK4                   COMPUTE SIZE
        STA     PNRCNT+1                AND SAVE
        TXA                             NOW
$BC     WORK3   SIZE                    HIGH BYTE
        STA     PNRCNT                  AND SAVE
        LDA     WORK4                   MOVE
        STA     ADDRL                   TO
        LDA     WORK3                   MEMORY
        STA     ADDRH                   POINTER
* ADDR->MEMORY START, PNRCNT=BYTE COUNT OF AREA
* NOW TURN ON THE PUNCH
        LDA     #DC2                    PUNCH ON CONTROL
        JSR     CHROUT                  SEND OUT
* NOW SEND CR FOLLOWED BY 24 NULLS AND 'S1'
PREC    BSR     PNCRNL                  SEND CR/LF AND NULLS
        LDX     #MSGS1-MBASE            POINT TO STRING
        JSR     PDATAL]                 SEND '$1' OUT
* NOW SEND NEXT 24 BYTES OR LESS IF TO THE END
        LDA     PNRCNT+1                LOW COUNT LEFT
        SUB     #24                     MINUS 24
        STA     PNRCNT+1                STORE RESULT
        BCC     PALL24                  IF NO CARRY THEN OK
        DEC     PNRCNT                  DOWN HIGH BYTE
        BPL     PALL24                  ALL 24 OK
        ADD     #24                     WAS LESS SO BACK UP TO ORIGINAL
        BRA     PGOTC                   GO USE COUNT HERE
PALL24  LDA     #24                     USE ALL 24
PGOTC   STA     PNCNT                   COUNT FOR THIS RECORD
* SEND THE FRAME COUNT AND START CHECKSUMMING
        CLR     CHKSUM
        ADD     #3                      ADJUST FOR COUNT AND ADDRESS
        BSR     PUNBYT                  SEND FRAME COUNT
* SEND ADDRESS
        LDA     ADDRH                   HI BYTE
        BSR     PUNBYT                  SEND IT
        LDA     ADDRL                   LOW BYTE
        BSR     PUNBYT                  SEND IT
* NOW SEND DATA
PUNLOP  JSR     LOAD                    LOAD NEXT BYTE
        BSR     PUNBYT                  SEND IT OUT
        JSR     PTRUPL                  UP ADDRESS BY ONE
        DEC     PNCNT                   COUNT DOWN
        BNE     PUNLOP                  LOOP UNTIL ZERO
* SEND OUT THE CHECKSUM
        LDA     CHKSUM                  LOAD CHECKSUM
        COMA                            COMPLEMENT IT
        BSR     PUNBYT                  SEND IT OUT
* LOOP OR SEND $9
        LDA     PNRCNT                  ? MINUS
        BMI     PNEND                   YES QUIT
        ADD     PNRCNT+1                ? ZERO
        BNE     PREC                    NO, DO NEXT RECORD
PNEND   BSR     PNCRNL                  SEND CR AND NULLS
        LDX     #MSGS9-MBASE            LOAD $9 TEXT
        JSR     PDATA1                  SEND AND TO COMMAND HANDLER
        JMP     CMD                     TO COMMAND HANDLER
* SUB TO SEND BYTE IN HEX AND ADJUST CHECKSUM
PUNBYT  TAX                             SAVE BYTE
        ADD     CHKSUM                  ADD TO CHECKSUM
        STA     CHKSUM                  STORE BACK
        TXA                             RESTORE BYTE
        JMP     PUTBYT                  SEND OUT IN HEX
* SUB TO SEND CR/LF AND 24 NULLS
PNCRNL  JSR     PCRLF                   SEND CR/LF
        LDX     #24                     COUNT NULLS
PNULLS  CLRA                            CREATE NULL
        JSR     CHROUT                  SEND OUT
        DECX                            COUNT DOWN
        BNE     PNULLS                  LOOP UNTIL DONE
        RTS                             RETURN
*************************************************
* T -- TRACE COMMAND                            *
*************************************************
CMDT    LDA     #1                      DEFAULT COUNT
        STA     ADDRL                   TO ONE *GETADR CLEARS ADDRH*
        JSR     GETADR                  BUILD ADDRESS IF ANY
        LDA     ADDRH                   SAVE VALUE IN TEMPORARY
        STA     WORK7                   LOCATIONS FOR LATER
        LDA     ADDRL                   USE
        STA     WORK6
* SETUP TIMER TO TRIGGER INTERRUPT
TRACE   EQU     *
        JSR     LOCSTK
        LDA     4,X                     GET CURRENT USER I-MASK
        AND     #8
        STA     WORK5                   SAVE IT
        LDA     7,X                     GET CURRENT USER PC
        STA     ADDRH
        LDA     8,X
        STA     ADDRL
        JSR     LOAD                    GET OPCODE
        CMP     #$83                    SWI?
        BNE     TRACE3                  IF YES THEN
        LDA     ADDRL                   INC USER PC
        ADD     #1
        STA     8,X
        LDA     ADDRH
        ADC     #0
        STA     7,X
        BRA     TIRQ                    CONTINUE TO TRACE
TRACE3  CMP     #$9B                    SEI?
        BNE     TRACE2                  IF YES
        LDA     4,X                     THEN SET IT IN THE STACK
        ORA     #8
        STA     4,X
        LDA     ADDRL                   THEN INC USER PC
        ADD     #1
        STA     8,X
        LDA     ADDRH
        ADC     #0
        STA     7,X
        BRA     TIRQ                    CONTINUE TO TRACE
TRACE2  CMP     #$9A                    CLI?
        BNE     TRACE1                  IF YES THEN
        CLR     WORK5
TRACE1  LDA     4,X
        AND     #$F7
        STA     4,X
        LDA     #16                     THEN SET UP TIMER
        STA     TIMER
        LDA     #8
        STA     TIMEC
        RTI                             EXECUTE ONE INSTRUCTION
*************************************************
* TIRQ -- TIMER INTERRUPT ROUTINE               *
*************************************************
TIRQ    EQU     *
* RESTORE I-MASK TO PROPER STATE
        LDA     #$40
        STA     TIMEC
        JSR     LOCSTK
        LDA     4,X
        ORA     WORK5
        STA     4,X
* $EE IF MORE TRACING IS DESIRED
        DEC     WORK6
        BNE     TRACE
        TST     WORK7
        BEQ     DISREG
        DEC     WORK7
        BRA     TRACE
DISREG  JMP     CMDR
*************************************************
* INT -- INTERRUPT ROUTINE                      *
*************************************************
IRQ     EQU     *
        JMP     CMDERR                  HARDWARE INTERRUPT UNUSED
*************************************************
* TWIRQ - TIMER INTERRUPT ROUTINE (WAIT MODE)   *
*************************************************
TWIRQ   EQU     *
        JMP     CMDERR                  TIMER WAIT INTERRUPT UNUSED
*************************************************
* DELBKP - DELETE BREAKPOINT SUBROUTINE         *
*************************************************
REMBKP  BSR     SCNBKP                  SETUP PARAMETERS
        BPL     REMRTS                  RETURN IF NOT IN
REMLOP  LDA     ,X                      LOAD HIGH ADDRESS
        BMI     REMNOB                  SKIP IF NULL
        STA     ADDRH                   STORE HIGH ADDRESS
        LDA     1,X                     LOAD LOW ADDRESS
        STA     ADDRL                   STORE IT
        LDA     2,X                     LOAD OPCODE
        JSR     STORE                   STORE IT BACK OVER 'SWI'
REMNOB  INCX                            TO
        INCX                            NEXT
        INCX                            ENTRY
        DEC     PNCNT                   COUNT DOWN
        BNE     REMLOP                  LOOP IF MORE
        COM     SWIFLG                  MAKE POSITIVE TO SHOW REMOVED
REMRTS  RTS                             RETURN
* SETUP FOR BREAKPOINT TABLE SCAN
SCNBKP  LDA     #NUMBKP                 LOAD NUMBER OF BREAKPOINTS
        STA     PNCNT                   SETUP FOR COUNTDOWN
        LDX     #BKPTBL                 LOAD TABLE ADDRESS
        TST     SWIFLG                  TEST IF BREAKPOINTS IN ALREADY
        RTS                             RETURN
*************************************************
* INTERRUPT VECTORS                             *
*************************************************
        ORG     MONSTR+$800-$A          START OF VECTORS
        FDB     VECRAM                  TIMER INTERRUPT HANDLER (WAIT MODE
        FDB     VECRAM+3                TIMER INTERRUPT HANDLER
        FDB     VECRAM+6                INTERRUPT HANDLER
        FDB     VECRAM+9                SWI HANDLER
        FDB     RESET                   POWER ON VECTOR
        END
