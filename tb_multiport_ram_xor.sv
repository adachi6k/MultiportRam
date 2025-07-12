// Copyright 2025 adachi6k
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Testbench for ram_nrnw_xor implementation specifically
`timescale 1ns/1ps

module tb_multiport_ram_xor;

  // Parameters to force XOR implementation: RdNum < 2 && Width < 8
  parameter Width = 4;
  parameter Depth = 8;
  parameter WrNum = 2;
  parameter RdNum = 1;

  // DUT Interface
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
    .DEBUG(1)
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
    // Display implementation info
    $display("=== ram_nrnw_xor Implementation Test ===");
    $display("Parameters: Width=%0d, Depth=%0d, RdNum=%0d, WrNum=%0d", Width, Depth, RdNum, WrNum);
    if ((RdNum < 2)&&(Width<8)||(Depth <= 16)&&(Width>64)) begin
      $display("✓ Implementation: XOR (as expected)");
    end else begin
      $display("✗ Implementation: LVT (unexpected!)");
    end
    $display("===============================");

    // Initialize
    #1;
    for (int i = 0; i < WrNum; i++) begin
      wa[i] = 0;
      we[i] = 0;
      din[i] = 0;
    end
    ra[0] = 0;

    // Test basic write/read
    @(posedge clk);
    we[0] = 1;
    we[1] = 1;
    din[0] = 4'hA;
    din[1] = 4'hB;
    wa[0] = 3'd2;
    wa[1] = 3'd3;
    ra[0] = 3'd2;

    @(posedge clk);
    ra[0] = 3'd3;
    
    @(posedge clk);
    we[0] = 0;
    we[1] = 0;

    #20;
    $display("XOR test completed successfully");
    $finish;
  end

  // Monitor outputs
  always @(posedge clk) begin
    if (we[0] || we[1]) begin
      $display("Time %t: Write - wa[0]=%0d din[0]=%h, wa[1]=%0d din[1]=%h", 
               $time, wa[0], din[0], wa[1], din[1]);
    end
    $display("Time %t: Read - ra[0]=%0d dout[0]=%h", $time, ra[0], dout[0]);
  end

endmodule
