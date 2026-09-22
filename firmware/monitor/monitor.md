# Visual Monitor

## Overview

The monitor ROM is a full-screen visual debugger for the 6805 SBC rather
than a teletype-oriented command monitor. It assumes a VT100-compatible
terminal, cursor positioning, ANSI scrolling regions, and a terminal that
retains display state until the monitor redraws it.

The base monitor is intended to fit in the fixed monitor ROM. It should
provide the core debugger functions directly and avoid larger tools such
as a keyboard assembler or symbolic disassembler. If the hardware later
supports ROM bank switching, larger optional tools can live in an
extension bank without burdening the base monitor.

The normal display is 80 columns by 24 rows. The mockup below uses plain
ASCII separator lines; the implementation may use VT100 line drawing if it
is available.

```text
| SP 00F8  PC E000  A 00  X 00  FLAGS 111HINZC  STOPPED: RESET                 |
--------------------------------------------------------------------------------
| E000: 8E FF A6 00 B7 00 20 26 F9 20 03 00 00 00 00 00  ...... &. ......      |
| E010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E030: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E040: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E060: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E070: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E080: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E090: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0A0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0B0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0C0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0D0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0E0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
| E0F0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................      |
--------------------------------------------------------------------------------
|   E000: 8E FF       STOP                                                     |
|   E001: A6 00       LDA     #$00                                             |
| * E003: B7 00       STA     $00                                              |
|   E005: 20 F9       BRA     $E000                                            |
|   E007: 00          BRSET   0,$00,$E00A                                      |
```

The layout is vertically fixed:

- CPU state panel: one row.
- Memory panel: sixteen rows.
- Disassembly panel: five rows.
- Horizontal separator rows divide the panels.

TAB moves focus between editable panels and subpanels. Ctrl+L clears and
redraws the whole screen from the monitor's current state.

## Control Model

The monitor owns the display whenever the CPU is stopped. The state shown
on screen is the saved user-program state at the point where control
returned to the monitor.

User code can return to the monitor with `SWI`. The base monitor treats
`SWI` as a monitor-entry trap first: a plain `SWI` returns control to the
monitor and leaves the saved `PC` pointing after the `SWI` instruction. If
user code later needs a specific monitor service rather than a plain
return-to-monitor operation, the service ABI may use a command code in the
accumulator before executing `SWI`.

The monitor must support these execution controls:

- Go: resume execution from the saved `PC`.
- Single step: execute one instruction, regain control, refresh the CPU
  and disassembly panels, and leave the stopped state visible.
- Trace: repeatedly single-step with visual updates after each instruction
  until stopped by the user or by a configured stop condition.
- Return to monitor from user code through `SWI`.

## Monitor Entry and Breakpoints

All monitor entry paths should converge on one saved user-state block. The
saved block is the debugger's truth while the CPU is stopped; register
editing, breakpoint handling, single-step, trace, and go all operate by
reading or modifying that saved frame before returning with `RTI`.

Breakpoints should use the ASSIST05 `SWI` patching model for writable
memory:

- Keep a small fixed-size breakpoint table. Each active entry records the
  breakpoint address, the original opcode byte, and whether the breakpoint
  is currently armed in memory.
- When execution resumes, arm breakpoints by saving the original byte and
  writing opcode `$83`, the 6805 `SWI`, at each writable breakpoint
  address.
- Do not arm `SWI` breakpoints in ROM, unmapped memory, read-only memory,
  or memory-mapped I/O. ROM code can still be inspected with timer-driven
  single-step and trace.
- On every monitor entry, restore any armed breakpoint opcodes before
  showing or editing memory. The memory and disassembly panels should show
  the user's real bytes, not the temporary `SWI` patches.
- When `SWI` entry occurs, compare `PC - 1` from the stacked user frame
  against the armed breakpoint table. A match is a breakpoint hit because
  `SWI` advances `PC` before entering the monitor.
