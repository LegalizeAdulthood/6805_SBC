# Arduino Uno Shield - MC146805E2 Bit-Bang Controller

## Overview

This document describes the design of an Arduino Uno shield that provides bit-banging control of all I/O pins on the Motorola MC146805E2 microcontroller. The shield uses MCP23017 I2C GPIO expanders to provide sufficient I/O pins.

## MC146805E2 Pin Requirements

The MC146805E2 (40-pin DIP package) has:
- **24 bidirectional I/O pins** (PA0-PA7, PB0-PB7, PC0-PC7)
- **9 output-only pins** (PD0-PD7, Timer Output)
- **3 input-only pins** (IRQ, NMI, RESET)
- Power/Clock pins (VDD, VSS, XTAL, EXTAL)

**Total controllable pins: 36** (24+9+3)

Since the Arduino Uno only has 20 digital I/O pins, we need I/O expansion.

## Hardware Design

### Bill of Materials

| Component | Quantity | Description |
|-----------|----------|-------------|
| MCP23017 | 3 | I2C GPIO expanders (16 I/O each) |
| 40-pin DIP socket | 1 | For MC146805E2 |
| 4.7k? resistor | 2 | I2C pull-ups (SDA, SCL) |
| 0.1µF ceramic capacitor | 4 | Decoupling (3x MCP23017, 1x MC6805) |
| Arduino Uno shield PCB | 1 | Stackable headers |
| LEDs (optional) | 4 | Debug/status indicators |
| 330? resistor (optional) | 4 | For LEDs |

### Schematic Design

```
Arduino Uno Shield - MC146805E2 Bit-Bang Controller
====================================================

I2C Bus Configuration:
- SDA: Arduino A4
- SCL: Arduino A5
- Pull-up resistors: 4.7k? to +5V

MCP23017 Address Configuration:
????????????????????????????????????????????????????
? Expander 1: 0x20 (A2=0, A1=0, A0=0)             ?
?   - Controls PA0-PA7, PB0-PB7                    ?
?                                                   ?
? Expander 2: 0x21 (A2=0, A1=0, A0=1)             ?
?   - Controls PC0-PC7, PD0-PD7                    ?
?                                                   ?
? Expander 3: 0x22 (A2=0, A1=1, A0=0)             ?
?   - Controls Timer Out, IRQ, NMI, RESET + spare  ?
????????????????????????????????????????????????????

Pin Mapping:
???????????????????????????????????????????????????
? MCP23017 #1 (Address 0x20)                     ?
?   GPA0-7  ? MC146805E2 PA0-PA7 (bidirectional) ?
?   GPB0-7  ? MC146805E2 PB0-PB7 (bidirectional) ?
?                                                  ?
? MCP23017 #2 (Address 0x21)                     ?
?   GPA0-7  ? MC146805E2 PC0-PC7 (bidirectional) ?
?   GPB0-7  ? MC146805E2 PD0-PD7 (output only)   ?
?                                                  ?
? MCP23017 #3 (Address 0x22)                     ?
?   GPA0    ? MC146805E2 Timer Output            ?
?   GPA1    ? MC146805E2 IRQ (input)             ?
?   GPA2    ? MC146805E2 NMI (input)             ?
?   GPA3    ? MC146805E2 RESET (input)           ?
?   GPA4-7  ? Spare (LEDs/debugging)             ?
?   GPB0-7  ? Spare                               ?
???????????????????????????????????????????????????
```

### Connection Diagram

```
                    Arduino Uno
                  ???????????????
                  ?             ?
            A4 ???? SDA         ?
            A5 ???? SCL         ?
           +5V ???? 5V          ?
           GND ???? GND         ?
                  ???????????????
                        ?
                        ? I2C Bus
                        ?
        ?????????????????????????????????
        ?                               ?
   ???????????   ??????????   ??????????
   ? MCP23017?   ?MCP23017?   ?MCP23017?
   ?  0x20   ?   ?  0x21  ?   ?  0x22  ?
   ?         ?   ?        ?   ?        ?
   ? GPA0-7  ?   ? GPA0-7 ?   ? GPA0   ???? Timer Out
   ?    ?    ?   ?    ?   ?   ? GPA1   ???? IRQ
   ?    ???????????????   ?   ? GPA2   ???? NMI
   ?         ?   ?        ?   ? GPA3   ???? RESET
   ? GPB0-7  ?   ? GPB0-7 ?   ? GPA4-7 ???? Spare/LEDs
   ?    ?    ?   ?    ?   ?   ??????????
   ???????????   ??????????
        ?             ?
        ???????????????
               ?
        MC146805E2 Pins
```

