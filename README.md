# FPGA Multi-Port Register File / Distributed RAM (SystemVerilog)

A configurable **FPGA-oriented multi-port register file / distributed RAM** implementation in SystemVerilog that automatically selects between LVT (Last Value Table) and XOR-based implementations based on design parameters.

> **Important timing/modeling note**  
> This project models FPGA distributed RAM/register file behavior:
> - **Read**: combinatorial/asynchronous (`assign dout = rf[ra]`)
> - **Write**: synchronous to `clk` (`always_ff @(posedge clk)`)
> - **Same-cycle read-after-write**: supported (new data can be observed in the write cycle)
>
> This is **not** a generic ASIC SRAM macro timing model. Many ASIC SRAM macros use synchronous reads with one-or-more-cycle read latency and macro-specific read-during-write behavior.

> **Naming note**  
> The repository name historically uses "RAM", but implemented behavior is closer to an FPGA distributed RAM / multi-port register file.

## File Structure

```
MultiportRam/
├── multiport_ram.sv          # Main design modules
├── tb_multiport_ram.sv       # General testbench (auto-selection)
├── tb_multiport_ram_lvt.sv   # LVT-specific testbench
├── tb_multiport_ram_xor.sv   # XOR-specific testbench
├── Makefile                  # Build automation
├── config.env                # Configuration settings
├── .gitignore                # Git ignore rules
└── README.md                 # This file
```

## Design Files

- **`multiport_ram.sv`**: Contains all design modules
  - `lx_ram_nrnw` - Top-level module with automatic implementation selection
  - `ram_nrnw_lvt` - LVT (Last Value Table) implementation
  - `ram_nrnw_xor` - XOR-based implementation  
  - `dist_ram_1r1w` - Basic 1-read-1-write RAM building block

- **`tb_multiport_ram.sv`**: General testbench with automatic implementation selection
- **`tb_multiport_ram_lvt.sv`**: LVT-specific testbench
- **`tb_multiport_ram_xor.sv`**: XOR-specific testbench

## Features

- **FPGA-Oriented Behavior**: Distributed RAM/register-file style timing
- **Configurable Parameters**: Width, depth, and number of read/write ports
- **Automatic Implementation Selection**: Chooses optimal implementation based on parameters
- **Debug Support**: Optional debug features for verification
- **Parameter Validation**: Runtime checks for parameter correctness (simulation only)

## Module Hierarchy

```
lx_ram_nrnw (Top-level module)
├── ram_nrnw_lvt (LVT implementation)
│   └── dist_ram_1r1w (1R1W basic RAM)
└── ram_nrnw_xor (XOR implementation)
    └── dist_ram_1r1w (1R1W basic RAM)
```

## Parameters

| Parameter | Description | Valid Range | Default |
|-----------|-------------|-------------|---------|
| `Width` | Data width in bits | > 0 | 8 |
| `Depth` | Memory depth (number of entries) | > 0 | 16 |
| `RdNum` | Number of read ports | > 0 | 1 |
| `WrNum` | Number of write ports | > 0 | 1 |
| `DEBUG` | Enable debug features | 0 or 1 | 0 |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock signal |
| `wa` | Input | `WrNum * $clog2(Depth)` | Write addresses |
| `we` | Input | `WrNum` | Write enables |
| `din` | Input | `WrNum * Width` | Write data |
| `ra` | Input | `RdNum * $clog2(Depth)` | Read addresses |
| `dout` | Output | `RdNum * Width` | Read data |

## Implementation Selection

The module automatically selects between two implementations:

- **XOR Implementation**: Used when `(RdNum < 2 && Width < 8) || (Depth <= 16 && Width > 64)`
- **LVT Implementation**: Used in all other cases

## Interface Specification

### Timing Behavior

The multi-port register file / distributed RAM follows **distributed RAM** timing characteristics:

