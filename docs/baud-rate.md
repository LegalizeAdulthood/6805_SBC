# Baud-Rate Selection

## Selected Clock Configuration

The following clock configuration is common to all baud-rate selection
alternatives.  The selected clock source is a 1.8432 MHz, 18 pF,
through-hole crystal connected to the MC14411 baud-rate generator.  The
MC14411 rate-select inputs are fixed at `RSA = 1` and `RSB = 1`, selecting
the X64 output range.  These are fixed hardware settings and are not
changed when selecting a baud rate.

The MC14411 reset input is connected to system reset.  It is asserted for
the duration of system reset and released when system reset is released.

The MC6850 ACIA uses its programmable /16 or /64 clock divider for normal
asynchronous RS-232 operation.  Its /1 mode is not included because it
expects an externally synchronized receive clock.  The selected divider
applies to both the receiver and transmitter.

Four MC14411 outputs provide the desired baud-rate range:

| MC14411 output | Clock frequency | MC6850 /16 | MC6850 /64 |
| --- | ---: | ---: | ---: |
| F1 | 614.4 kHz | 38,400 baud | 9,600 baud |
| F3 | 307.2 kHz | 19,200 baud | 4,800 baud |
| F8 | 38.4 kHz | 2,400 baud | 600 baud |
| F9 | 19.2 kHz | 1,200 baud | 300 baud |

The highest selected clock, 614.4 kHz, is below the MC6850's 0.8 MHz
maximum serial data-clock frequency for /16 and /64 operation.

The two halves of a 74153 dual 4-to-1 multiplexer select the same one of
F1, F3, F8, and F9.  One multiplexer output drives the MC6850 receive
clock and the other drives its transmit clock.  The halves share the
same two select signals, so receive and transmit always operate at the
same baud rate.  The MC6850 divider then selects one of the two rates in
the corresponding table row.

The [MC14411 data sheet](MC14411.pdf),
[MC6850 data sheet](MC6850.pdf),
[MC146805E2 data sheet](MC146805E2_1983.pdf), and
[chip inventory](chip-inventory.csv) provide the component details.

## Alternative 1: Manual Selection

A DIP switch drives the two 74153 select inputs.  Pull-up or pull-down
resistors give both inputs defined logic levels when a switch is open.
The four switch settings select F1, F3, F8, or F9; the MC6850 control
register selects /16 or /64 for a total of eight available baud rates.

The DIP switch changes only the clock range.  It requires no memory-map
entry or address-decode logic.  Because changing the select inputs while
the clock is running can produce a shortened clock pulse, the selection
should be changed while the system is reset or while the MC6850 is held
in master reset.  The MC6850 must then be initialized with the desired
divider.

## Alternative 2: Software Selection

A 7474 dual D-type flip-flop stores the two software-controlled select
bits.  CPU data bits D0 and D1 drive its D inputs, and its Q outputs drive
the shared select inputs of the 74153.  Both flip-flops are clocked by a
write strobe generated from suitable address-decode and bus-control
logic.  The asynchronous clear inputs establish selection `00` at reset;
the preset inputs remain inactive.

The write strobe must occur only for a write to the baud-rate selection
register and after the CPU data is valid.  The register address and the
exact decode logic remain to be defined in the SBC memory map.  The
selection mapped to `00` should be wired to the chosen power-on default
baud rate.

Software should change rates in this order:

1. Finish or stop any serial transfer.
2. Put the MC6850 in master reset.
3. Write the new 74153 selection to the 7474 register.
4. Program the MC6850 for /16 or /64 operation.
5. Resume communication after the remote endpoint is set to the same
   baud rate.

This alternative provides all eight rates without opening the enclosure,
at the cost of the 7474, a memory-mapped register, and its address-decode
and write-strobe logic.

## Alternative 3: I2C Software Selection

Two outputs from a suitable I2C GPIO expander drive the shared 74153
select inputs.  The expander's output latch stores the selection, so this
alternative does not require the 7474 or a dedicated memory-mapped
baud-rate register.  It instead depends on the planned I2C interface and
its supporting address-decode logic.

The GPIO expander must have logic levels compatible with the 74153 and a
defined power-on state.  If its outputs reset to inputs or a high-impedance
state, pull-up or pull-down resistors must establish a valid selection.
The corresponding 74153 input should be wired to the chosen power-on
default baud rate.

Changing the I2C output selection has the same clock-transition concern
as the other alternatives.  Software should place the MC6850 in master
reset, write the new selection to the GPIO expander, program the MC6850
for /16 or /64 operation, and then resume communication.  Baud-rate
selection is unavailable until the I2C interface and GPIO expander are
operational.

This alternative shares the planned I2C infrastructure and can use the
expander's remaining outputs for other purposes.  It avoids decode logic
dedicated solely to baud-rate selection, but makes baud-rate control
dependent on the I2C subsystem.

## Alternative 4: CPU Port Selection

Two otherwise-unused output bits from either CPU port A or CPU port B
drive the shared 74153 select inputs directly.  Both select bits should
come from the same port so that one write to the port register changes
them together.  The existing CPU port registers provide software control,
so this alternative requires no additional latch, I2C device, or external
address-decode logic.

The port pins are inputs during reset.  Pull-up or pull-down resistors must
therefore establish a valid 74153 selection until software configures the
pins as outputs.  Software should write the desired values to the port
output latch before setting the corresponding data-direction bits.  The
74153 input selected by the pull resistors should provide the chosen
power-on default baud rate.

Later changes should update both select bits with one port-register write
while preserving the values of unrelated pins on the same port.  Software
should place the MC6850 in master reset before the write, program the
MC6850 for /16 or /64 operation afterward, and then resume communication.

This alternative has the lowest additional component count and no
dependency on the planned I2C interface.  Its cost is two CPU port pins,
and all software that writes the selected port must preserve the
baud-rate selection bits.

## Open Decisions

- Choose DIP-switch, directly memory-mapped, I2C-controlled, or CPU-port
  selection.
- Assign F1, F3, F8, and F9 to the four 74153 input positions, including
  the desired `00` reset selection.
- If direct software selection is chosen, assign the register address and
  define its address-decode and write-strobe logic in the SBC design.
- If I2C software selection is chosen, select a compatible GPIO expander
  and define its reset behavior and I2C address.
- If CPU port selection is chosen, assign two bits from port A or port B
  and define their reset pull resistors.
