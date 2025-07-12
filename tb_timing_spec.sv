// Copyright 2025 adachi6k
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Testbench for timing specification verification
// Generates detailed waveforms showing interface behavior
`timescale 1ns/1ps

module tb_timing_spec;

  // Test parameters
  parameter Width = 8;
  parameter Depth = 16;
  parameter WrNum = 2;
  parameter RdNum = 2;

  // DUT Interface
  logic clk;
  logic [RdNum-1:0][Width-1:0] dout;
  logic [RdNum-1:0][$clog2(Depth)-1:0] ra;
  logic [WrNum-1:0] we;
  logic [WrNum-1:0][Width-1:0] din;
  logic [WrNum-1:0][$clog2(Depth)-1:0] wa;
  
  // Clock Generation
  initial begin
    clk = 0;
    forever begin
       #5 clk = ~clk;
    end
  end

  // DUT
  lx_ram_nrnw
  #(
    .Width(Width),
    .Depth(Depth),
    .RdNum(RdNum),
    .WrNum(WrNum),
    .DEBUG(0)
  )
  uut (
    .dout(dout),
    .clk(clk),
    .wa(wa),
    .we(we),
    .din(din),
    .ra(ra)
  );

  // Test sequence demonstrating timing specifications
  initial begin
    $display("=== Interface Timing Specification Test ===");
    $display("Generating waveforms for documentation...");
    
    // Waveform dump
    $dumpfile("timing_spec.vcd");
    $dumpvars(0, tb_timing_spec);

    // Initialize all signals
    for (int i = 0; i < WrNum; i++) begin
      wa[i] = 0;
      we[i] = 0;
      din[i] = 0;
    end
    for (int i = 0; i < RdNum; i++) begin
      ra[i] = 0;
    end

    // Test 1: Basic Write-then-Read
    $display("\n--- Test 1: Basic Write-then-Read ---");
    @(posedge clk);
    we[0] = 1;
    wa[0] = 4'h5;  // Address 5
    din[0] = 8'hAA; // Data 0xAA
    ra[0] = 4'h5;   // Read same address
    
    @(posedge clk);
    we[0] = 0;
    
    // Test 2: Write Conflict (Same Address)
    $display("\n--- Test 2: Write Conflict Resolution ---");
    @(posedge clk);
    we[0] = 1;
    we[1] = 1;
    wa[0] = 4'h3;   // Same address
    wa[1] = 4'h3;   // Same address
    din[0] = 8'h11; // Port 0 data
    din[1] = 8'h22; // Port 1 data (should win)
    ra[0] = 4'h3;   // Read the conflicted address
    
    @(posedge clk);
    we[0] = 0;
    we[1] = 0;
    
    // Test 3: Simultaneous Read/Write (Same Address)
    $display("\n--- Test 3: Simultaneous Read/Write ---");
    @(posedge clk);
    we[0] = 1;
    wa[0] = 4'h7;
    din[0] = 8'hFF;
    ra[0] = 4'h7;   // Read same address being written
    ra[1] = 4'h3;   // Read previous conflict result
    
    @(posedge clk);
    we[0] = 0;
    
    // Test 4: Multiple reads of same location
    $display("\n--- Test 4: Multiple Reads Same Location ---");
    @(posedge clk);
    ra[0] = 4'h7;   // Both read ports
    ra[1] = 4'h7;   // read same location
    
    @(posedge clk);
    @(posedge clk);
    
    $display("\nTiming specification test completed.");
    $display("Check timing_spec.vcd for detailed waveforms.");
    $finish;
  end

  // Monitor for documentation
  always @(posedge clk) begin
    $display("T=%0t: we=%b wa=%h din=%h | ra=%h dout=%h", 
             $time, we, wa, din, ra, dout);
  end

endmodule