- **Write Operation**: Data is written on the positive edge of `clk` when `we[i]` is asserted
- **Read Operation**: Data is available **combinatorially** after address change
- **Read-after-Write**: New data is available on the same cycle as write (combinatorial read)

These semantics intentionally match FPGA-style distributed RAM/register files, and differ from many ASIC SRAM macros that provide synchronous/registered reads.

### Write Conflict Resolution

When multiple write ports target the **same address** on the **same cycle**:

- **XOR Implementation**: Behavior is **undefined** - should be avoided
- **LVT Implementation**: **Last writer wins** based on port priority (higher port index has priority)

⚠️ **Important**: Users should avoid simultaneous writes to the same address for predictable behavior.

### Timing Diagrams

The following timing diagrams use [WaveDrom](https://wavedrom.com/) JSON format. To view them as interactive timing diagrams:

**Option 1: VS Code Extension**
- Install the "WaveDrom" extension in VS Code
- View this README.md file in VS Code for interactive diagrams

**Option 2: Online WaveDrom Editor**
- Copy the JSON code blocks below
- Paste them into [wavedrom.com](https://wavedrom.com/) online editor

**Option 3: GitHub WaveDrom Viewer**
- Some GitHub repositories support WaveDrom rendering
- The JSON format below is compatible with various WaveDrom viewers

⚠️ **Note**: If you see JSON code instead of timing diagrams on GitHub, use Options 1 or 2 above.

#### Basic Write-then-Read Operation

```json
{
  "signal": [
    {"name": "clk",     "wave": "p....|..."},
    {"name": "we[0]",   "wave": "01.0|..."},
    {"name": "wa[0]",   "wave": "x3..|...", "data": ["ADDR"]},
    {"name": "din[0]",  "wave": "x4..|...", "data": ["DATA"]},
    {"name": "ra[0]",   "wave": "x3..|...", "data": ["ADDR"]},
    {"name": "dout[0]", "wave": "x2.4|...", "data": ["OLD", "DATA"]}
  ],
  "config": { "hscale": 2 },
  "head": {
    "text": "Write-then-Read: New data available same cycle as write"
  }
}
```

#### Write Conflict (Same Address, Same Cycle)

```json
{
  "signal": [
    {"name": "clk",     "wave": "p..|."},
    {"name": "we[0]",   "wave": "01.|."},
    {"name": "we[1]",   "wave": "01.|."},
    {"name": "wa[0]",   "wave": "x3.|.", "data": ["ADDR"]},
    {"name": "wa[1]",   "wave": "x3.|.", "data": ["ADDR"]},
    {"name": "din[0]",  "wave": "x4.|.", "data": ["AAA"]},
    {"name": "din[1]",  "wave": "x5.|.", "data": ["BBB"]},
    {"name": "ra[0]",   "wave": "x3.|.", "data": ["ADDR"]},
    {"name": "dout[0]", "wave": "x.5|.", "data": ["BBB"]}
  ],
  "config": { "hscale": 2 },
  "head": {
    "text": "Write Conflict: Port 1 wins (higher priority in LVT)"
  }
}
```

#### Simultaneous Read/Write (Same Address)

```json
{
  "signal": [
    {"name": "clk",     "wave": "p.|."},
    {"name": "we[0]",   "wave": "01|."},
    {"name": "wa[0]",   "wave": "x3|.", "data": ["ADDR"]},
    {"name": "din[0]",  "wave": "x4|.", "data": ["NEW"]},
    {"name": "ra[0]",   "wave": "x3|.", "data": ["ADDR"]},
    {"name": "dout[0]", "wave": "x24", "data": ["OLD", "NEW"]}
  ],
  "config": { "hscale": 2 },
  "head": {
    "text": "Simultaneous Read/Write: New data available same cycle"
  }
}
```

#### Complete Multi-cycle Operation Example

```json
{
  "signal": [
    {"name": "clk",      "wave": "p........"},
    {"name": "we[0]",    "wave": "010..10.."},
    {"name": "we[1]",    "wave": "0.010...."},
    {"name": "wa[0]",    "wave": "x3.x.4x..", "data": ["5", "7"]},
    {"name": "wa[1]",    "wave": "x.5.x....", "data": ["5"]},
    {"name": "din[0]",   "wave": "x6.x.7x..", "data": ["AA", "CC"]},
    {"name": "din[1]",   "wave": "x.8.x....", "data": ["BB"]},
    {"name": "ra[0]",    "wave": "x3...45..", "data": ["5", "7", "5"]},
    {"name": "ra[1]",    "wave": "x..3.4...", "data": ["5", "7"]},
    {"name": "dout[0]",  "wave": "x2...67..", "data": ["00", "BB", "CC"]},
    {"name": "dout[1]",  "wave": "x..2.6...", "data": ["00", "BB"]}
  ],
  "config": { "hscale": 1 },
  "head": {
    "text": "Multi-cycle Example: Shows write conflicts and read timing"
  }
}
```

**Key observations from the timing diagrams:**
- **Cycle 1**: Write AA to address 5 on port 0
- **Cycle 2**: Write BB to address 5 on port 1 (conflicts with previous write, port 1 wins)
- **Cycle 3**: Both reads show BB (result of port 1 winning the conflict)
- **Cycle 6**: Write CC to address 7 on port 0
- **Cycle 7**: Read from address 7 immediately shows CC (same-cycle read/write)

## Usage Example

```systemverilog
// Instantiate a 32-bit wide, 64-entry deep multi-port register file with 2 read and 2 write ports
lx_ram_nrnw #(
    .Width(32),
    .Depth(64),
    .RdNum(2),
    .WrNum(2),
    .DEBUG(0)
) ram_inst (
    .clk(clk),
    .wa(write_addresses),  // [1:0][5:0]
    .we(write_enables),    // [1:0]
    .din(write_data),      // [1:0][31:0]
    .ra(read_addresses),   // [1:0][5:0]
    .dout(read_data)       // [1:0][31:0]
);
```

## Debug Features

When `DEBUG=1`:
- Internal shadow memory tracks all writes
- Automatic comparison between actual and expected outputs
- Debug messages printed on mismatches

## Testing

Run the testbench with different options:

```bash
# Basic test (auto-selection)
make test

# Test specific implementations
make test-lvt
make test-xor

# Generate timing specification waveforms
make test-timing

# Test all implementations including timing verification
make test-all

# Syntax check (design only)
make syntax

# Check design + testbench
make check-tb

# Test with different simulator
make test SIM=verilator

# Clean and test
make clean test

# Test with smaller parameters  
make test-small
```

### Manual Simulation

```bash
# With iverilog
iverilog -g2012 -o sim multiport_ram.sv tb_multiport_ram.sv
./sim

# With ModelSim/QuestaSim
vlog multiport_ram.sv tb_multiport_ram.sv
vsim -do "run -all" tb_multiport_ram

# With Vivado
xvlog --sv multiport_ram.sv tb_multiport_ram.sv
xelab tb_multiport_ram -s tb_sim
xsim tb_sim -R
```

## Design Notes

1. **LVT Implementation**: Uses a Last Value Table to track which write port last wrote to each address
2. **XOR Implementation**: Uses XOR-based encoding for conflict resolution
3. **Memory Initialization**: In simulation, the `dist_ram_1r1w` building blocks used by both LVT/XOR paths initialize storage to zero via `initial` blocks (no explicit reset port)
4. **Write Conflicts**: When multiple write ports target the same address, behavior depends on implementation

## License

This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details.

## References

MultiportRAM optimized for FPGA. (Registerfile rather than SRAM)

https://github.com/rsd-devel/rsd/blob/master/Processor/Src/Primitives/RAM.sv
"Multi-ported memories for FPGAs via XOR", Laforest, Charles Eric et. al., FPGA 2012
