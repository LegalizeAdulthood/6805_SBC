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

The renderer should exploit ANSI terminal behavior to minimize output. If
an escape sequence has already erased, cleared, scrolled, positioned, or
restyled part of the display, the monitor should not emit redundant spaces
or redraw unchanged text merely to maintain a rectangular byte stream.
Tests should distinguish the final screen state from the exact serial byte
sequence required to produce it.

Panel borders are decorative, not functional. The layout should reserve
the vertical and horizontal spacing needed for bordered panel tiles from
the start, but the functional implementation slices should render panel
content without depending on border glyphs. Drawing borders around the
panels is deferred to the final polish slice.

Monitor assembly sources use lowercase for directives, opcodes, operands,
labels, and symbols. Hexadecimal operands also use lowercase hex digits
where letters appear. User-facing display strings may use whatever casing
the screen text requires.

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
- Reserved horizontal and vertical spacing divides the panel tiles and
  leaves room for decorative borders.

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

## Implementation Test Plan

Implementation should use strict TDD. Each slice starts by adding one
failing test, verifying that it fails for the expected reason, then adding
the smallest implementation that makes the test pass. After the new test
passes, all existing tests must still pass. Every slice should leave a
working, if minimal, monitor ROM that can be built and validated.

ROM space is tight. Each implementation slice should aggressively factor
out duplication as it is introduced, especially repeated formatting,
emission, dispatch, and table-walking code. Clear code is still required,
but shared ROM routines and compact data-driven paths are preferred when
they keep behavior testable and reduce generated monitor bytes. Monitor
code should optimize for binary size over speed.

Terminal output should also be size-conscious. ANSI escape sequences
should aggressively exploit default parameter values when they produce the
same screen state, such as using `ESC[J` instead of `ESC[0J` or cursor
home plus erase-to-end instead of longer clear-screen forms when that
shares more code. Prefer reusable control-sequence helpers over storing
one-off escape strings. Regular control characters such as BS, LF, and CR
should be used for cursor positioning when that is simpler or shorter than
an ANSI escape sequence.

A slice is complete only when its stated end state is true. Slice numbers
are stable progress markers; when a completed slice is removed from this
plan, do not renumber the remaining slice headings.

The `m6805sbc` MAME emulator is the system validation target. Unit-style
tests may inspect generated files or helper-tool output, but behavior that
depends on CPU execution, vectors, interrupts, serial I/O, or display state
should be validated in MAME.

Each MAME-based test case must be independent. A test must stage its own
temporary MAME data directory, including any ROM, CFG, NVRAM, input, or
output files it needs, and must invoke the emulator through an absolute
path with the process current directory set to the staged data directory.
Tests must not depend on shared mutable files in the developer's normal
MAME directory or on any caller working directory.

Planned implementation slices follow in dependency order.

The disassembler slices are organized by addressing mode to keep tests and
reviews focused. The implementation should not mirror that structure with
a long opcode compare chain. To keep ROM size low, decode using the 6805
opcode bit organization wherever practical: mask and shift opcode fields,
share operand emitters, use compact mnemonic tables for the irregular
cases, and fall through to `FCB $nn` for gaps or invalid opcodes.

### 9.3. Disassembler Relative Instructions

Failing test: the disassembler fixture is extended with every relative
branch row in `TASM05.TAB`, including `BSR`, and fails until each row
decodes to the expected text.

End state: all one-byte relative offsets decode to resolved absolute target
addresses using uppercase hexadecimal. The fixture includes at least one
forward branch, one backward branch, and one target crossing a page
boundary. Relative rows emit no labels or symbolic operands.

### 9.4. Disassembler Immediate Instructions

Failing test: the disassembler fixture is extended with every immediate
operand row in `TASM05.TAB`, and fails until each row decodes to the
expected text.

End state: all immediate arithmetic, logic, load, compare, and indexed
compare forms decode with operands formatted as `#$nn`. Fixture rows cover
each immediate mnemonic accepted by `TASM05.TAB`, including opcodes shared
by aliases such as `CMPX` and `CPX`; shared opcodes use the monitor's
canonical mnemonic.

### 9.5. Disassembler Direct and Extended Instructions

Failing test: the disassembler fixture is extended with every direct and
extended operand row in `TASM05.TAB`, and fails until each row decodes to
the expected text.

End state: direct operands display as `$nn`, extended operands display as
`$nnnn`, and all direct/extended arithmetic, logic, load/store, compare,
unary memory, `JMP`, and `JSR` forms decode with the expected byte count.
Rows using `MZERO` table behavior have fixtures for both short direct-page
operands and full extended operands where both encodings are valid machine
code.

### 9.6. Disassembler Indexed Instructions

Failing test: the disassembler fixture is extended with every indexed
operand row in `TASM05.TAB`, and fails until each row decodes to the
expected text.

