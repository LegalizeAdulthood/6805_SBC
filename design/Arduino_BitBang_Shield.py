from skidl import *

# Create the Arduino bitbang shield for 6805 SBC interface
# Direct 5V to 5V interface - no level shifting needed
# Includes address latch for proper demultiplexing of 6805's multiplexed AD bus

# Define the circuit
set_default_tool(KICAD)

# Arduino headers (connectors to Arduino board)
arduino_d0_d7 = Bus('D', 8, Pin)  # Digital pins 0-7 (Data bus)
arduino_d8_d13 = Bus('D', 6, Pin) # Digital pins 8-13 (Upper address bits)
arduino_a0_a5 = Bus('A', 6, Pin)  # Analog pins A0-A5 (Lower address bits)
arduino_5v = Net('5V')
arduino_gnd = Net('GND')

# 6805 SBC interface signals
sbc_ad_bus = Bus('SBC_AD', 8, Pin)       # Multiplexed Address/Data bus (PORT A)
sbc_addr_high = Bus('SBC_A_HIGH', 8, Pin) # High address bits (PORT C)
sbc_as = Net('SBC_AS')                   # Address Strobe (indicates address valid)
sbc_rd = Net('SBC_RD')                   # Read strobe
sbc_wr = Net('SBC_WR')                   # Write strobe
sbc_reset = Net('SBC_RST')               # Reset
sbc_irq = Net('SBC_IRQ')                 # Interrupt request
sbc_5v = Net('SBC_5V')
sbc_gnd = Net('SBC_GND')

# Internal nets for demultiplexed address bus
addr_low_latched = Bus('ADDR_LOW', 8, Pin)  # Latched low address byte
data_bus = Bus('DATA', 8, Pin)              # Bidirectional data bus

# Power connections - direct connection, same voltage
sbc_5v += arduino_5v
sbc_gnd += arduino_gnd

# Address latch: 74HC573 (or 74LS373)
# Captures low address byte from AD0-AD7 when AS is asserted
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

# Connect multiplexed AD bus to latch inputs
for i in range(8):
    addr_latch[f'D{i+1}'] += sbc_ad_bus[i]
    
# Connect latch outputs to internal latched address bus
for i in range(8):
    addr_latch[f'Q{i+1}'] += addr_low_latched[i]

# Bidirectional buffers for data bus (74HC245 or similar)
# These allow the Arduino to drive or read the multiplexed AD bus
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

# Connect 6805 AD bus to buffer B side
for i in range(8):
    data_buffer[f'B{i+1}'] += sbc_ad_bus[i]

# Arduino connections:
# Low address byte comes from latched address
for i in range(6):
    arduino_a0_a5[i] += addr_low_latched[i]

# Upper 2 bits of low address byte
arduino_d8_d13[0] += addr_low_latched[6]
arduino_d8_d13[1] += addr_low_latched[7]

# High address byte (if using 6805 with PORT C for upper address)
# Connect to remaining Arduino pins
for i in range(6):
    arduino_d8_d13[i] += sbc_addr_high[i] if i < 6 else sbc_gnd

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
sbc_rd += arduino_d5          # D5 for read strobe
sbc_wr += arduino_d6          # D6 for write strobe
sbc_reset += arduino_d7       # D7 for reset

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
for ic in [addr_latch, data_buffer]:
    cap = Part('Device', 'C', value='100nF', 
               footprint='Capacitor_SMD:C_0805_2012Metric')
    cap[1] += ic['VCC']
    cap[2] += ic['GND']

# 6805 interface connector (2x20 header)
sbc_connector = Part('Connector_Generic', 'Conn_02x20_Odd_Even', 
                     footprint='Connector_PinHeader_2.54mm:PinHeader_2x20_P2.54mm_Vertical')

# Pin mapping for 6805 SBC connector
pin_map = [
    (1, sbc_gnd),
    (2, sbc_5v),
    # Multiplexed Address/Data bus (PORT A)
    (3, sbc_ad_bus[0]),
    (4, sbc_ad_bus[1]),
    (5, sbc_ad_bus[2]),
    (6, sbc_ad_bus[3]),
    (7, sbc_ad_bus[4]),
    (8, sbc_ad_bus[5]),
    (9, sbc_ad_bus[6]),
    (10, sbc_ad_bus[7]),
    # High address bus (PORT C) if available
    (11, sbc_addr_high[0]),
    (12, sbc_addr_high[1]),
    (13, sbc_addr_high[2]),
    (14, sbc_addr_high[3]),
    (15, sbc_addr_high[4]),
    (16, sbc_addr_high[5]),
    (17, sbc_addr_high[6]),
    (18, sbc_addr_high[7]),
    # Control signals
    (19, sbc_as),      # Address Strobe
    (20, sbc_rd),      # Read
    (21, sbc_wr),      # Write
    (22, sbc_reset),   # Reset
    (23, sbc_irq),     # IRQ
    (24, sbc_gnd),
]

for pin_num, net in pin_map:
    sbc_connector[pin_num] += net

# Generate netlist
generate_netlist()