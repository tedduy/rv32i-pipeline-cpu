# Debug Guide - DE2-115 FPGA Implementation

## 🎛️ Debug Controls

### Switch Controls (SW[2:0])

| SW[2] | SW[1] | SW[0] | Display Mode | 7-Segment Shows | LEDR[17:5] | LEDR[4:0] |
|-------|-------|-------|--------------|-----------------|------------|-----------|
| 0 | 0 | 0 | **Cycle Counter** | Total cycles | Lower 13 bits | rd_addr |
| 0 | 0 | 1 | **Program Counter** | Current PC | Lower 13 bits | rd_addr |
| 0 | 1 | 0 | **Instruction** | Current instruction | Lower 13 bits | rd_addr |
| 0 | 1 | 1 | **ALU Output** | ALU result | Lower 13 bits | rd_addr |
| 1 | 0 | 0 | **Writeback Data** | Data to write | Lower 13 bits | rd_addr |
| 1 | 0 | 1 | **Memory Address** | Memory addr | Lower 13 bits | rd_addr |
| 1 | 1 | 0 | **Instruction Count** | Instructions done | Lower 13 bits | rd_addr |
| 1 | 1 | 1 | **Register Read** | RD1 value | Lower 13 bits | rd_addr |

### LED Indicators

#### Green LEDs (LEDG[8:0]) - CPU Status
| LED | Signal | Meaning |
|-----|--------|---------|
| LEDG[0] | Reset Status | ON = CPU running, OFF = Reset active |
| LEDG[1] | Register Write | Blinks when writing to registers |
| LEDG[2] | Memory Write | Blinks when writing to memory (SW, SH, SB) |
| LEDG[3] | Memory Read | Blinks when reading from memory (LW, LH, LB, etc.) |
| LEDG[4] | Branch Taken | ON when branch is taken |
| LEDG[5] | JAL | ON when executing JAL instruction |
| LEDG[6] | JALR | ON when executing JALR instruction |
| LEDG[7] | Pipeline Stall | ON when pipeline is stalled (load-use hazard) |
| LEDG[8] | Pipeline Flush | ON when pipeline is flushed (branch/jump) |

#### Red LEDs (LEDR[17:0]) - Data Display
- **LEDR[17:5]:** Lower 13 bits of selected display value
- **LEDR[4:0]:** Destination register address (rd_addr)
  - Shows which register is being written (x0-x31)
  - Useful for tracking register writes
- Changes based on SW[2:0] setting

---

## 🔍 Debug Scenarios

### Scenario 1: Monitor Cycle Count (Default)

**Setup:**
```
SW[2:0] = 000 (all switches DOWN)
```

**What you see:**
- **7-Segment:** Cycle counter in hex (00000000 → FFFFFFFF)
- **LEDR:** Lower 18 bits of cycle counter (fast blinking)
- **LEDG[1]:** Blinks when instructions write to registers

**Use case:**
- Verify CPU is running
- Measure execution time
- Check for hangs/freezes

**Example:**
```
HEX: 00000123  ← 291 cycles executed
LEDR: Blinking rapidly
LEDG[1]: Blinking (register writes)
```

---

### Scenario 2: Monitor Program Counter

**Setup:**
```
SW[2:0] = 001 (SW[0] UP, others DOWN)
```

**What you see:**
- **7-Segment:** Current PC value in hex
- **LEDR:** Lower 18 bits of PC
- **LEDG[4]:** Lights up when branch taken
- **LEDG[5-6]:** Light up for JAL/JALR

**Use case:**
- Track program execution flow
- Verify branches/jumps
- Debug control flow issues

**Example:**
```
HEX: 00000004  ← PC at address 0x04
     ↓
HEX: 00000008  ← PC at address 0x08
     ↓
HEX: 00000020  ← Branch taken! (LEDG[4] ON)
```

**Expected PC sequence:**
```
0x00000000  (reset)
0x00000004  (instruction 1)
0x00000008  (instruction 2)
0x0000000C  (instruction 3)
...
0x00000130  (last instruction)
0x00000134  (loop back or halt)
```

