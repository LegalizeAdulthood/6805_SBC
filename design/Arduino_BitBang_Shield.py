from skidl import *

# Create the Arduino bitbang shield for 6805 SBC interface
# Direct 5V to 5V interface - no level shifting needed
# Includes address latch for proper demultiplexing of 6805's multiplexed B bus
# MC146805E2 in 40-pin DIP package
# Arduino provides manual clock on OSC1 for single-stepping
# Arduino can directly bit-bang all digital I/O pins (PORT A, PORT B)

# Define the circuit
set_default_tool(KICAD)

# Arduino headers (connectors to Arduino board)
arduino_d0_d7 = Bus('D', 8, Pin)  # Digital pins 0-7 (Data bus)
arduino_d8_d13 = Bus('D', 6, Pin) # Digital pins 8-13 (Upper address bits + clock)
arduino_a0_a5 = Bus('A', 6, Pin)  # Analog pins A0-A5 (Lower address bits)
arduino_5v = Net('5V')
arduino_gnd = Net('GND')

# MC146805E2 interface signals - ACTUAL PINOUT
# Multiplexed Address/Data bus (B0-B7)
sbc_b_bus = Bus('SBC_B', 8, Pin)         # B0-B7: Multiplexed low addr (A7-A0) / data (D7-D0)

# High address bits (A12-A8)
sbc_addr_high = Bus('SBC_A_HIGH', 5, Pin) # A12-A8: High address bits (5 bits only!)

# PORT A (PA7-PA0) - directly controllable via shift registers
sbc_porta = Bus('SBC_PA', 8, Pin)         # PA7-PA0: General purpose I/O port

# PORT B (PB7-PB0) - directly controllable via shift registers
sbc_portb = Bus('SBC_PB', 8, Pin)         # PB7-PB0: General purpose I/O port

# Control signals
sbc_as = Net('SBC_AS')                    # AS: Address Strobe
sbc_rw = Net('SBC_RW')                    # R/W: Read/Write (HIGH=Read, LOW=Write)
sbc_ds = Net('SBC_DS')                    # DS: Data Strobe
sbc_li = Net('SBC_LI')                    # LI: Load Instruction
sbc_reset = Net('SBC_nRESET')             # RESET (active low)
sbc_irq = Net('SBC_nIRQ')                 # IRQ (active low)

# Timer output
sbc_timer = Net('SBC_TIMER')              # TIMER: Timer output

# Oscillator - OSC1 driven by Arduino for manual clocking
sbc_osc1 = Net('SBC_OSC1')                # OSC1: Clock input (driven by Arduino)

# Power (supplied TO the 6805 from Arduino)
sbc_5v = Net('SBC_VDD')
sbc_gnd = Net('SBC_VSS')

# Internal nets for demultiplexed address bus
addr_low_latched = Bus('ADDR_LOW', 8, Pin)  # Latched low address byte (A7-A0)

# Shift register control signals (for PORT A and PORT B bit-banging)
sr_data = Net('SR_DATA')       # Serial data to shift registers
sr_clock = Net('SR_CLOCK')     # Clock for shift registers
sr_latch = Net('SR_LATCH')     # Latch signal for output registers
sr_oe = Net('SR_OE')           # Output enable for shift registers

# Power connections - direct connection, same voltage
sbc_5v += arduino_5v
sbc_gnd += arduino_gnd

# 40-pin DIP socket for MC146805E2
cpu_socket = Part('Connector', 'DIP-40_W15.24mm_Socket', 
                  footprint='Package_DIP:DIP-40_W15.24mm_Socket')

# Address latch: 74HC573 (or 74LS373)
# Captures low address byte from B0-B7 when AS is asserted
addr_latch = Part('74xx', '74HC573', footprint='Package_SO:SOIC-20W_7.5x12.8mm_P1.27mm')

# Connect latch power
addr_latch['VCC'] += sbc_5v
addr_latch['GND'] += sbc_gnd

# Connect latch enable (LE) to Address Strobe (AS)
# When AS is high, latch is transparent (address passes through)
# When AS goes low, address is latched
addr_latch['LE'] += sbc_as

