# Visual Monitor

## Overview

The monitor ROM is a full-screen visual debugger for the 6805 SBC rather
than a teletype-oriented command monitor. It assumes a VT100-compatible
terminal, cursor positioning, ANSI scrolling regions, and a terminal that
retains display state until the monitor redraws it.

The base monitor is intended to fit in the fixed monitor ROM. It should
provide the core debugger functions directly, including non-symbolic
disassembly and keyboard assembly, while avoiding larger symbolic tools
such as label-aware assembly or symbolic disassembly. If the hardware later
supports ROM bank switching, larger optional tools can live in an extension
bank without burdening the base monitor.

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

## Assembly Style and Resource Rules

These rules apply to all subsequent monitor implementation. They are not
only notes about EVSBUG12; EVSBUG12 is the worked example that exposed the
style and resource constraints we want for the monitor.

Monitor assembly sources use lowercase for directives, opcodes, operands,
labels, and symbols. Hexadecimal operands also use lowercase hex digits
where letters appear. User-facing display strings may use whatever casing
the screen text requires.

Use `.module` to define each global entry point or closely related group of
global entry points. A module owns the local labels and local equates used
only to implement that global entry point. Module-local names should not
leak into unrelated code.

Identifiers should be terse without becoming cryptic. Assembly idioms such
as `msg` for message, `cmd` for command, `buf` for buffer, `ptr` for
pointer, `idx` for index, `cnt` for count, `len` for length, `tmp` for
temporary, `addr` for address, `vec` for vector, `op` for opcode, and
`hi`/`lo` for byte halves are preferred over long-form words.

When abbreviating, start by dropping vowels while keeping enough consonants
to preserve recognition, and avoid duplicated consonants. Prefer
established short forms such as `msg` and `cmd` over mechanical spellings
such as `mssg` or `cmmd`.

Use module scope to remove repetitive prefixes instead of encoding the
whole subsystem name into every local identifier. Where an identifier is
declared, use the running-commentary column to give the long-form meaning
when the abbreviation is not completely obvious.

Identifier length penalties are explicit:

- `<= 8` characters: preferred.
- `9-16` characters: allowed only when the extra length clearly improves
  review; otherwise shorten the identifier.
- `> 16` characters: aggressively penalized. Replace with a shorter
  module-local name plus a declaration comment unless the name is an
  explicitly justified exported entry point, hardware register, persistent
  monitor state, or shared data table.

Labels should be preceded by a blank line, unless the previous line is a
module operation; in that case, the blank line should precede the module
operation. A blank line should separate module-local equates from the
global entry point for the module.

Comments that describe implementation details should form a running
commentary starting in one-based column 41 where practical. Comments should
explain intent, lifetime, hardware meaning, table encoding, or non-obvious
control flow rather than narrating self-evident instructions.

The monitor is constrained by a 4K ROM budget. Optimize for binary size
over speed unless a specific behavior requires otherwise. Factor out
duplication aggressively, prefer shared routines and shared metadata, and
avoid wider encodings that only make the source look simpler.

Data tables should be encoded as tightly as the implementation can
reasonably support. Prefer shared base tables, high-bit terminators,
indexed metadata, symbolic constants, and packed fields when they reduce
ROM size while remaining reviewable.

RAM is more precious than ROM. Separate permanent monitor state from
scratch storage, and reuse scratch bytes for routines whose lifetimes do
not overlap. Do not allocate a permanent RAM byte for a temporary value
unless that value must survive across monitor operations.

New fixed monitor state must always precede the scratchpad area. The
scratchpad must remain one contiguous region after fixed state and thunks;
do not carve persistent state bytes out of the scratchpad, append fixed
state after it, or split scratch into discontiguous islands. If a new
persistent byte is required, move the scratchpad start upward and update
the RAM map and audits in the same slice.

Zero-page RAM is more precious than ordinary RAM because it enables shorter
direct-addressed instructions. Use zero page deliberately for hardware,
persistent debugger state, generated-code thunks, or scratch values whose
direct addressing saves enough ROM to justify the allocation.

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
- Invalid or unimplemented opcodes display as data, using `fcb $nn`, and
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

The base monitor includes the non-symbolic disassembler and keyboard
assembler. Both should directly carry over the compact mnemonic,
operand-class, opcode construction, and parser implementation recovered in
the reconstituted EVSBUG12 source. EVSBUG12's assembler has already been
micro-optimized to fit in an 8KB debug ROM; treat that implementation as
the size-tested source, not as loose inspiration for a replacement.
If ROM bank switching is added later, an extension bank may provide larger
optional tools that are useful but not essential to the core debugger.

Candidate extension-bank features:

