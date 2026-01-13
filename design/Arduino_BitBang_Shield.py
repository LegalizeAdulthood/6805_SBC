from skidl import *

# Create the Arduino bitbang shield for 6805 SBC interface
# Direct 5V to 5V interface - no level shifting needed
# Includes address latch for proper demultiplexing of 6805's multiplexed B bus
# MC146805E2 in 40-pin DIP package
# Arduino provides manual clock on OSC1 for single-stepping
# ALL 6805 pins directly controllable via I2C expanders
# Uses multiple MCP23017 I2C GPIO expanders for complete control

# Define the circuit
set_default_tool(KICAD)

# Arduino headers (connectors to Arduino board)
arduino_d0_d7 = Bus('D', 8, Pin)  # Digital pins 0-7 (Data bus)
arduino_d8_d13 = Bus('D', 6, Pin) # Digital pins 8-13 (spare/future use)
arduino_a0_a3 = Bus('A', 4, Pin)  # Analog pins A0-A3 (spare/future use)
arduino_a4 = Net('ARDUINO_A4')    # I2C SDA
arduino_a5 = Net('ARDUINO_A5')    # I2C SCL
arduino_5v = Net('5V')
arduino_gnd = Net('GND')

# I2C bus
i2c_sda = Net('I2C_SDA')
i2c_scl = Net('I2C_SCL')

# Connect Arduino I2C pins
i2c_sda += arduino_a4
i2c_scl += arduino_a5

# MC146805E2 interface signals - ACTUAL PINOUT
# Multiplexed Address/Data bus (B0-B7)
sbc_b_bus = Bus('SBC_B', 8, Pin)         # B0-B7: Multiplexed low addr (A7-A0) / data (D7-D0)

# High address bits (A12-A8)
sbc_addr_high = Bus('SBC_A_HIGH', 5, Pin) # A12-A8: High address bits (5 bits only!)

# PORT A (PA7-PA0) - controllable via I2C
sbc_porta = Bus('SBC_PA', 8, Pin)         # PA7-PA0: General purpose I/O port

# PORT B (PB7-PB0) - controllable via I2C
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

# Direction control and output enable from I2C expander
buffer_dir = Net('BUF_DIR')
buffer_oe = Net('BUF_OE')
data_buffer['DIR'] += buffer_dir
data_buffer['OE'] += buffer_oe

# Connect Arduino data pins to buffer A side
for i in range(8):
    data_buffer[f'A{i+1}'] += arduino_d0_d7[i]

# Connect 6805 B bus to buffer B side
for i in range(8):
    data_buffer[f'B{i+1}'] += sbc_b_bus[i]

# ============================================================================
# I2C GPIO Expander #1: PORT A and PORT B control
# MCP23017 at address 0x20
# Port A controls 6805 PORT A (PA0-PA7)
# Port B controls 6805 PORT B (PB0-PB7)
# ============================================================================

gpio_ports = Part('Interface_Expansion', 'MCP23017_SO', 
                  footprint='Package_SO:SOIC-28W_7.5x17.9mm_P1.27mm')

gpio_ports['VDD'] += sbc_5v
gpio_ports['VSS'] += sbc_gnd
gpio_ports['SDA'] += i2c_sda
gpio_ports['SCL'] += i2c_scl

# I2C address = 0x20 (A2=0, A1=0, A0=0)
gpio_ports['A0'] += sbc_gnd
gpio_ports['A1'] += sbc_gnd
gpio_ports['A2'] += sbc_gnd
gpio_ports['RESET'] += sbc_5v

# Connect to 6805 PORT A and PORT B
for i in range(8):
    gpio_ports[f'GPA{i}'] += sbc_porta[i]
    gpio_ports[f'GPB{i}'] += sbc_portb[i]

# Interrupt outputs (optional monitoring)
ports_inta = Net('PORTS_INTA')
ports_intb = Net('PORTS_INTB')
gpio_ports['INTA'] += ports_inta
gpio_ports['INTB'] += ports_intb

# ============================================================================
# I2C GPIO Expander #2: High Address bits and Control signals
# MCP23017 at address 0x21
# Port A: A8-A12 (5 bits) + 3 spare
# Port B: Control signals (AS, R/W, DS, LI, RESET, IRQ, BUF_DIR, BUF_OE)
# ============================================================================

gpio_addr_ctrl = Part('Interface_Expansion', 'MCP23017_SO', 
                      footprint='Package_SO:SOIC-28W_7.5x17.9mm_P1.27mm')

gpio_addr_ctrl['VDD'] += sbc_5v
gpio_addr_ctrl['VSS'] += sbc_gnd
gpio_addr_ctrl['SDA'] += i2c_sda
gpio_addr_ctrl['SCL'] += i2c_scl

# I2C address = 0x21 (A2=0, A1=0, A0=1)
gpio_addr_ctrl['A0'] += sbc_5v
gpio_addr_ctrl['A1'] += sbc_gnd
gpio_addr_ctrl['A2'] += sbc_gnd
gpio_addr_ctrl['RESET'] += sbc_5v