---

### Scenario 3: Monitor Instructions

**Setup:**
```
SW[2:0] = 010 (SW[1] UP, others DOWN)
```

**What you see:**
- **7-Segment:** Current instruction encoding (hex)
- **LEDR:** Lower 18 bits of instruction
- **LEDG[2-3]:** Light up for memory operations

**Use case:**
- Verify correct instruction fetch
- Debug instruction memory issues
- Check instruction encoding

**Example:**
```
HEX: 002081B3  ← add x3, x1, x2
     ↓
HEX: 40520333  ← sub x6, x4, x5
     ↓
HEX: 00A10183  ← lb x3, 10(x2)  (LEDG[3] ON for load)
```

**Decode instruction:**
```
Instruction: 0x002081B3
Binary: 0000000 00010 00001 000 00011 0110011
        └─────┘ └───┘ └───┘ └─┘ └───┘ └─────┘
        funct7  rs2   rs1  f3  rd    opcode
        
Opcode: 0110011 = R-type
Funct3: 000 = ADD
Funct7: 0000000 = ADD (not SUB)
→ ADD x3, x1, x2
```

---

### Scenario 4: Monitor ALU Output

**Setup:**
```
SW[2:0] = 011 (SW[0] and SW[1] UP, SW[2] DOWN)
```

**What you see:**
- **7-Segment:** ALU result in hex
- **LEDR:** Lower 18 bits of ALU result
- **LEDG[1]:** Blinks when result written to register

**Use case:**
- Verify ALU operations
- Debug arithmetic/logic errors
- Check computation results

**Example:**
```
Instruction: ADD x3, x1, x2
x1 = 0x00000005
x2 = 0x00000003

HEX: 00000008  ← ALU output (5 + 3 = 8)
LEDG[1]: ON (writing to x3)
```

---

## 🧪 Debug Workflows

### Workflow 1: Verify CPU is Running

1. **Set SW[1:0] = 00** (cycle counter mode)
2. **Press KEY[0]** to reset
3. **Observe:**
   - 7-segment should count up continuously
   - LEDG[0] should be ON (running)
   - LEDG[1] should blink (register writes)

**Pass:** Counter increases continuously
**Fail:** Counter stuck or not changing

---

### Workflow 2: Track Program Execution

1. **Set SW[1:0] = 01** (PC mode)
2. **Press KEY[0]** to reset
3. **Observe PC sequence:**
   ```
   0x00000000 → 0x00000004 → 0x00000008 → ...
   ```
4. **Watch for branches:**
   - LEDG[4] lights up when branch taken
   - PC jumps to non-sequential address

**Pass:** PC follows expected sequence
**Fail:** PC stuck or jumps incorrectly

---

### Workflow 3: Verify Instructions

1. **Set SW[1:0] = 10** (instruction mode)
2. **Press KEY[0]** to reset
3. **Compare with expected instructions:**
   ```
   Expected: 0x002081B3 (add x3, x1, x2)
   Display:  0x002081B3 ✓
   ```
4. **Check memory operations:**
   - LEDG[3] ON for loads (LW, LH, LB, etc.)
   - LEDG[2] ON for stores (SW, SH, SB)

**Pass:** Instructions match expected values
**Fail:** Wrong instruction encoding

---

### Workflow 4: Debug ALU Operations

1. **Set SW[1:0] = 11** (ALU mode)
2. **Press KEY[0]** to reset
3. **Manually calculate expected results:**
   ```
   Instruction: ADD x3, x1, x2
   x1 = 5, x2 = 3
   Expected: 8
   ```
4. **Compare with display:**
   ```
   HEX: 00000008 ✓
   ```

**Pass:** ALU output matches calculation
**Fail:** Wrong ALU result

---

## 📊 Debug Checklist

