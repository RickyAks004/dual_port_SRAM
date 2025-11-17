`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.11.2025 16:03:02
// Design Name: 
// Module Name: dual_port_SRAM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////




// dual_port_SRAM.v
// Simple dual-port RAM: Port A (R/W), Port B (R/W)
// Both ports are synchronous and independent. If both write same address same cycle, Port A wins.
// Behavioral only - good for testbenches / verification.


module dual_port_SRAM #(
  parameter ADDR_WIDTH = 6,
  parameter DATA_WIDTH = 32
)(
  input  wire                    clk,
  input  wire                    rst_n,

  // Port A
  input  wire                    we_a_n,
  input  wire [ADDR_WIDTH-1:0]   addr_a,
  input  wire [DATA_WIDTH-1:0]   din_a,
  output reg  [DATA_WIDTH-1:0]   dout_a,

  // Port B
  input  wire                    we_b_n,
  input  wire [ADDR_WIDTH-1:0]   addr_b,
  input  wire [DATA_WIDTH-1:0]   din_b,
  output reg  [DATA_WIDTH-1:0]   dout_b
);

  localparam DEPTH = (1 << ADDR_WIDTH);
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  reg [ADDR_WIDTH-1:0] addr_a_r, addr_b_r;
  reg                  we_a_r, we_b_r;
  reg [DATA_WIDTH-1:0] din_a_r, din_b_r;

  integer i;
  initial begin
    for (i = 0; i < DEPTH; i = i+1) mem[i] = {DATA_WIDTH{1'b0}};
    dout_a = {DATA_WIDTH{1'b0}};
    dout_b = {DATA_WIDTH{1'b0}};
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_a_r <= {ADDR_WIDTH{1'b0}};
      addr_b_r <= {ADDR_WIDTH{1'b0}};
      we_a_r   <= 1'b1;
      we_b_r   <= 1'b1;
      din_a_r  <= {DATA_WIDTH{1'b0}};
      din_b_r  <= {DATA_WIDTH{1'b0}};
      dout_a   <= {DATA_WIDTH{1'b0}};
      dout_b   <= {DATA_WIDTH{1'b0}};
    end else begin
      // register inputs
      addr_a_r <= addr_a;
      addr_b_r <= addr_b;
      we_a_r   <= we_a_n;
      we_b_r   <= we_b_n;
      din_a_r  <= din_a;
      din_b_r  <= din_b;

      // process writes - simple arbitration: A before B
      if (we_a_r == 1'b0) mem[addr_a_r] <= din_a_r;
      if (we_b_r == 1'b0) begin
        if (!(we_a_r == 1'b0 && addr_a_r == addr_b_r)) // if A wrote same location this cycle, A wins
          mem[addr_b_r] <= din_b_r;
      end

      // read outputs
      dout_a <= mem[addr_a_r];
      dout_b <= mem[addr_b_r];
    end
  end

endmodule