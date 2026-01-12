from skidl import *

# Create the Arduino bitbang shield for 6805 SBC interface
# Direct 5V to 5V interface - no level shifting needed
# Simplified design for bit-banging debug/programming interface

# Define the circuit
set_default_tool(KICAD)

# Arduino headers (connectors to Arduino board)
arduino_d0_d7 = Bus('D', 8, Pin)  # Digital pins 0-7 (Data bus)
arduino_d8_d13 = Bus('D', 6, Pin) # Digital pins 8-13 (Address + Control)
arduino_a0_a5 = Bus('A', 6, Pin)  # Analog pins A0-A5 (Address lines)
arduino_5v = Net('5V')
arduino_gnd = Net('GND')

# 6805 SBC interface
sbc_data_bus = Bus('SBC_D', 8, Pin)      # 8-bit data bus
sbc_addr_bus = Bus('SBC_A', 12, Pin)     # 12 address lines for bit-banging
sbc_rd = Net('SBC_RD')                   # Read strobe
sbc_wr = Net('SBC_WR')                   # Write strobe
sbc_reset = Net('SBC_RST')               # Reset
sbc_irq = Net('SBC_IRQ')                 # Interrupt request
sbc_5v = Net('SBC_5V')
sbc_gnd = Net('SBC_GND')

# Power connections - direct connection, same voltage
sbc_5v += arduino_5v
sbc_gnd += arduino_gnd

# Direct data bus connections (D0-D7)
for i in range(8):
    arduino_d0_d7[i] += sbc_data_bus[i]

# Address bus connections (A0-A5 analog pins + D8-D13 digital pins)
# A0-A5 for address bits 0-5
for i in range(6):
    arduino_a0_a5[i] += sbc_addr_bus[i]

# D8-D13 for address bits 6-11 (6 more bits = 12 total address lines)
for i in range(6):
    arduino_d8_d13[i] += sbc_addr_bus[i+6]

# Control signal assignments (using remaining Arduino pins)
# Note: You'll need to define which Arduino pins are used for control
# This is a simplified version - adjust pin assignments as needed
sbc_rd += Net('ARDUINO_D2')      # Could use D2 for read strobe
sbc_wr += Net('ARDUINO_D3')      # Could use D3 for write strobe
sbc_reset += Net('ARDUINO_D4')   # Could use D4 for reset
sbc_irq += Net('ARDUINO_D5')     # Could use D5 for IRQ monitoring

# Series resistors for bus protection (current limiting)
# Optional but good practice for bit-banging
for i in range(8):
    r = Part('Device', 'R', value='220', 
             footprint='Resistor_SMD:R_0805_2012Metric')
    r[1] += arduino_d0_d7[i]
    r[2] += sbc_data_bus[i]

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

# 6805 interface connector (2x20 header for expansion)
sbc_connector = Part('Connector_Generic', 'Conn_02x20_Odd_Even', 
                     footprint='Connector_PinHeader_2.54mm:PinHeader_2x20_P2.54mm_Vertical')

# Pin mapping (simplified - expand as needed)
pin_map = [
    (1, sbc_gnd),
    (2, sbc_5v),
    (3, sbc_data_bus[0]),
    (4, sbc_data_bus[1]),
    (5, sbc_data_bus[2]),
    (6, sbc_data_bus[3]),
    (7, sbc_data_bus[4]),
    (8, sbc_data_bus[5]),
    (9, sbc_data_bus[6]),
    (10, sbc_data_bus[7]),
    (11, sbc_addr_bus[0]),
    (12, sbc_addr_bus[1]),
    (13, sbc_addr_bus[2]),
    (14, sbc_addr_bus[3]),
    (15, sbc_addr_bus[4]),
    (16, sbc_addr_bus[5]),
    (17, sbc_rd),
    (18, sbc_wr),
    (19, sbc_reset),
    (20, sbc_irq),
]

for pin_num, net in pin_map:
    sbc_connector[pin_num] += net

# Generate netlist
generate_netlist()