# Port A: High address bits A8-A12 (5 bits) + 3 spare
for i in range(5):
    gpio_addr_ctrl[f'GPA{i}'] += sbc_addr_high[i]

# GPA5, GPA6, GPA7 are spare - could be used for future expansion
spare1 = Net('SPARE1')
spare2 = Net('SPARE2')
spare3 = Net('SPARE3')
gpio_addr_ctrl['GPA5'] += spare1
gpio_addr_ctrl['GPA6'] += spare2
gpio_addr_ctrl['GPA7'] += spare3

# Port B: Control signals
gpio_addr_ctrl['GPB0'] += sbc_as      # Address Strobe
gpio_addr_ctrl['GPB1'] += sbc_rw      # Read/Write
gpio_addr_ctrl['GPB2'] += sbc_ds      # Data Strobe
gpio_addr_ctrl['GPB3'] += sbc_li      # Load Instruction
gpio_addr_ctrl['GPB4'] += sbc_reset   # Reset
gpio_addr_ctrl['GPB5'] += sbc_irq     # IRQ
gpio_addr_ctrl['GPB6'] += buffer_dir  # Data buffer direction control
gpio_addr_ctrl['GPB7'] += buffer_oe   # Data buffer output enable

# Interrupt outputs
addr_ctrl_inta = Net('ADDR_CTRL_INTA')
addr_ctrl_intb = Net('ADDR_CTRL_INTB')
gpio_addr_ctrl['INTA'] += addr_ctrl_inta
gpio_addr_ctrl['INTB'] += addr_ctrl_intb

# ============================================================================
# I2C GPIO Expander #3: Latched Address monitoring and Clock/Timer
# MCP23017 at address 0x22
# Port A: Monitor latched low address bits A0-A7
# Port B: OSC1 (clock), TIMER output, + 6 spare
# ============================================================================

gpio_addr_mon = Part('Interface_Expansion', 'MCP23017_SO', 
                     footprint='Package_SO:SOIC-28W_7.5x17.9mm_P1.27mm')

gpio_addr_mon['VDD'] += sbc_5v
gpio_addr_mon['VSS'] += sbc_gnd
gpio_addr_mon['SDA'] += i2c_sda
gpio_addr_mon['SCL'] += i2c_scl

# I2C address = 0x22 (A2=0, A1=1, A0=0)
gpio_addr_mon['A0'] += sbc_gnd
gpio_addr_mon['A1'] += sbc_5v
gpio_addr_mon['A2'] += sbc_gnd
gpio_addr_mon['RESET'] += sbc_5v

# Port A: Monitor latched low address A0-A7
for i in range(8):
    gpio_addr_mon[f'GPA{i}'] += addr_low_latched[i]

# Port B: Clock and timer signals
gpio_addr_mon['GPB0'] += sbc_osc1     # Clock output to 6805
gpio_addr_mon['GPB1'] += sbc_timer    # Timer input from 6805

# GPB2-GPB7 are spare
spare4 = Net('SPARE4')
spare5 = Net('SPARE5')
spare6 = Net('SPARE6')
spare7 = Net('SPARE7')
spare8 = Net('SPARE8')
spare9 = Net('SPARE9')
gpio_addr_mon['GPB2'] += spare4
gpio_addr_mon['GPB3'] += spare5
gpio_addr_mon['GPB4'] += spare6
gpio_addr_mon['GPB5'] += spare7
gpio_addr_mon['GPB6'] += spare8
gpio_addr_mon['GPB7'] += spare9

# Interrupt outputs
addr_mon_inta = Net('ADDR_MON_INTA')
addr_mon_intb = Net('ADDR_MON_INTB')
gpio_addr_mon['INTA'] += addr_mon_inta
gpio_addr_mon['INTB'] += addr_mon_intb

# ============================================================================
# I2C pull-up resistors (required for I2C bus)
# ============================================================================

i2c_pullup_sda = Part('Device', 'R', value='4.7k', 
                      footprint='Resistor_SMD:R_0805_2012Metric')
i2c_pullup_sda[1] += i2c_sda
i2c_pullup_sda[2] += sbc_5v

i2c_pullup_scl = Part('Device', 'R', value='4.7k', 
                      footprint='Resistor_SMD:R_0805_2012Metric')
i2c_pullup_scl[1] += i2c_scl
i2c_pullup_scl[2] += sbc_5v

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

# Decoupling caps for all ICs
for ic in [addr_latch, data_buffer, gpio_ports, gpio_addr_ctrl, gpio_addr_mon]:
    cap = Part('Device', 'C', value='100nF', 
               footprint='Capacitor_SMD:C_0805_2012Metric')
    if 'VCC' in ic.pins:
        cap[1] += ic['VCC']
        cap[2] += ic['GND']
    else:
        cap[1] += ic['VDD']
        cap[2] += ic['VSS']

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
    
    # High address bits (A12-A8)
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
    
    # Timer and clock
    (38, sbc_timer),        # TIMER output
    (39, sbc_osc1),         # OSC1 (manual clock)
    
    # I2C bus
    (40, i2c_sda),          # I2C SDA
    (41, i2c_scl),          # I2C SCL
    
    # Additional grounds for signal integrity
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