- For a breakpoint hit, restore the original opcode and reset the saved
  `PC` to the breakpoint address so the original instruction is still the
  next instruction to execute.
- Continuing from a breakpoint should execute the restored instruction once
  under timer-trace control, then re-arm breakpoints before normal
  execution continues. This avoids losing the breakpoint while still
  allowing the original instruction to run.
- A `SWI` that does not match an armed breakpoint is an explicit
  user-program return to the monitor.

## Single-Step and Trace Implementation

Single-step and trace should use the ASSIST05 timer-interrupt technique so
that ROM code can be stepped without modifying the instruction stream.
Breakpoint implementation may patch RAM with `SWI`, but stepping must not
depend on writing an opcode at the instruction being executed.

For each traced instruction, the monitor prepares the saved user stack
frame, arms the timer to interrupt immediately after execution resumes, and
uses `RTI` to return to the user instruction. The timer interrupt then
re-enters the monitor, captures the new user state, refreshes the display,
and either repeats for the next trace step or stops at the command/UI
level.

The trace path must preserve the user's interrupt-mask state. It may need
to temporarily clear the saved interrupt mask before `RTI` so the timer can
fire, then restore the user's intended mask when the timer interrupt brings
control back to the monitor.

The trace path also needs instruction-specific handling for operations that
affect monitor entry or interrupt masking:

- `SWI`: treat as an explicit return to the monitor rather than allowing it
  to confuse the timer-driven trace path.
- `SEI`: update the saved user condition-code state so the user's interrupt
  mask is set after the stepped instruction.
- `CLI`: update the saved user condition-code state so the user's interrupt
  mask is clear after the stepped instruction.

## CPU State Panel

The CPU state panel is a single row at the top of the screen. It shows the
saved state for the stopped user program.

Required fields:

- `SP` as a 16-bit hexadecimal value.
- `PC` as a 16-bit hexadecimal value.
- `A` as an 8-bit hexadecimal value.
- `X` as an 8-bit hexadecimal value.
- Condition-code bits shown as `111HINZC`, with each named flag displayed
  as its letter when set and as a space when clear.
- Stop reason, such as reset, SWI, single step, breakpoint, user break, or
  error.

The CPU panel should allow explicit editing of register and flag values so
that execution can resume from a modified state.

Register editing modifies the saved resume frame, not live CPU registers.
The next `RTI` into user code materializes those edited values. This keeps
all debugger state changes in one place and matches the way ASSIST05
treats register-change commands as edits to the saved user state.

## Memory Panel

The memory panel displays sixteen rows of memory. Each row shows the row
address, sixteen hexadecimal bytes, and the corresponding ASCII dump.

The hex bytes and ASCII dump are separate focusable subpanels. TAB moves
between them. The focused subpanel owns the edit cursor, but both subpanels
represent the same selected memory byte.

The memory panel must provide an explicit zero-page view command. This is
a named navigation operation that positions the memory panel at `$0000`
for direct inspection and editing of zero page memory, rather than merely
requiring the user to enter address zero manually.

Memory navigation requirements:

- Ctrl+P displays the previous 256-byte page.
- Ctrl+N displays the next 256-byte page.
- Arrow keys move the edit cursor within the visible memory view.
- Cursor movement past the top or bottom visible row scrolls the memory
  view by one row when possible.
- Cursor movement beyond the beginning or end of addressable memory does
  nothing.
- RETURN moves the cursor to the first byte of the next row, scrolling if
  needed.
- LF is equivalent to cursor down.
- The implementation should use an ANSI scrolling region for the memory
  panel when scrolling the visible memory rows.

Hex subpanel requirements:

- Editing accepts only `0`-`9`, `A`-`F`, and equivalent lowercase input.
- Editing one nibble advances the cursor to the next nibble.
- Cursor left and cursor right move across nibbles, not bytes.
- Cursor up and cursor down move to the first nibble of the same byte in
  the previous or next row.

ASCII subpanel requirements:

