module lx_ram_nrnw
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1,  // Set a non-zero default
  parameter RdNum=1,  // Set a non-zero default
  parameter WrNum=1   // Set a non-zero default
  )
  (
    output logic [RdNum-1:0][Width-1:0] dout,
    input logic clk,
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,
    input logic [WrNum-1:0]we,
    input logic [WrNum-1:0][Width-1:0] din,
    input logic [RdNum-1:0][$clog2(Depth)-1:0] ra
  );

  // Select lvt_ram_nrnw or xor_ram_nrnw
  if ((RdNum < 2)&&(Width<8)||
      (Depth <= 16)&&(Width>64)) begin: g_xor
    xor_ram_nrnw
    #(.Width(Width), .Depth(Depth), .RdNum(RdNum), .WrNum(WrNum))
    ram (.dout(dout), .clk(clk), .wa(wa), .we(we), .din(din), .ra(ra) );
  end else begin: g_lvt
    lvt_ram_nrnw
    #(.Width(Width), .Depth(Depth), .RdNum(RdNum), .WrNum(WrNum))
    ram (.dout(dout), .clk(clk), .wa(wa), .we(we), .din(din), .ra(ra) );
  end

`define DEBUG
`ifdef DEBUG
  logic [Width-1:0] debug_rf[Depth];
  always_ff @(posedge clk)   begin
    for (int i=0; i<WrNum; i++) begin
        if (we[i])
            debug_rf[wa[i]] <= #1 din[i];
    end
  end
  logic [Width-1:0] debug_rdout[RdNum];

  for (genvar i=0; i<RdNum; i++) begin: debug_rd
    assign debug_rdout[i] = debug_rf[ra[i]];
    always @(posedge clk) begin
        if (dout[i] != debug_rf[ra[i]]) begin
           $display("dout[%d]=%x, debug_rf=%x, ra=%d", i, dout[i], debug_rf[ra[i]], ra[i]);
        end    
    end
  end
`endif

endmodule

module lvt_ram_nrnw
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1,
  parameter RdNum=1,
  parameter WrNum=1
  )  // Set a non-zero default
  (
    output logic [RdNum-1:0][Width-1:0] dout,
    input logic clk,
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,
    input logic [WrNum-1:0]we,
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

    xor_ram_nrnw
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

module xor_ram_nrnw
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1,
  parameter RdNum=1,
  parameter WrNum=1
  )  // Set a non-zero default
  (
    output logic [RdNum-1:0][Width-1:0] dout,
    input logic clk,
    input logic [WrNum-1:0][$clog2(Depth)-1:0] wa,
    input logic [WrNum-1:0]we,
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

module dist_ram_1r1w
#(parameter Width=8,  // Set a non-zero default
  parameter Depth=1)  // Set a non-zero default
  (
    output logic [Width-1:0] dout,
    input logic clk,
    input logic [$clog2(Depth)-1:0] wa,
    input logic we,
    input logic [Width-1:0] din,
    input logic [$clog2(Depth)-1:0] ra
  );

  logic [Width-1:0] rf[0:Depth-1];

  always_ff @(posedge clk) begin
    if (we) begin
      rf[wa] <= #1 din;
    end
  end
  assign dout = rf[ra];

endmodule

module tb_xor_ram_nrnw;

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
    .WrNum(WrNum)
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