- Symbolic disassembly using a loaded or built-in symbol table.
- Symbolic assembly using labels, expressions, or a loaded symbol table.
- More capable search, compare, move, and checksum operations.
- Larger help screens or command reference text.

## Open Decisions

The following details still need concrete key bindings and command syntax:

- Breakpoint set, clear, list, display markers, and continue-from-breakpoint
  behavior.
- User break behavior while a program is running.
- Keyboard assembler panel entry and full-screen editing affordances around
  the EVSBUG12 assembler core.
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

End-to-end tests that need to exercise monitor ROM services from user code
should assemble a small RAM-resident test program rather than adding
test-only entry points or direct Lua calls into production ROM code. The
build first assembles `monitor.asm` to produce `monitor.sym`, then a helper
generates a whitelisted include file containing only the global ROM entry
points that the test program is allowed to call. The test assembly includes
that generated file, is assembled by TASM into a binary, and is loaded by
the MAME Lua script into low RAM.

The Lua side stages the ROM image, fixture bytes, and RAM test program,
sets the monitor state needed by the test, masks interrupts if the test is
not validating interrupt behavior, gives the CPU a safe stack, and starts
execution by setting the program counter to the RAM test code. Test code
must leave its verdict in RAM, such as a done/pass byte, and must keep its
own loop counters or persistent state in RAM rather than assuming monitor
ROM calls preserve A or X. Lua may inspect RAM for the verdict and may
install ACIA read/write taps to make the serial port observable, but the
behavior under test should still flow through the CPU, memory map, and ROM
entry points in the same shape user code would use.

Planned implementation slices follow in dependency order.

The current `firmware/monitor/monitor.asm` is still structured like an
early prototype: long global equate names, no module scopes, permanent
zero-page allocations for values that are often temporary, sparse running
commentary, and simple data tables that favor readability over ROM density.
Before adding more monitor behavior, refactor the source to obey the
top-level assembly style and resource rules.

The disassembler and keyboard assembler slices should now directly take the
proven EVSBUG12 disassembler and assembler from the reconstituted assembly
source, then adapt only their I/O boundaries to the monitor's full-screen
presentation, command-input model, and memory abstraction. This is not a
from-scratch EVSBUG12-inspired variation, and it is not a TASM-compatible
interactive assembler. TASM remains the host assembler used to build ROMs
and test helper programs; it is not the behavioral authority for the
monitor's inline assembler syntax. After the integration, keep adding
monitor-context coverage until every EVSBUG12 assembler opcode and
addressing mode is validated. Disassembled source text follows local
assembly style: mnemonics, directives, pseudo-ops, operands, labels, and
symbols are lower-case, while hexadecimal digits remain uppercase.
Any partial or prototype assembler implementation already present in
`monitor.asm` must be ripped out rather than incrementally grown; the
replacement is the EVSBUG12 assembler core adapted at the I/O and monitor
integration boundaries.

Use `firmware/evsbug12/evsbug12.asm` as the source-level reference for the
compact decoder, mnemonic metadata, assembler opcode construction paths, and
small monitor support routines. The source has been reconstituted with
labels, modules, symbolic equates, and named data tables; prefer those names
over raw ROM addresses when planning or porting behavior.

Useful EVSBUG12 source artifacts include:

- `decode_inst`: opcode classifier and control-flow decoder. It uses high
  nibble and low nibble structure first, falls back to small family tables
  only where needed, records operand length in `op_len`, flags operand
  details in `decode_flags`, and computes both `inst_next` and
  `inst_target_*` for branches, jumps, subroutine calls, and return-like
  instructions.
- `disassemble_line`: one-line disassembly renderer. It decodes into
  `line_buf` first, then writes the completed line. Its column constants and
  output shape are teletype-oriented, but the decode-to-buffer structure is
  the model for adapting output to the visual monitor panel.
- `load_line_addr`, `app_hex_byte`, `app_hex_word`, `app_char`, and related
  helpers: reusable text-buffer append routines shared by the disassembler
  and display formatting.
- `opcode_30_7f_index`, `opcode_a0_af_index`, `branch_bit_index`, and
  `opcode_80_9f_index`: compact irregular-family lookup tables used after
  the primary bit-structured opcode classification.
- `mnemonics`: compressed mnemonic text using `msg_end` as the high-bit
  token terminator.
- `mnemonic_modes`: parallel mnemonic metadata. The high nibble carries the
  parser or operand class and the low nibble carries the mnemonic character
  position/count information.
- `opcode_table`: assembler-side base opcode table, using named `op_*`
  equates rather than anonymous bytes.
- `asm_cmd`: keyboard assembler parser and opcode construction path. Port
  this code directly and preserve its compact parser/data structure unless
  the monitor I/O boundary requires a change. It reuses `mnemonics`,
  `mnemonic_modes`, `opcode_table`, `parse_hex_word`, and the memory write
  path, then redisassembles the newly written instruction for feedback.