# Output Enable (OE) - always enabled (active low)
addr_latch['OE'] += sbc_gnd

# Connect multiplexed B bus to latch inputs
for i in range(8):
    addr_latch[f'D{i+1}'] += sbc_b_bus[i]
    
# Connect latch outputs to internal latched address bus
for i in range(8):
    addr_latch[f'Q{i+1}'] += addr_low_latched[i]

# Bidirectional buffers for data bus (74HC245)
# These allow the Arduino to drive or read the multiplexed B bus
data_buffer = Part('74xx', '74HC245', footprint='Package_SO:SOIC-20W_7.5x12.8mm_P1.27mm')

# Connect buffer power
data_buffer['VCC'] += sbc_5v
data_buffer['GND'] += sbc_gnd

# Direction control: Arduino controls whether it's reading or writing
# DIR signal from Arduino (LOW = B->A, HIGH = A->B)
buffer_dir = Net('BUF_DIR')
data_buffer['DIR'] += buffer_dir

# Output Enable (active low) - Arduino controls when buffer is active
buffer_oe = Net('BUF_OE')
data_buffer['OE'] += buffer_oe

# Connect Arduino data pins to buffer A side
for i in range(8):
    data_buffer[f'A{i+1}'] += arduino_d0_d7[i]

# Connect 6805 B bus to buffer B side
for i in range(8):
    data_buffer[f'B{i+1}'] += sbc_b_bus[i]

# ============================================================================
# PORT A bit-banging capability using 74HC595 shift registers
# Two cascaded shift registers for 16 bits (we only use 8 for PORT A)
# This allows Arduino to directly control all PORT A pins
# ============================================================================

porta_shiftreg = Part('74xx', '74HC595', footprint='Package_SO:SOIC-16_3.9x9.9mm_P1.27mm')

# Connect shift register power
porta_shiftreg['VCC'] += sbc_5v
porta_shiftreg['GND'] += sbc_gnd

# Connect shift register control signals
porta_shiftreg['SER'] += sr_data          # Serial data input
porta_shiftreg['SRCLK'] += sr_clock       # Shift register clock
porta_shiftreg['RCLK'] += sr_latch        # Storage register clock (latch)
porta_shiftreg['OE'] += sr_oe             # Output enable (active low)
porta_shiftreg['SRCLR'] += sbc_5v         # Shift register clear (active low, tied high)

# Connect PORT A outputs from shift register
for i in range(8):
    porta_shiftreg[f'Q{i}'] += sbc_porta[i]

# ============================================================================
# PORT B bit-banging capability using 74HC595 shift registers
# Cascaded from PORT A shift register
# ============================================================================

portb_shiftreg = Part('74xx', '74HC595', footprint='Package_SO:SOIC-16_3.9x9.9mm_P1.27mm')

# Connect shift register power
portb_shiftreg['VCC'] += sbc_5v
portb_shiftreg['GND'] += sbc_gnd

# Cascade from PORT A shift register
portb_shiftreg['SER'] += porta_shiftreg['QH_prime']  # Serial data from PORT A
portb_shiftreg['SRCLK'] += sr_clock       # Shift register clock
portb_shiftreg['RCLK'] += sr_latch        # Storage register clock (latch)
portb_shiftreg['OE'] += sr_oe             # Output enable (active low)
portb_shiftreg['SRCLR'] += sbc_5v         # Shift register clear (active low, tied high)

# Connect PORT B outputs from shift register
for i in range(8):
    portb_shiftreg[f'Q{i}'] += sbc_portb[i]

# ============================================================================
# Arduino connections
# ============================================================================

# Low address byte comes from latched address (A7-A0)
for i in range(6):
    arduino_a0_a5[i] += addr_low_latched[i]

# Upper 2 bits of low address byte (A7-A6)
arduino_d8_d13[0] += addr_low_latched[6]
arduino_d8_d13[1] += addr_low_latched[7]