## Arduino Library Code

### Header File: `MC146805E2_Shield.h`

```cpp
#ifndef MC146805E2_SHIELD_H
#define MC146805E2_SHIELD_H

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_MCP23X17.h>

class MC146805E2_Shield {
public:
    // Port definitions matching MC146805E2
    enum Port {
        PORT_A = 0,  // PA0-PA7 (bidirectional)
        PORT_B = 1,  // PB0-PB7 (bidirectional)
        PORT_C = 2,  // PC0-PC7 (bidirectional)
        PORT_D = 3   // PD0-PD7 (output only)
    };
    
    // Control pins
    enum ControlPin {
        PIN_TIMER_OUT = 0,
        PIN_IRQ = 1,
        PIN_NMI = 2,
        PIN_RESET = 3
    };
    
    MC146805E2_Shield();
    bool begin();
    
    // Port operations
    void setPortMode(Port port, uint8_t mode);  // 0=OUTPUT, 1=INPUT
    void writePort(Port port, uint8_t value);
    uint8_t readPort(Port port);
    
    // Individual pin operations
    void setPinMode(Port port, uint8_t pin, uint8_t mode);
    void writePin(Port port, uint8_t pin, bool value);
    bool readPin(Port port, uint8_t pin);
    
    // Control pin operations
    void setControlPin(ControlPin pin, bool value);
    bool readControlPin(ControlPin pin);
    
    // Bulk operations
    void writeAllPorts(uint8_t portA, uint8_t portB, 
                       uint8_t portC, uint8_t portD);
    void readAllPorts(uint8_t &portA, uint8_t &portB, 
                      uint8_t &portC, uint8_t &portD);
    
    // Reset MC146805E2
    void resetMCU();
    
private:
    Adafruit_MCP23X17 mcp1;  // 0x20: PA, PB
    Adafruit_MCP23X17 mcp2;  // 0x21: PC, PD
    Adafruit_MCP23X17 mcp3;  // 0x22: Control pins
    
    bool initialized;
};

#endif
```

### Implementation File: `MC146805E2_Shield.cpp`