### Basic Functionality
- [ ] Cycle counter increases continuously
- [ ] LEDG[0] ON after reset released
- [ ] LEDG[1] blinks (register writes)
- [ ] PC starts at 0x00000000
- [ ] PC increments by 4 each cycle (no branches)

### Control Flow
- [ ] LEDG[4] lights up for branches
- [ ] LEDG[5] lights up for JAL
- [ ] LEDG[6] lights up for JALR
- [ ] PC jumps correctly on branches
- [ ] LEDG[8] lights up when flushing pipeline

### Memory Operations
- [ ] LEDG[3] lights up for loads
- [ ] LEDG[2] lights up for stores
- [ ] Memory addresses are correct

### Pipeline Behavior
- [ ] LEDG[7] lights up for stalls (load-use hazard)
- [ ] LEDG[8] lights up for flushes (branch/jump)
- [ ] Pipeline recovers after stall/flush

---

## 🎓 Tips for Debugging

### 1. Start Simple
- Begin with cycle counter mode (SW[1:0] = 00)
- Verify basic operation first
- Then move to more complex modes

### 2. Use Multiple Modes
- Switch between modes to correlate data
- Example: Check PC, then check instruction at that PC

### 3. Take Photos
- Capture 7-segment displays at key moments
- Document LED patterns
- Compare with expected values

### 4. Use Reset Frequently
- Press KEY[0] to restart from known state
- Easier to track execution from beginning

### 5. Watch LED Patterns
- LEDG[1] should blink regularly (register writes)
- LEDG[7-8] should be mostly OFF (few stalls/flushes)
- LEDG[2-3] should blink occasionally (memory ops)

---

## 🐛 Common Issues

### Issue 1: Counter Not Increasing
**Symptom:** 7-segment stuck at 00000000
**Possible causes:**
- Clock not running
- Reset stuck active (KEY[0] pressed)
- CPU not executing

**Debug:**
1. Check LEDG[0] (should be ON)
2. Check LEDG[1] (should blink)
3. Try different clock source

---

### Issue 2: PC Not Sequential
**Symptom:** PC jumps randomly
**Possible causes:**
- Branch/jump instructions executing
- Control flow bug
- Instruction memory corruption

**Debug:**
1. Check LEDG[4-6] (branch/jump indicators)
2. Switch to instruction mode (SW[1:0] = 10)
3. Verify instruction encoding

---

### Issue 3: Wrong ALU Results
**Symptom:** ALU output doesn't match calculation
**Possible causes:**
- ALU logic error
- Forwarding issue
- Register file corruption

**Debug:**
1. Check instruction encoding (mode 10)
2. Check PC (mode 01)
3. Verify operand values

---

## 📸 Documentation for Report

### Photos to Take

1. **Cycle Counter Mode (SW[1:0] = 00)**
   - Show counter at 0x00000000 (reset)
   - Show counter at high value (0x00012345)
   - Capture LEDG pattern

2. **PC Mode (SW[1:0] = 01)**
   - Show PC at 0x00000000
   - Show PC at 0x00000004
   - Show PC during branch (LEDG[4] ON)

3. **Instruction Mode (SW[1:0] = 10)**
   - Show first instruction (0x00000000)
   - Show load instruction (LEDG[3] ON)
   - Show store instruction (LEDG[2] ON)

4. **ALU Mode (SW[1:0] = 11)**
   - Show ALU result for ADD
   - Show ALU result for SUB
   - Show ALU result for logic ops

### Video Clips

1. **Cycle counter running** (10 seconds)
2. **PC incrementing** (10 seconds)
3. **LED patterns during execution** (15 seconds)
4. **Reset and restart** (10 seconds)

---

## ✅ Success Criteria

**CPU is working correctly when:**
- ✅ Cycle counter increases continuously
- ✅ PC follows expected sequence
- ✅ Instructions match expected encoding
- ✅ ALU results are correct
- ✅ LED indicators show expected patterns
- ✅ No unexpected stalls or flushes
- ✅ Reset works reliably

**This proves your CPU is functionally correct on real hardware!** 🎉