# High address bits (A12-A8) - only 5 bits!
# D9, D10, D11, D12, D13 = A8, A9, A10, A11, A12
for i in range(5):
    if i + 2 < 6:  # D9-D13 (indices 2-5 in arduino_d8_d13)
        arduino_d8_d13[i + 2] += sbc_addr_high[i]

# Control signal assignments
arduino_d2 = Net('ARDUINO_D2')
arduino_d3 = Net('ARDUINO_D3')
arduino_d4 = Net('ARDUINO_D4')
arduino_d5 = Net('ARDUINO_D5')
arduino_d6 = Net('ARDUINO_D6')
arduino_d7 = Net('ARDUINO_D7')

buffer_dir += arduino_d2      # D2 controls buffer direction
buffer_oe += arduino_d3       # D3 controls buffer output enable
sbc_as += arduino_d4          # D4 monitors Address Strobe
sbc_ds += arduino_d5          # D5 monitors Data Strobe
sbc_rw += arduino_d6          # D6 monitors Read/Write
sbc_reset += arduino_d7       # D7 for Reset control

# Shift register control from Arduino
# These need to be connected to available Arduino pins
# (You may need to use I2C expander or reassign pins)
arduino_sr_data = Net('ARDUINO_SR_DATA')
arduino_sr_clock = Net('ARDUINO_SR_CLOCK')
arduino_sr_latch = Net('ARDUINO_SR_LATCH')
arduino_sr_oe = Net('ARDUINO_SR_OE')

sr_data += arduino_sr_data
sr_clock += arduino_sr_clock
sr_latch += arduino_sr_latch
sr_oe += arduino_sr_oe

# Arduino provides manual clock on OSC1 for single-stepping
arduino_clk = Net('ARDUINO_CLK')
sbc_osc1 += arduino_clk

# Series resistors for bus protection (on Arduino side of buffer)
for i in range(8):
    r = Part('Device', 'R', value='220', 
             footprint='Resistor_SMD:R_0805_2012Metric')
    r[1] += arduino_d0_d7[i]
    r[2] += data_buffer[f'A{i+1}']

# Decoupling capacitors for clean power supply
for i in range(4):
    cap = Part('Device', 'C', value='100nF', 
               footprint='Capacitor_SMD:C_0805_2012Metric')
    cap[1] += arduino_5v
    cap[2] += arduino_gnd

# Bulk capacitor
bulk_cap = Part('Device', 'CP', value='47uF', 
                footprint='Capacitor_SMD:CP_Elec_5x5.3')
bulk_cap[1] += arduino_5v
bulk_cap[2] += arduino_gnd

# Decoupling caps for ICs
for ic in [addr_latch, data_buffer, porta_shiftreg, portb_shiftreg]:
    cap = Part('Device', 'C', value='100nF', 
               footprint='Capacitor_SMD:C_0805_2012Metric')
    cap[1] += ic['VCC']
    cap[2] += ic['GND']

# Connect CPU socket pins to nets
# MC146805E2 40-pin DIP pinout:
cpu_pin_map = {
    1: sbc_gnd,          # VSS
    2: sbc_porta[0],     # PA0
    3: sbc_porta[1],     # PA1
    4: sbc_porta[2],     # PA2
    5: sbc_porta[3],     # PA3
    6: sbc_porta[4],     # PA4
    7: sbc_porta[5],     # PA5
    8: sbc_porta[6],     # PA6
    9: sbc_porta[7],     # PA7
    10: sbc_portb[0],    # PB0
    11: sbc_portb[1],    # PB1
    12: sbc_portb[2],    # PB2
    13: sbc_portb[3],    # PB3
    14: sbc_portb[4],    # PB4
    15: sbc_portb[5],    # PB5
    16: sbc_portb[6],    # PB6
    17: sbc_portb[7],    # PB7
    18: sbc_b_bus[0],    # B0
    19: sbc_b_bus[1],    # B1
    20: sbc_b_bus[2],    # B2
    21: sbc_b_bus[3],    # B3
    22: sbc_b_bus[4],    # B4
    23: sbc_b_bus[5],    # B5
    24: sbc_b_bus[6],    # B6
    25: sbc_b_bus[7],    # B7
    26: sbc_addr_high[0], # A8
    27: sbc_addr_high[1], # A9
    28: sbc_addr_high[2], # A10
    29: sbc_addr_high[3], # A11
    30: sbc_addr_high[4], # A12
    31: sbc_as,          # AS
    32: sbc_rw,          # R/W
    33: sbc_ds,          # DS
    34: sbc_li,          # LI
    35: sbc_irq,         # IRQ
    36: sbc_timer,       # TIMER
    37: sbc_reset,       # RESET
    38: sbc_osc1,        # OSC1 (clock input from Arduino)
    39: Net('NC'),       # OSC2 (not connected - internal oscillator output)
    40: sbc_5v,          # VDD
}