```cpp
#include "MC146805E2_Shield.h"

MC146805E2_Shield::MC146805E2_Shield() : initialized(false) {
}

bool MC146805E2_Shield::begin() {
    Wire.begin();
    
    // Initialize MCP23017 expanders
    if (!mcp1.begin_I2C(0x20)) return false;
    if (!mcp2.begin_I2C(0x21)) return false;
    if (!mcp3.begin_I2C(0x22)) return false;
    
    // Set default directions
    // PA, PB, PC are bidirectional - default to INPUT
    for (int i = 0; i < 16; i++) {
        mcp1.pinMode(i, INPUT);
    }
    
    // PC is bidirectional - default to INPUT
    // PD is output only
    for (int i = 0; i < 8; i++) {
        mcp2.pinMode(i, INPUT);      // PC pins
        mcp2.pinMode(i + 8, OUTPUT); // PD pins
    }
    
    // Control pins
    mcp3.pinMode(PIN_TIMER_OUT, OUTPUT);
    mcp3.pinMode(PIN_IRQ, OUTPUT);
    mcp3.pinMode(PIN_NMI, OUTPUT);
    mcp3.pinMode(PIN_RESET, OUTPUT);
    
    // Set RESET high (inactive)
    mcp3.digitalWrite(PIN_RESET, HIGH);
    
    initialized = true;
    return true;
}

void MC146805E2_Shield::setPortMode(Port port, uint8_t mode) {
    if (!initialized) return;
    
    for (int i = 0; i < 8; i++) {
        switch (port) {
            case PORT_A:
                mcp1.pinMode(i, mode);
                break;
            case PORT_B:
                mcp1.pinMode(i + 8, mode);
                break;
            case PORT_C:
                mcp2.pinMode(i, mode);
                break;
            case PORT_D:
                // PD is output only, ignore mode
                mcp2.pinMode(i + 8, OUTPUT);
                break;
        }
    }
}

void MC146805E2_Shield::writePort(Port port, uint8_t value) {
    if (!initialized) return;
    
    switch (port) {
        case PORT_A:
            for (int i = 0; i < 8; i++) {
                mcp1.digitalWrite(i, (value >> i) & 1);
            }
            break;
        case PORT_B:
            for (int i = 0; i < 8; i++) {
                mcp1.digitalWrite(i + 8, (value >> i) & 1);
            }
            break;
        case PORT_C:
            for (int i = 0; i < 8; i++) {
                mcp2.digitalWrite(i, (value >> i) & 1);
            }
            break;
        case PORT_D:
            for (int i = 0; i < 8; i++) {
                mcp2.digitalWrite(i + 8, (value >> i) & 1);
            }
            break;
    }
}

uint8_t MC146805E2_Shield::readPort(Port port) {
    if (!initialized) return 0;
    
    uint8_t value = 0;
    
    switch (port) {
        case PORT_A:
            for (int i = 0; i < 8; i++) {
                if (mcp1.digitalRead(i)) value |= (1 << i);
            }
            break;
        case PORT_B:
            for (int i = 0; i < 8; i++) {
                if (mcp1.digitalRead(i + 8)) value |= (1 << i);
            }
            break;
        case PORT_C:
            for (int i = 0; i < 8; i++) {
                if (mcp2.digitalRead(i)) value |= (1 << i);
            }
            break;
        case PORT_D:
            // PD is output only, read back written values
            for (int i = 0; i < 8; i++) {
                if (mcp2.digitalRead(i + 8)) value |= (1 << i);
            }
            break;
    }
    
    return value;
}

void MC146805E2_Shield::setPinMode(Port port, uint8_t pin, uint8_t mode) {
    if (!initialized || pin > 7) return;
    
    switch (port) {
        case PORT_A:
            mcp1.pinMode(pin, mode);
            break;
        case PORT_B:
            mcp1.pinMode(pin + 8, mode);
            break;
        case PORT_C:
            mcp2.pinMode(pin, mode);
            break;
        case PORT_D:
            mcp2.pinMode(pin + 8, OUTPUT); // Force OUTPUT
            break;
    }
}

void MC146805E2_Shield::writePin(Port port, uint8_t pin, bool value) {
    if (!initialized || pin > 7) return;
    
    switch (port) {
        case PORT_A:
            mcp1.digitalWrite(pin, value);
            break;
        case PORT_B:
            mcp1.digitalWrite(pin + 8, value);
            break;
        case PORT_C:
            mcp2.digitalWrite(pin, value);
            break;
        case PORT_D:
            mcp2.digitalWrite(pin + 8, value);
            break;
    }
}

bool MC146805E2_Shield::readPin(Port port, uint8_t pin) {
    if (!initialized || pin > 7) return false;
    
    switch (port) {
        case PORT_A:
            return mcp1.digitalRead(pin);
        case PORT_B:
            return mcp1.digitalRead(pin + 8);
        case PORT_C:
            return mcp2.digitalRead(pin);
        case PORT_D:
            return mcp2.digitalRead(pin + 8);
    }
    return false;
}

void MC146805E2_Shield::setControlPin(ControlPin pin, bool value) {
    if (!initialized) return;
    mcp3.digitalWrite(pin, value);
}

bool MC146805E2_Shield::readControlPin(ControlPin pin) {
    if (!initialized) return false;
    return mcp3.digitalRead(pin);
}

void MC146805E2_Shield::writeAllPorts(uint8_t portA, uint8_t portB, 
                                       uint8_t portC, uint8_t portD) {
    writePort(PORT_A, portA);
    writePort(PORT_B, portB);
    writePort(PORT_C, portC);
    writePort(PORT_D, portD);
}

void MC146805E2_Shield::readAllPorts(uint8_t &portA, uint8_t &portB, 
                                      uint8_t &portC, uint8_t &portD) {
    portA = readPort(PORT_A);
    portB = readPort(PORT_B);
    portC = readPort(PORT_C);
    portD = readPort(PORT_D);
}

void MC146805E2_Shield::resetMCU() {
    if (!initialized) return;
    
    // Pulse RESET low for 10ms
    mcp3.digitalWrite(PIN_RESET, LOW);
    delay(10);
    mcp3.digitalWrite(PIN_RESET, HIGH);
    delay(10);
}
```

