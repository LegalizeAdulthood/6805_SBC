
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

<br>

### Data Register

<kbd>  $0000  </kbd>  <kbd>  Port A  </kbd>

<br>

### Data Register

<kbd>  $0001  </kbd>  <kbd>  Port B  </kbd>

<br>

### External

<kbd>  $0002  -  $0003  </kbd>  <kbd>  External  </kbd>

<br>

### Data Direction Register

<kbd>  $0004  </kbd>  <kbd>  Port A  </kbd>

<br>

### Data Direction Register

<kbd>  $0005  </kbd>  <kbd>  Port B  </kbd>

<br>

### ACIA Control  &  Status Registers

<kbd>  $0006  </kbd>  <kbd>  External  </kbd>

<br>

### ACIA Transmit  &  Receive Data Registers

<kbd>  $0007  </kbd>  <kbd>  External  </kbd>

<br>

### Timer Data Register

<kbd>  $0008  </kbd>

<br>

### Timer Control Register

<kbd>  $0009  </kbd>

<br>

### External

<kbd>  $000A  -  $000F  </kbd>  <kbd>  External  </kbd>

<br>

### RAM

<kbd>  $0010  -  $003F  </kbd>

<br>

### Stack

<kbd>  $0040  -  $007F  </kbd>

<br>

### RAM

<kbd>  $0080  -  $00FF  </kbd>

<br>

### RTC

<kbd>  $0100  -  $010F  </kbd>  <kbd>  External  </kbd>

<br>

### 2K x 8 RAM 1

<kbd>  $0110  -  $07FF  </kbd>  <kbd>  External  </kbd>

<br>

### 2K x 8 RAM 2

<kbd>  $0800  -  $0FFF  </kbd>  <kbd>  External  </kbd>

<br>

### ROM  &  ISR vectors

<kbd>  $1000  -  $1FFF  </kbd>  <kbd>  External  </kbd>

<br>

### Timer from wait state

<kbd>  $1FF6  -  $1FF7  </kbd>

<br>

### Timer

<kbd>  $1FF8  -  $1FF9  </kbd>

<br>

### External Interrupt

<kbd>  $1FFA  -  $1FFB  </kbd>

<br>

### SWI

<kbd>  $1FFC  -  $1FFD  </kbd>

<br>

### Reset

<kbd>  $1FFE  -  $1FFF  </kbd>

<br>

