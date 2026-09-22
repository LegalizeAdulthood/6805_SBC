# MSM58321 Bus Interface

## Purpose

This note records the proposed interface between the MC146805E2 external bus
and the MSM58321 real-time clock at `$0100-$010F`. The board is still a
work-in-progress and does not yet have a complete schematic, so this document
separates settled CPU-visible behavior from remaining physical timing work.

Sources:

- [Memory map](../docs/memory-map.txt)
- [MC146805E2 data sheet](../docs/MC146805E2_1983.pdf)
- [MSM58321 data sheet](../docs/MSM58321.pdf)
- [Current address decode](New_Address_Decode.dig)
- [Current low-address latch](Address_Latch.dig)

## CPU-Visible Interface

The RTC occupies `$0100-$010F`. A CPU access is a byte read or byte write. The
low address nibble selects one of the MSM58321's 16 registers:

```text
RTC register address = CPU address A3-A0
```

The data-bus connection is intentionally four bits wide:

```text
CPU D0-D3 <-> MSM58321 D0-D3
CPU D4-D7     not connected to the MSM58321
```

On a byte write, the RTC consumes D0-D3 and ignores D4-D7. On a byte read while
the RTC is selected, D0-D3 contain the RTC register value and D4-D7 are zero.
Software may therefore use an ordinary byte access without a separate address
or data port.

## Bus Phases and Control Signals

The MC146805E2 multiplexes the low address and data on Port B. During the
address-strobe phase, B0-B7 carry A0-A7. During the data-strobe phase, B0-B7
carry the byte being read or written. R/~W is high for a read and low for a
write.

The MSM58321 control inputs are active high. CS1 and CS2 must both be high for
address, read, or write activity. `ADDRESS WRITE`, `READ`, and `WRITE` are
level-sensitive active-high inputs.

The intended glue relationships are:

```text
RTC_SELECT        = decode of $0100-$010F held for the complete bus cycle
RTC_CS1           = RTC_SELECT
RTC_CS2           = RTC_SELECT
RTC_ADDRESS_WRITE = RTC_SELECT AND AS
RTC_READ          = RTC_SELECT AND DS AND R/~W
RTC_WRITE         = RTC_SELECT AND DS AND NOT R/~W
```

`ADDRESS WRITE` must be asserted on both reads and writes. Qualifying it with
R/~W would prevent one kind of access from latching its register address. DS,
not the raw oscillator clock, is the correct data-phase qualifier for `READ`
and `WRITE`.

## Address-Decode Finding

`New_Address_Decode.dig` correctly recognizes `$0100-$010F` and produces an
active-high `RTCCS` while AS is high. That verifies the address range and chip
select polarity. However, this signal drops when the address phase ends, before
the DS data phase.

Consequently, the current `RTCCS` signal cannot directly drive both MSM58321
chip-select inputs for the complete transaction. The final glue must either:

- produce the RTC range decode without qualifying it by AS; or
- latch the AS-qualified decode until the data phase completes.

The existing `RTCCS` is suitable as an address-phase indication and is close
to the required `ADDRESS WRITE` signal, but it is not by itself a complete RTC
chip select.

## Timing Finding

The MSM58321 data sheet specifies a minimum 0.5 microsecond `ADDRESS WRITE`
pulse, 0.1 microsecond address hold time, and 2 microsecond `WRITE` pulse. The
MC146805E2 timing values evaluated at 1 MHz provide at least 0.85 microsecond
for AS but only about 1.8 microseconds for DS. The address phase meets the RTC
minimum, while the write phase is slightly short. Faster CPU clocks make both
phases shorter.

The physical design must settle the CPU oscillator and may need to stretch the
RTC control pulses. In particular, the provisional 4 MHz value currently used
by the MAME driver is not evidence that the physical board can directly drive
the RTC at that rate.

## Emulator Model

MAME models one completed CPU byte access atomically. For each access at
`$0100-$010F`, the driver:

1. Asserts CS1 and CS2.
2. Drives the low address nibble on D0-D3 and pulses `ADDRESS WRITE`.
3. For a write, drives CPU D0-D3 and pulses `WRITE`.
4. For a read, pulses `READ`, captures RTC D0-D3, and supplies zero on CPU
   D4-D7.
5. Deasserts CS1 and CS2.

This is the simplest model that preserves software-visible behavior while
using MAME's pin-level MSM58321 device. It deliberately does not simulate the
individual TTL propagation delays or pulse stretching. Those details can be
refined after the physical schematic and oscillator choice are settled.
