# Multi-Port RAM Implementation

A configurable multi-port RAM implementation in SystemVerilog that automatically selects between LVT (Last Value Table) and XOR-based implementations based on design parameters.

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

## Usage Example

```systemverilog
// Instantiate a 32-bit wide, 64-entry deep RAM with 2 read and 2 write ports
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

# Test all implementations
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
3. **Memory Initialization**: Memory contents are undefined at startup (no reset)
4. **Write Conflicts**: When multiple write ports target the same address, behavior depends on implementation

## License

This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details.

## References

MultiportRAM optimized for FPGA. (Registerfile rather than SRAM)

https://github.com/rsd-devel/rsd/blob/master/Processor/Src/Primitives/RAM.sv
"Multi-ported memories for FPGAs via XOR", Laforest, Charles Eric et. al., FPGA 2012