End state: no-offset indexed operands display as `,X`. Offset-indexed
operands display the literal numeric offset and `,X`, using `$nn,X` for
one-byte offsets and `$nnnn,X` where the opcode encoding carries a full
extended address. Indexed arithmetic, logic, load/store, compare, unary
memory, `JMP`, and `JSR` forms decode with the expected byte count and
canonical mnemonic.

### 9.7. Disassembler Bit Operations

Failing test: the disassembler fixture is extended with every bit-test and
bit-manipulation row in `TASM05.TAB`, and fails until each row decodes to
the expected text.

End state: `BSET` and `BCLR` rows display the bit number and literal
direct-page address. `BRSET` and `BRCLR` rows display the bit number,
literal direct-page address, and resolved absolute branch target. Fixture
rows cover at least bit 0, bit 7, a forward branch, and a backward branch.

### 9.8. Disassembler Coverage and Truncation

Failing test: a fixture coverage audit fails until every opcode row in
`TASM05.TAB` is represented by at least one disassembler fixture, and
truncated end-of-memory cases fail until the decoder handles them without
reading beyond addressable memory.

End state: the disassembler fixture covers every opcode row in
`TASM05.TAB`, plus at least one invalid opcode. The coverage check names
any missing table row by mnemonic, operand form, and opcode byte. Truncated
instructions near `$FFFF` display only bytes that can be read and still
produce a deterministic `FCB $nn` fallback or decoded mnemonic text. The
decoder emits no labels, symbol names, expressions, comments, or
source-level information in any fixture row.

### 10. SWI Monitor Entry

Failing test: a MAME SWI-entry test runs a fixed RAM program ending in
`SWI` and fails until the monitor captures the expected saved frame.

End state: the RAM program loads known values into `A` and `X`, sets a
known condition-code state, and executes `SWI` at label `user_swi`.
`swi_entry` records stop reason `STOP_SWI`, saves `A`, `X`, condition
codes, and saves `PC=user_swi+1`, then enters `monitor_idle`.

### 11. Timer Single-Step

Failing test: a MAME timer-step test computes a checksum of the ROM test
code, performs one monitor step, and fails until `PC` advances by one
instruction with the checksum unchanged.

End state: starting at ROM label `step_rom_start`, one step temporarily
uses the timer RAM vector to enter the monitor's step handler, executes the
instruction at the saved `PC`, returns through the timer interrupt, saves
the new `PC`, restores the previous timer RAM vector value, preserves the
user's intended interrupt-mask state, records stop reason `STOP_STEP`, and
leaves every byte in ROM unchanged.

### 12. RAM Breakpoints

Failing test: a MAME breakpoint test sets one breakpoint in a fixed RAM
program and fails until breakpoint hit and continue behavior match the
contract below.

End state: arming the breakpoint stores opcode `$83` at the breakpoint
address and records the original opcode in the breakpoint table. When the
program hits the breakpoint, the monitor restores the original opcode
before drawing or exposing memory, records stop reason `STOP_BREAK`, and
saves `PC` equal to the breakpoint address. Continuing executes the
restored instruction exactly once under timer-step control, then re-arms
the breakpoint before normal execution resumes.

### 13. Go and Trace UI Integration

Failing test: a command-dispatch test invokes internal commands `GO`,
`STEP`, and `TRACE_COUNT` and fails until each command updates execution
state and panel state as specified.

End state: `GO` resumes from the saved `PC` and stops only at a monitor
entry condition. `STEP` executes exactly one instruction and refreshes the
CPU and disassembly panel state. `TRACE_COUNT` with count `3` performs
three single steps, refreshing CPU and disassembly state after each step,
then returns to `monitor_idle`.

### 14. S-Record Load and Dump

Failing test: an S-record test feeds one fixed valid record and one fixed
invalid record, then fails until load and dump behavior is exact.

End state: loading `S107011001020304DD` writes bytes `$01,$02,$03,$04` to
`$0110`-`$0113`. Loading the same record with the checksum changed by one
bit reports a checksum error and leaves memory unchanged. Dumping
`$0110`-`$0113` emits exactly `S107011001020304DD\r\nS9030000FC\r\n`.

### 15. Full-Screen Polish Pass

Failing test: a MAME screen-snapshot test fails until the final terminal
screen state after reset matches the checked-in expected 80x24 snapshot for
a fixed machine state.

End state: reset uses ANSI clear, cursor positioning, and targeted output
to produce the expected 24-row by 80-column screen state. The emitted
serial byte stream is not required to contain 80 printable characters for
each row when ANSI clearing or positioning already supplies the intended
blank cells. The snapshot includes the CPU state panel, sixteen memory
rows, five disassembly rows, and reserved panel spacing in the documented
positions. This slice adds decorative borders around the panels in the
reserved spacing without changing any monitor behavior. Follow-PC and
pinned disassembly modes both have snapshot tests with fixed `PC`, fixed
memory bytes, and fixed selected panel state.
