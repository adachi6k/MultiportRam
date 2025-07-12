// Copyright 2025 adachi6k
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Multi-port RAM with configurable read/write ports
// Automatically selects between LVT and XOR implementation based on parameters
// Reference: https://github.com/rsd-devel/rsd/blob/master/Processor/Src/Primitives/RAM.sv
//
// INTERFACE SPECIFICATION:
// - Write: Data written on posedge clk when we[i] asserted
// - Read:  Data available combinatorially after address change
// - Read-after-Write: New data available same cycle as write
// - Write Conflicts: Avoid simultaneous writes to same address
//   * LVT: Higher port index has priority (port N beats port N-1)
//   * XOR: Undefined behavior - should be avoided
//
`timescale 1ns/1ps

module lx_ram_nrnw
#(parameter Width=8,   // Data width (must be > 0)
  parameter Depth=16,  // Memory depth (must be > 0)
  parameter RdNum=1,   // Number of read ports (must be > 0)
  parameter WrNum=1,   // Number of write ports (must be > 0)
  parameter DEBUG=0    // Enable debug features (0 or 1)
  )
  (
    // Read interface - combinatorial output
    output logic [RdNum-1:0][Width-1:0] dout, // Read data [port][bit]
    
    // Clock
    input logic clk,                           // Clock signal
    
    // Write interface - synchronous to clk
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,  // Write addresses [port][addr_bit]
    input logic [WrNum-1:0] we,                      // Write enables [port]
    input logic [WrNum-1:0][Width-1:0] din,         // Write data [port][bit]
    
    // Read interface - combinatorial address input
    input logic [RdNum-1:0][$clog2(Depth)-1:0] ra   // Read addresses [port][addr_bit]
  );

  // Parameter validation (simulation only)
  // Note: These checks are not synthesizable
  `ifdef SIMULATION
  initial begin
    if (Width <= 0) begin
      $error("lx_ram_nrnw: Width must be greater than 0, got %0d", Width);
      $finish;
    end
    if (Depth <= 0) begin
      $error("lx_ram_nrnw: Depth must be greater than 0, got %0d", Depth);
      $finish;
    end
    if (RdNum <= 0) begin
      $error("lx_ram_nrnw: RdNum must be greater than 0, got %0d", RdNum);
      $finish;
    end
    if (WrNum <= 0) begin
      $error("lx_ram_nrnw: WrNum must be greater than 0, got %0d", WrNum);
      $finish;
    end
    if (DEBUG != 0 && DEBUG != 1) begin
      $error("lx_ram_nrnw: DEBUG must be 0 or 1, got %0d", DEBUG);
      $finish;
    end
  end
  `endif

  // Select ram_nrnw_lvt or ram_nrnw_xor
  if ((RdNum < 2)&&(Width<8)||
      (Depth <= 16)&&(Width>64)) begin: g_xor
    ram_nrnw_xor
    #(.Width(Width), .Depth(Depth), .RdNum(RdNum), .WrNum(WrNum))
    ram (.dout(dout), .clk(clk), .wa(wa), .we(we), .din(din), .ra(ra) );
  end else begin: g_lvt
    ram_nrnw_lvt
    #(.Width(Width), .Depth(Depth), .RdNum(RdNum), .WrNum(WrNum))
    ram (.dout(dout), .clk(clk), .wa(wa), .we(we), .din(din), .ra(ra) );
  end

  // Debug logic - only instantiated when DEBUG parameter is enabled
  generate
    if (DEBUG == 1) begin: g_debug
      logic [Width-1:0] debug_rf[Depth];
      
      always_ff @(posedge clk) begin
        for (int i = 0; i < WrNum; i++) begin
          if (we[i]) begin
            debug_rf[wa[i]] <= #1 din[i];
          end
        end
      end
      
      logic [Width-1:0] debug_rdout[RdNum];

      for (genvar i = 0; i < RdNum; i++) begin: debug_rd
        assign debug_rdout[i] = debug_rf[ra[i]];
        always @(posedge clk) begin
          if (dout[i] != debug_rf[ra[i]]) begin
            $display("DEBUG: dout[%0d]=%h, debug_rf=%h, ra=%0d at time %t", 
                     i, dout[i], debug_rf[ra[i]], ra[i], $time);
          end    
        end
      end
    end
  endgenerate

endmodule

module ram_nrnw_lvt
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1,
  parameter RdNum=1,
  parameter WrNum=1
  )  // Set a non-zero default
  (
    output logic [RdNum-1:0][Width-1:0] dout,
    input logic clk,
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,
    input logic [WrNum-1:0] we,
    input logic [WrNum-1:0][Width-1:0] din,
    input logic [RdNum-1:0][$clog2(Depth)-1:0] ra
  );

  if (WrNum == 1) begin
    for (genvar i=0; i<RdNum; i++) begin: ri
        dist_ram_1r1w
        #(.Width(Width), .Depth(Depth))
        rdbk_ram (.dout(dout[i]), .ra(ra[i]), .clk(clk), .wa(wa[0]), .we(we[0]), .din(din[0]));
    end
  end else begin
    localparam WrNumIdxWidth = (WrNum == 1) ? 1 : $clog2(WrNum);
    logic [RdNum-1:0][WrNumIdxWidth-1:0] lvt_dout;
    logic [WrNum-1:0][WrNumIdxWidth-1:0] lvt_din;

    for (genvar i=0; i<WrNum; i++) begin: g_lvt_din
        assign lvt_din[i] = i;
    end

    ram_nrnw_xor
    #(.Width(WrNumIdxWidth), .Depth(Depth), .RdNum(RdNum), .WrNum(WrNum))
    lvt (.dout(lvt_dout), .clk(clk), .wa(wa), .we(we), .din(lvt_din), .ra(ra) );

    logic [Width-1:0] rdbk_dout[RdNum][WrNum];

    for (genvar j=0; j<WrNum; j++) begin: g_wi
        for (genvar i=0; i<RdNum; i++) begin: g_ri
            dist_ram_1r1w
            #(.Width(Width), .Depth(Depth))
            rdbk_ram (.dout(rdbk_dout[i][j]), .ra(ra[i]), .clk(clk), .wa(wa[j]), .we(we[j]), .din(din[j]));
        end
    end
    for (genvar i=0; i<RdNum; i++) begin: g_rdout
        assign dout[i] = rdbk_dout[i][lvt_dout[i]];
    end

  end      
endmodule

module ram_nrnw_xor
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1,
  parameter RdNum=1,
  parameter WrNum=1
  )  // Set a non-zero default
  (
    output logic [RdNum-1:0][Width-1:0] dout,
    input logic clk,
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,
    input logic [WrNum-1:0] we,
    input logic [WrNum-1:0][Width-1:0] din,
    input logic [RdNum-1:0][$clog2(Depth)-1:0] ra
  );
 
  logic [Width-1:0] wrbk_din[WrNum];
  logic [Width-1:0] wrbk_dout[WrNum][WrNum];
  logic [Width-1:0] rdbk_dout[WrNum][RdNum];

  logic [Width-1:0] rdout[RdNum];

  for (genvar j=0; j<WrNum; j++) begin : wj
    for (genvar i=0; i<WrNum; i++) begin : wi
        if (j != i) begin : wrbk
            dist_ram_1r1w
            #(.Width(Width), .Depth(Depth))
            wrbk_ram (.dout(wrbk_dout[j][i]), .ra(wa[i]), .clk(clk), .wa(wa[j]), .we(we[j]), .din(wrbk_din[j]));
        end
    end
  end

  for (genvar j=0; j<WrNum; j++) begin : rj
    for (genvar i=0; i<RdNum; i++) begin : ri
        dist_ram_1r1w
        #(.Width(Width), .Depth(Depth))
        rdbk_ram (.dout(rdbk_dout[j][i]), .ra(ra[i]), .clk(clk), .wa(wa[j]), .we(we[j]), .din(wrbk_din[j]));
    end
  end

  always_comb begin
    for (int i=0; i<WrNum; i++) begin
        wrbk_din[i] = din[i];
        for (int j=0; j<WrNum; j++) begin
            if (i!=j) begin
                wrbk_din[i] ^= wrbk_dout[j][i];
            end
        end 
    end

    for (int i=0; i<RdNum; i++) begin
        rdout[i] = '0;
        for (int j=0; j<WrNum; j++) begin
            rdout[i] ^= rdbk_dout[j][i];
        end
    end

    for (int i=0; i<RdNum; i++) begin
        dout[i] = rdout[i];
    end
  end

endmodule

// Basic 1-read-1-write distributed RAM building block
// Timing: Write on posedge clk, Read combinatorial
module dist_ram_1r1w
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1)  // Set a non-zero default
  (
    output logic [Width-1:0] dout,              // Read data (combinatorial)
    input logic clk,                            // Clock signal
    input logic [$clog2(Depth)-1:0] wa,         // Write address
    input logic we,                             // Write enable
    input logic [Width-1:0] din,                // Write data
    input logic [$clog2(Depth)-1:0] ra          // Read address (combinatorial)
  );

  logic [Width-1:0] rf[0:Depth-1];

  // Initialize memory to zero
  initial begin
    for (int i = 0; i < Depth; i++) begin
      rf[i] = '0;
    end
  end

  always_ff @(posedge clk) begin
    if (we) begin
      rf[wa] <= #1 din;
    end
  end
  assign dout = rf[ra];

endmodule
