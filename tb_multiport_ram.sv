// Copyright 2025 adachi6k
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Testbench for Multi-port RAM
`timescale 1ns/1ps

module tb_multiport_ram;

  // Parameter
  parameter Width = 32;
  parameter Depth = 32;
  parameter WrNum = 2;
  parameter RdNum = 4;

  // Dut Interface
  logic clk;
  logic [RdNum-1:0][Width-1:0] dout;
  logic [RdNum-1:0][$clog2(Depth)-1:0] ra;
  logic [WrNum-1:0] we ;
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
    .DEBUG(0)  // Disable debug for cleaner output
  )
  uut (
    .dout(dout),
    .clk(clk),
    .wa(wa),
    .we(we),
    .din(din),
    .ra(ra)
  );

  // Test Sequence
  initial begin
    // Waveform Dump
    $dumpfile("dump.vcd");
    $dumpvars;

    // Display which implementation will be used
    $display("=== Multi-port RAM Test ===");
    $display("Parameters: Width=%0d, Depth=%0d, RdNum=%0d, WrNum=%0d", Width, Depth, RdNum, WrNum);
    if ((RdNum < 2)&&(Width<8)||(Depth <= 16)&&(Width>64)) begin
      $display("Implementation: XOR");
    end else begin
      $display("Implementation: LVT");
    end
    $display("========================");

    // Reset
    #1;
    for (int i = 0; i < WrNum; i++) begin
      wa[i] = i[$clog2(Depth)-1:0];
      we[i] = 0;
      din[i] = 0;
    end

    for (int i = 0; i < RdNum; i++) begin
      ra[i] = i[$clog2(Depth)-1:0];
    end

    // Test Sequence #1
    @(posedge clk);
    we[0] = 1;
    we[1] = 1;
    din[0] = 32'hFACE_B00C;
    din[1] = 32'hDEAD_BEEF;
    wa[0] = 3;
    wa[1] = 4;

    ra[0] = 3;
    ra[1] = 4;
    ra[2] = 3;
    ra[3] = 4;

    @(posedge clk);
    @(posedge clk);
    we[0] = 0;
    we[1] = 0;

    // Test Sequence #2
    #10;
    we[0] = 1;
    we[1] = 1;
    din[0] = 32'hC0FF_EE00;
    din[1] = 32'hBEEF_FACE;
    wa[0] = 3;
    wa[1] = 4;

    #20;
    we[0] = 0;
    we[1] = 0;

    #10;
    $finish;
  end

  // Display Time for Debug
  always @(posedge clk) begin
    $display("time %t", $time);
  end

endmodule