- `cmd_tokens`, `cmd_handlers`, and `cmd_loop`: high-bit-terminated command
  token matching and compact command dispatch.
- `message_text`, `help_intro`, `help_breakpoint`, `help_go_load_md`,
  `help_modify_nobr_proceed`, and `help_register_trace`: examples of
  reviewable ASCII data regions split by purpose rather than left as
  anonymous bytes.
- `read_memory_byte`, `write_memory_byte`, and `cmd_thunk`: mapped user
  memory access through a generated STA/LDA thunk.
- `arm_breaks`, `arm_break_range`, `restore_breaks`, and
  `restore_break_range`: fixed-slot breakpoint table handling, including
  separate user, step, and temporary breakpoint slots.
- `go_cmd`, `proceed_cmd`, `trace_cmd`, `swi_handler`, and `resume_user`:
  execution-control reference code. EVSBUG12 uses decoded next/target
  addresses plus temporary breakpoints for step and trace; the visual
  monitor still plans to use timer-driven stepping for ROM safety, but these
  routines are useful references for breakpoint bookkeeping, SWI stack
  adjustment, and continue/proceed state.
- `load_cmd`: S-record load implementation for `LOAD T`, including S1/S9
  handling, checksum accumulation, and byte-at-a-time writes through the
  memory access abstraction.
- `register_fields`, `condition_bits`, `display_regs`, `select_reg_addr`,
  and `display_cc`: compact saved-register display/edit support.
- `cmd_tokens`, `message_text`, and the help text tables show the preferred
  source style for ROM data: named labels, visible ASCII, and symbolic
  constants such as `NUL`, `CR`, `LF`, and `msg_end`.

Directly carry over EVSBUG12's disassembler and assembler structure, data
encoding, shared metadata, and size-oriented control flow, adapting only the
surrounding I/O and monitor integration where needed:

- Classify opcodes by high nibble and low nibble first, then use tiny
  family tables only for irregular holes or mnemonic selection.
- Decode to a small text buffer, then copy that buffer to the active output
  path. The monitor panel renderer may use different column constants than
  EVSBUG12's teletype line, but it should keep the same staged-output shape.
- Share one operand-format path per addressing mode and one invalid-opcode
  path that emits `fcb $nn`.
- Treat branch operands as resolved target addresses in the display, not as
  raw offsets.
- Emit canonical mnemonics for aliases; for example, display carry
  branches as `bcc` and `bcs` rather than preserving source aliases.
- Use EVSBUG12's high-bit string terminator, prefix/suffix mnemonic
  compression, and metadata-carries-operand-class trick when they save ROM.
- Prefer shared metadata for disassembly and assembly so opcode coverage,
  operand classification, and alias handling do not drift between the two
  tools.
- Preserve EVSBUG12 assembler syntax and error behavior except where the
  monitor's full-screen I/O wrapper explicitly adds an outer interaction.
  Do not use TASM operand syntax acceptance as the inline assembler
  standard.
- Use named opcode equates and named data tables when lifting EVSBUG12
  logic. The monitor source should be compact, but it should not return to
  anonymous byte blobs now that the EVSBUG12 source has reviewable labels.
- Treat EVSBUG12's temporary-breakpoint trace mechanism as reference
  material for control-flow edge cases. Do not replace the monitor's
  ASSIST05-style timer-step requirement with RAM/ROM patching.

## Implementation Slices

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

### 15.1. Manual CRT Raw-Socket Smoke Test

Manual test: launch `m6805sbc` from an absolute path with the monitor ROM
staged in an isolated MAME data directory, connect the emulated RS-232
path to a TCP raw socket, and connect Van Dyke CRT or SecureCRT to that
socket using a raw TCP session. The manual notes for this slice must record
the exact MAME command line, CRT protocol/session settings, host, port, and
any required startup ordering, such as whether CRT connects before or after
MAME starts.

End state: a reset observed through CRT clears the terminal and draws the
same monitor screen state validated by the automated snapshot tests:
`MONITOR 1.0` appears in the upper-right version field, CPU state appears
in its panel, memory appears in the 16-byte hex-plus-ASCII format, and the
disassembly panel is populated from its selected start address. CRT should
not show streams of unnecessary blank-filled 80-column rows; ANSI clear and
cursor-positioning sequences should produce the final screen state. Manual
input through CRT should exercise the real ACIA receive path: TAB changes
the active panel, memory cursor movement/editing behaves like the MAME
keyboard tests, simple assembler entries produce the same bytes/status as
the automated assembler fixtures, and execution commands visibly refresh
CPU and disassembly state after monitor re-entry.
