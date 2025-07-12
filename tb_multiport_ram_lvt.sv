// Copyright 2025 adachi6k
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Testbench for ram_nrnw_lvt implementation specifically
`timescale 1ns/1ps

module tb_multiport_ram_lvt;

  // Parameters to force LVT implementation: normal case
  parameter Width = 32;
  parameter Depth = 64;
  parameter WrNum = 3;
  parameter RdNum = 2;

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
    // Display implementation info
    $display("=== ram_nrnw_lvt Implementation Test ===");
    $display("Parameters: Width=%0d, Depth=%0d, RdNum=%0d, WrNum=%0d", Width, Depth, RdNum, WrNum);
    if ((RdNum < 2)&&(Width<8)||(Depth <= 16)&&(Width>64)) begin
      $display("✗ Implementation: XOR (unexpected!)");
    end else begin
      $display("✓ Implementation: LVT (as expected)");
    end
    $display("===============================");

    // Initialize
    #1;
    for (int i = 0; i < WrNum; i++) begin
      wa[i] = 0;
      we[i] = 0;
      din[i] = 0;
    end
    for (int i = 0; i < RdNum; i++) begin
      ra[i] = 0;
    end

    // Test multi-write scenario (LVT strength)
    @(posedge clk);
    we[0] = 1;
    we[1] = 1;
    we[2] = 1;
    din[0] = 32'h1111_1111;
    din[1] = 32'h2222_2222;
    din[2] = 32'h3333_3333;
    wa[0] = 6'd10;
    wa[1] = 6'd11;
    wa[2] = 6'd12;
    ra[0] = 6'd10;
    ra[1] = 6'd11;

    @(posedge clk);
    ra[0] = 6'd12;
    ra[1] = 6'd10;
    
    @(posedge clk);
    we[0] = 0;
    we[1] = 0;
    we[2] = 0;

    // Test overwrite scenario
    #10;
    we[0] = 1;
    we[1] = 1;
    din[0] = 32'hAAAA_AAAA;
    din[1] = 32'hBBBB_BBBB;
    wa[0] = 6'd10;  // Same address as before
    wa[1] = 6'd11;  // Same address as before
    ra[0] = 6'd10;
    ra[1] = 6'd11;

    @(posedge clk);
    we[0] = 0;
    we[1] = 0;

    #20;
    $display("LVT test completed successfully");
    $finish;
  end

  // Monitor outputs
  always @(posedge clk) begin
    if (we[0] || we[1] || we[2]) begin
      $display("Time %t: Write - wa[0]=%0d din[0]=%h, wa[1]=%0d din[1]=%h, wa[2]=%0d din[2]=%h", 
               $time, wa[0], din[0], wa[1], din[1], wa[2], din[2]);
    end
    $display("Time %t: Read - ra[0]=%0d dout[0]=%h, ra[1]=%0d dout[1]=%h", 
             $time, ra[0], dout[0], ra[1], dout[1]);
  end

endmodule