## Example Usage

### Basic Example

```cpp
#include "MC146805E2_Shield.h"

MC146805E2_Shield mc6805;

void setup() {
    Serial.begin(115200);
    
    if (!mc6805.begin()) {
        Serial.println("Failed to initialize MC146805E2 Shield!");
        while (1);
    }
    
    Serial.println("MC146805E2 Shield initialized");
    
    // Reset the MC6805
    mc6805.resetMCU();
    
    // Configure ports
    mc6805.setPortMode(MC146805E2_Shield::PORT_A, OUTPUT);
    mc6805.setPortMode(MC146805E2_Shield::PORT_B, INPUT);
    mc6805.setPortMode(MC146805E2_Shield::PORT_C, OUTPUT);
    // PORT_D is always output
}

void loop() {
    // Write pattern to Port A
    static uint8_t counter = 0;
    mc6805.writePort(MC146805E2_Shield::PORT_A, counter);
    
    // Read Port B
    uint8_t portB = mc6805.readPort(MC146805E2_Shield::PORT_B);
    
    // Write to Port C
    mc6805.writePort(MC146805E2_Shield::PORT_C, ~counter);
    
    // Write to Port D (output only)
    mc6805.writePort(MC146805E2_Shield::PORT_D, counter >> 1);
    
    // Toggle control pins
    mc6805.setControlPin(MC146805E2_Shield::PIN_IRQ, counter & 1);
    
    Serial.print("PA: 0x");
    Serial.print(counter, HEX);
    Serial.print(" PB: 0x");
    Serial.println(portB, HEX);
    
    counter++;
    delay(100);
}
```

### Advanced Example: Memory Interface

```cpp
void writeMemory(uint16_t address, uint8_t data) {
    // Set address on Port A and Port B
    mc6805.writePort(MC146805E2_Shield::PORT_A, address & 0xFF);
    mc6805.writePort(MC146805E2_Shield::PORT_B, (address >> 8) & 0xFF);
    
    // Set data on Port C
    mc6805.setPortMode(MC146805E2_Shield::PORT_C, OUTPUT);
    mc6805.writePort(MC146805E2_Shield::PORT_C, data);
    
    // Toggle write strobe on Port D
    mc6805.writePin(MC146805E2_Shield::PORT_D, 0, HIGH);
    delayMicroseconds(1);
    mc6805.writePin(MC146805E2_Shield::PORT_D, 0, LOW);
}

uint8_t readMemory(uint16_t address) {
    // Set address
    mc6805.writePort(MC146805E2_Shield::PORT_A, address & 0xFF);
    mc6805.writePort(MC146805E2_Shield::PORT_B, (address >> 8) & 0xFF);
    
    // Set data port to input
    mc6805.setPortMode(MC146805E2_Shield::PORT_C, INPUT);
    
    // Toggle read strobe
    mc6805.writePin(MC146805E2_Shield::PORT_D, 1, HIGH);
    delayMicroseconds(1);
    
    uint8_t data = mc6805.readPort(MC146805E2_Shield::PORT_C);
    
    mc6805.writePin(MC146805E2_Shield::PORT_D, 1, LOW);
    
    return data;
}
```

## PCB Design Considerations

### Layout Guidelines

1. **Stackable Headers**: Use standard Arduino Uno shield headers (2.54mm pitch)
2. **Address Configuration**: 
   - Solder jumpers for MCP23017 address pins (A0, A1, A2)
   - Default configuration: 0x20, 0x21, 0x22
3. **Power Supply**: 
   - 5V rail from Arduino for all ICs
   - Optional separate 5V rail for MC146805E2 if different voltage needed
4. **Decoupling Capacitors**: 
   - 0.1µF ceramic capacitor near each MCP23017 VDD pin
   - 0.1µF ceramic capacitor near MC146805E2 VDD pin