- Printable characters replace the byte at the cursor.
- Ctrl+V accepts the next typed character verbatim.
- Non-printable control characters are shown as reverse-video uppercase
  ASCII letters where possible; for example, byte `$03` is displayed as a
  reverse-video `C`.
- Cursor left and cursor right move across bytes.
- Cursor up and cursor down move to the same character position in the
  previous or next row.

Bulk memory operations required by the monitor:

- Fill an address range with a byte value.
- Load Motorola S-records from the terminal into memory.
- Dump an address range as Motorola S-records to the terminal.

S-record load and dump should be implemented as core terminal transfer
operations, not as extension-bank features. The ASSIST05 tape punch/load
commands are tape-era names for the same basic workflow: move a bounded
address range between the monitor and a host over the serial console.

## Disassembly Panel

The disassembly panel displays five decoded instructions. It is a
non-symbolic disassembler: it converts raw machine-code bytes to 6805
mnemonics with literal operands. It does not use labels, symbol tables,
expressions, comments, or source-level information.

The panel's default mode follows `PC`, with the current instruction shown
on the middle row.

Each disassembly row uses this form:

```text
* aaaa: xx xx xx    MNEM    OP,OP
```

Field requirements:

- `*` marks the row whose address matches the saved `PC`.
- `aaaa` is the instruction address.
- Machine-code bytes begin at column 8.
- The mnemonic begins at column 20.
- Operands begin at column 28.
- Numeric values are displayed in uppercase hexadecimal.

The disassembly panel must support an explicitly set starting address. This
starting address is independent of the memory panel address and does not
need to align with the memory panel's 16-byte rows.

The disassembly panel needs two display modes:

- Follow-PC mode: single step and trace update the panel so the current
  `PC` remains visible, normally on the middle row.
- Pinned mode: the disassembly start address remains fixed until the user
  changes it, even if stepping moves `PC` elsewhere.

Operand formatting requirements:

- Immediate operands display as `#$nn`.
- Direct operands display as `$nn`.
- Extended operands display as `$nnnn`.
- Indexed operands display with literal numeric offsets when present.
- Relative branch operands display the resolved absolute target address.
- Bit-test and bit-manipulation operands display the bit number and literal
  direct-page address.
- Invalid or unimplemented opcodes display as data, using `FCB $nn`, and
  consume one byte.
- The decoder must tolerate truncated instructions at the end of addressable
  memory and display the bytes that can be read.

## Console and State Implementation

Console input and output should be isolated behind small character I/O
routines, following ASSIST05's `CHRIN`/`CHROUT` style. Screen drawing,
S-record transfer, command entry, and diagnostics should call those
routines rather than touching UART registers directly.

Monitor RAM should use fixed-size tables and buffers. Dynamic allocation is
not appropriate for the base ROM. The saved CPU frame, breakpoint table,
trace counter, input buffer, current panel focus, and current memory and
disassembly addresses should have explicit storage with known upper bounds.

## Extension Bank Features

The base monitor does not include a keyboard assembler. If ROM bank
switching is added later, an extension bank may provide larger optional
tools that are useful but not essential to the core debugger.

Candidate extension-bank features:

- Keyboard assembler.
- Symbolic disassembly using a loaded or built-in symbol table.
- More capable search, compare, move, and checksum operations.
- Larger help screens or command reference text.

## Open Decisions

The following details still need concrete key bindings and command syntax:

- Breakpoint set, clear, list, display markers, and continue-from-breakpoint
  behavior.
- User break behavior while a program is running.
- Whether any non-return SWI monitor services are needed, and if so the
  exact command codes passed in the accumulator.
- Error handling for S-record checksum failures and partial loads.
- Behavior when editing ROM, I/O registers, unmapped memory, or memory
  with side effects.
- Exact timer setup values, timer-vector ownership, and whether trace is
  allowed while user code also depends on timer interrupts.
- Where monitor RAM state, saved CPU state, input buffers, and breakpoints
  reside.
