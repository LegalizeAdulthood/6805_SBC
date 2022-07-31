
# Memory map

<br>

ACIA - CS0, CS1, /CS2 <br>
 RTC - CS1, CS2 <br>
SRAM - /CS <br>
 ROM - /CE

Okay, 13 address bits a12 - a0 <br>
0 0000 0000 0000

Here is the High Level Address Decoder <br>
logic on the highest 2 bits of the address.

<br>
<br>

## Address Areas

```
 Address |
   Bits  | 
 12 | 11 | Area Accessed
----+----+---------------
  0 |  0 | RAM 1 / ACIA / RTC
  0 |  1 | RAM 2
  1 |  X | ROM
```

<br>
<br>

## Sections

```
              External
             
$0000                 Port A Data Register
$0001                 Port B Data Register
$0002 - $0003    X    
$0004                 Port A Data Direction Register
$0005                 Port B Data Direction Register
$0006            X    ACIA Control/Status Registers
$0007            X    ACIA Transmit/Receive Data Registers
$0008                 Timer Data Register
$0009                 Timer Control Register
$000A - $000F    X
$0010 - $003F         RAM
$0040 - $007F         Stack
$0080 - $00FF         RAM
$0100 - $010F    X    RTC
$0110 - $07FF    X    2Kx8 RAM 1
$0800 - $0FFF    X    2Kx8 RAM 2
$1000 - $1FFF    X    ROM
                      ISR vectors
$1FF6 - $1FF7         Timer from wait state
$1FF8 - $1FF9         Timer
$1FFA - $1FFB         External interrupt
$1FFC - $1FFD         SWI
$1FFE - $1FFF         Reset
```

<br>