5. **I2C Pull-ups**: 
   - 4.7k? resistors on SDA and SCL lines
   - Connect to +5V
6. **Debug LEDs**: 
   - 4x LEDs connected to spare pins (GPA4-7 of MCP3)
   - 330? current limiting resistors

### PCB Layers

- **Top Layer**: Component placement, signal routing
- **Bottom Layer**: Ground plane, power distribution
- **Dimensions**: Standard Arduino Uno shield (53.34mm × 68.58mm)

### Mounting Holes

Use standard Arduino Uno mounting hole positions:
- Top-left: (14.0, 2.5)
- Top-right: (66.0, 7.6)
- Bottom-left: (15.2, 50.8)
- Bottom-right: (66.0, 35.6)

## Performance Characteristics

### Timing Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| I2C Clock Speed | 400 kHz | Fast mode |
| Port Write Latency | 100-200 µs | I2C overhead |
| Port Read Latency | 100-200 µs | I2C overhead |
| Full Port Update | ~600 µs | All 4 ports sequential |
| Maximum Toggle Rate | ~2.5 kHz | Single pin |

### Limitations

- **Not suitable for**: High-speed parallel bus emulation (>10 kHz)
- **Best for**: Slow control signals, manual stepping, debugging
- **I2C bottleneck**: Sequential access to multiple ports
- **No hardware PWM**: All signals are software-controlled

## Interrupt Support (Optional)

The MCP23017 has interrupt pins (INTA, INTB) that can be connected to Arduino pins D2 and D3 for asynchronous event detection.

### Optional Interrupt Connections

```cpp
// Connect MCP23017 INT pins to Arduino
// MCP1 INTA ? D2
// MCP1 INTB ? D3
// MCP2 INTA ? D4 (optional)
// MCP2 INTB ? D5 (optional)

void setup() {
    // Enable interrupts on MCP23017
    mcp1.setupInterrupts(true, false, LOW);
    
    // Attach Arduino interrupt
    pinMode(2, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(2), handleMCP1_A, FALLING);
}

void handleMCP1_A() {
    // Handle Port A/B changes
    uint8_t intFlag = mcp1.getLastInterruptPin();
    uint8_t intValue = mcp1.getLastInterruptPinValue();
    // Process interrupt...
}
```

## Testing and Debugging

### Basic Tests

1. **I2C Communication Test**
   ```cpp
   void testI2C() {
       Wire.beginTransmission(0x20);
       if (Wire.endTransmission() == 0) {
           Serial.println("MCP23017 #1 found!");
       }
   }
   ```

2. **Port Loopback Test**
   ```cpp
   void testLoopback() {
       mc6805.setPortMode(MC146805E2_Shield::PORT_A, OUTPUT);
       mc6805.setPortMode(MC146805E2_Shield::PORT_B, INPUT);
       
       // Connect PA0-PB0, PA1-PB1, etc. with jumpers
       mc6805.writePort(MC146805E2_Shield::PORT_A, 0xAA);
       delay(1);
       uint8_t read = mc6805.readPort(MC146805E2_Shield::PORT_B);
       
       if (read == 0xAA) {
           Serial.println("Loopback test passed!");
       }
   }
   ```

3. **Control Pin Test**
   ```cpp
   void testReset() {
       Serial.println("Pulsing RESET...");
       mc6805.resetMCU();
       Serial.println("RESET complete");
   }
   ```

## Dependencies

### Required Arduino Libraries

```
- Wire (built-in)
- Adafruit_MCP23X17 (install via Library Manager)
```

### Installation

```bash
# Using Arduino Library Manager
Sketch ? Include Library ? Manage Libraries
Search for "Adafruit MCP23017"
Install "Adafruit MCP23XXX" library
```

## License

This design is provided as-is for educational and hobbyist use.

## References

- [MCP23017 Datasheet](https://www.microchip.com/wwwproducts/en/MCP23017)
- [MC146805E2 Datasheet](https://www.nxp.com/docs/en/data-sheet/MC68HC05C8A.pdf)
- [Arduino Uno Pinout](https://www.arduino.cc/en/Reference/Board)
- [Adafruit MCP23017 Library](https://github.com/adafruit/Adafruit-MCP23017-Arduino-Library)

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024 | Initial design |
