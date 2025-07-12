# Makefile for Multi-Port RAM
# Supports multiple simulators

# Default simulator
SIM ?= iverilog

# Source files
DESIGN_SRC = multiport_ram.sv
TB_SRC = tb_multiport_ram.sv
TB_LVT_SRC = tb_multiport_ram_lvt.sv
TB_XOR_SRC = tb_multiport_ram_xor.sv
ALL_SRC = $(DESIGN_SRC) $(TB_SRC)
TESTBENCH = tb_multiport_ram
LVT_TESTBENCH = tb_multiport_ram_lvt
XOR_TESTBENCH = tb_multiport_ram_xor
TOP_MODULE = $(TESTBENCH)

# Output files
VCD_FILE = dump.vcd
LOG_FILE = simulation.log

# Simulator-specific settings
ifeq ($(SIM),iverilog)
    COMPILE_CMD = iverilog -g2012 -o $(TESTBENCH) $(ALL_SRC)
    RUN_CMD = ./$(TESTBENCH)
else ifeq ($(SIM),verilator)
    COMPILE_CMD = verilator --cc --exe --build -j 0 -Wall $(ALL_SRC) --top-module $(TOP_MODULE)
    RUN_CMD = ./obj_dir/V$(TOP_MODULE)
else ifeq ($(SIM),xvlog)
    COMPILE_CMD = xvlog --sv $(ALL_SRC) && xelab $(TOP_MODULE) -s $(TOP_MODULE)_sim
    RUN_CMD = xsim $(TOP_MODULE)_sim -R
else
    $(error Unsupported simulator: $(SIM). Supported: iverilog, verilator, xvlog)
endif

.PHONY: all compile run clean test help

# Default target
all: test

# Compile the design
compile:
	@echo "Compiling with $(SIM)..."
	$(COMPILE_CMD)

# Run simulation
run: compile
	@echo "Running simulation..."
	$(RUN_CMD) | tee $(LOG_FILE)

# Run test (same as run but with additional checks)
test: run
	@echo "Checking simulation results..."
	@if grep -q "ERROR\|FATAL" $(LOG_FILE); then \
		echo "❌ Test FAILED - Errors found in simulation"; \
		exit 1; \
	else \
		echo "✅ Test PASSED - No errors detected"; \
	fi

# Test specific implementations and generate waveforms for documentation
test-timing:
	@echo "Running timing specification test..."
	iverilog -g2012 -o tb_timing_spec $(DESIGN_SRC) tb_timing_spec.sv
	./tb_timing_spec
	@echo "✅ Timing test completed - check timing_spec.vcd for waveforms"
	rm -f tb_timing_spec

# Clean generated files
clean:
	@echo "Cleaning up..."
	rm -f $(TESTBENCH) $(VCD_FILE) $(LOG_FILE)
	rm -f tb_timing_spec timing_spec.vcd
	rm -rf obj_dir/
	rm -f *.jou *.log *.pb
	rm -rf xsim.dir/

# Quick syntax check
syntax:
	@echo "Checking syntax..."
	iverilog -t null -g2012 $(DESIGN_SRC)

# Check design only (without testbench)
check-design:
	@echo "Checking design syntax..."
	iverilog -t null -g2012 $(DESIGN_SRC)

# Check testbench syntax
check-tb:
	@echo "Checking testbench syntax..."
	iverilog -t null -g2012 $(ALL_SRC)

# Test LVT implementation specifically
test-lvt:
	@echo "Testing LVT implementation..."
	iverilog -g2012 -o $(LVT_TESTBENCH) $(DESIGN_SRC) $(TB_LVT_SRC)
	./$(LVT_TESTBENCH)
	rm -f $(LVT_TESTBENCH)

# Test XOR implementation specifically
test-xor:
	@echo "Testing XOR implementation..."
	iverilog -g2012 -o $(XOR_TESTBENCH) $(DESIGN_SRC) $(TB_XOR_SRC)
	./$(XOR_TESTBENCH)
	rm -f $(XOR_TESTBENCH)

# Test all implementations
test-all: test test-lvt test-xor test-timing
	@echo "✅ All implementations (LVT, XOR, and auto-selection) tested successfully"

# Test both LVT and XOR implementations
test-both: test-lvt test-xor
	@echo "✅ Both LVT and XOR implementations tested successfully"
# Run with different parameters
test-small:
	@echo "Testing with small parameters..."
	sed 's/parameter Width = 32/parameter Width = 8/' $(TB_SRC) > temp_tb.sv
	sed -i 's/parameter Depth = 32/parameter Depth = 8/' temp_tb.sv
	iverilog -g2012 -o test_small $(DESIGN_SRC) temp_tb.sv
	./test_small
	rm -f temp_tb.sv test_small

# Display help
help:
	@echo "Multi-Port RAM Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Run full test (default)"
	@echo "  compile     - Compile the design"
	@echo "  run         - Compile and run simulation"
	@echo "  test        - Run simulation with result checking"
	@echo "  clean       - Remove generated files"
	@echo "  syntax      - Quick syntax check (design only)"
	@echo "  check-design- Check design syntax only"
	@echo "  check-tb    - Check design + testbench syntax"
	@echo "  test-lvt    - Test LVT implementation specifically"
	@echo "  test-xor    - Test XOR implementation specifically"
	@echo "  test-both   - Test both LVT and XOR implementations"
	@echo "  test-all    - Test all implementations (auto + LVT + XOR + timing)"
	@echo "  test-timing - Generate timing specification waveforms"
	@echo "  test-small  - Test with smaller parameters"
	@echo "  help        - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  SIM       - Simulator to use (iverilog, verilator, xvlog)"
	@echo "            Default: iverilog"
	@echo ""
	@echo "Examples:"
	@echo "  make test                 # Run with default simulator"
	@echo "  make test SIM=verilator   # Run with Verilator"
	@echo "  make clean test           # Clean and test"