for pin_num, net in cpu_pin_map.items():
    cpu_socket[pin_num] += net

# Test points connector for monitoring/debugging
# Using 2x25 (50-pin) header to expose all signals
test_connector = Part('Connector_Generic', 'Conn_02x25_Odd_Even', 
                      footprint='Connector_PinHeader_2.54mm:PinHeader_2x25_P2.54mm_Vertical')

# Pin mapping for test connector - expose all signals
test_pin_map = [
    # Power
    (1, sbc_gnd),           # VSS (Ground)
    (2, sbc_5v),            # VDD (+5V)
    
    # Multiplexed Address/Data bus (B0-B7)
    (3, sbc_b_bus[0]),      # B0
    (4, sbc_b_bus[1]),      # B1
    (5, sbc_b_bus[2]),      # B2
    (6, sbc_b_bus[3]),      # B3
    (7, sbc_b_bus[4]),      # B4
    (8, sbc_b_bus[5]),      # B5
    (9, sbc_b_bus[6]),      # B6
    (10, sbc_b_bus[7]),     # B7
    
    # High address bits (A12-A8) - only 5 bits
    (11, sbc_addr_high[0]), # A8
    (12, sbc_addr_high[1]), # A9
    (13, sbc_addr_high[2]), # A10
    (14, sbc_addr_high[3]), # A11
    (15, sbc_addr_high[4]), # A12
    
    # PORT A (PA7-PA0)
    (16, sbc_porta[0]),     # PA0
    (17, sbc_porta[1]),     # PA1
    (18, sbc_porta[2]),     # PA2
    (19, sbc_porta[3]),     # PA3
    (20, sbc_porta[4]),     # PA4
    (21, sbc_porta[5]),     # PA5
    (22, sbc_porta[6]),     # PA6
    (23, sbc_porta[7]),     # PA7
    
    # PORT B (PB7-PB0)
    (24, sbc_portb[0]),     # PB0
    (25, sbc_portb[1]),     # PB1
    (26, sbc_portb[2]),     # PB2
    (27, sbc_portb[3]),     # PB3
    (28, sbc_portb[4]),     # PB4
    (29, sbc_portb[5]),     # PB5
    (30, sbc_portb[6]),     # PB6
    (31, sbc_portb[7]),     # PB7
    
    # Control signals
    (32, sbc_as),           # AS (Address Strobe)
    (33, sbc_rw),           # R/W (Read/Write)
    (34, sbc_ds),           # DS (Data Strobe)
    (35, sbc_li),           # LI (Load Instruction)
    (36, sbc_reset),        # RESET (active low)
    (37, sbc_irq),          # IRQ (active low)
    
    # Timer
    (38, sbc_timer),        # TIMER output
    
    # Clock
    (39, sbc_osc1),         # OSC1 (manual clock from Arduino)
    
    # Additional grounds for signal integrity
    (40, sbc_gnd),
    (41, sbc_gnd),
    (42, sbc_gnd),
    (43, sbc_gnd),
    (44, sbc_gnd),
    (45, sbc_gnd),
    (46, sbc_gnd),
    (47, sbc_gnd),
    (48, sbc_gnd),
    (49, sbc_gnd),
    (50, sbc_gnd),
]

for pin_num, net in test_pin_map.items():
    test_connector[pin_num] += net

# Generate netlist
generate_netlist()