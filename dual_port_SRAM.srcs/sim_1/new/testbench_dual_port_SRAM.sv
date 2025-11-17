`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.11.2025 16:05:49
// Design Name: 
// Module Name: testbench_dual_port_SRAM
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




module testbench_dual_port_SRAM ();

  // parameters -- match DUT
  parameter ADDR_WIDTH = 6;
  parameter DATA_WIDTH = 32;
  parameter DEPTH      = (1 << ADDR_WIDTH);

  reg                     clk;
  reg                     rst_n;

  // PORT A
  reg                     we_a_n;
  reg  [ADDR_WIDTH-1:0]   addr_a;
  reg  [DATA_WIDTH-1:0]   din_a;
  wire [DATA_WIDTH-1:0]   dout_a;

  // PORT B
  reg                     we_b_n;
  reg  [ADDR_WIDTH-1:0]   addr_b;
  reg  [DATA_WIDTH-1:0]   din_b;
  wire [DATA_WIDTH-1:0]   dout_b;

  // DUT instantiation
  dual_port_SRAM #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),

    .we_a_n  (we_a_n),
    .addr_a  (addr_a),
    .din_a   (din_a),
    .dout_a  (dout_a),

    .we_b_n  (we_b_n),
    .addr_b  (addr_b),
    .din_b   (din_b),
    .dout_b  (dout_b)
  );

  // bookkeeping
  integer i;
  integer errors = 0;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;   // 100MHz
  end

`ifdef VCD
  initial begin
    $dumpfile("tb_dual_port_SRAM.vcd");
    $dumpvars(0, tb_dual_port_SRAM);
  end
`endif

  // Reset & top-level sequencing
  initial begin
    rst_n = 0;

    we_a_n = 1;
    we_b_n = 1;
    addr_a = '0;
    addr_b = '0;
    din_a  = '0;
    din_b  = '0;

    #25 rst_n = 1;
    repeat (2) @(posedge clk);

    deterministic_test();
    randomized_test(800);

    summary_and_finish();
  end

  // ============================
  // Deterministic test
  // ============================
  task deterministic_test();
    begin
      $display("[%0t] --- Deterministic test start", $time);

      // Write pattern on BOTH ports
      for (i = 0; i < DEPTH; i = i + 1) begin
        // PORT A: addr=i
        @(negedge clk);
        we_a_n = 0;
        addr_a = i;
        din_a  = 32'hA000_0000 + i;

        // PORT B: addr=(DEPTH-1-i)
        we_b_n = 0;
        addr_b = DEPTH - 1 - i;
        din_b  = 32'hB000_0000 + (DEPTH - 1 - i);

        @(posedge clk);
        @(posedge clk);    // read latency
      end

      // Disable writes
      we_a_n = 1;
      we_b_n = 1;

      repeat (2) @(posedge clk);

      // Read-back test
      for (i = 0; i < DEPTH; i = i + 1) begin
        @(negedge clk);
        addr_a = i;
        addr_b = DEPTH - 1 - i;

        @(posedge clk);
        @(posedge clk);

        if (dout_a !== (32'hA000_0000 + i)) begin
          $display("[%0t] ERROR A: addr=%0d expected=%0h got=%0h",
                    $time, i, (32'hA000_0000 + i), dout_a);
          errors++;
        end

        if (dout_b !== (32'hB000_0000 + (DEPTH-1-i))) begin
          $display("[%0t] ERROR B: addr=%0d expected=%0h got=%0h",
                   $time, (DEPTH-1-i), 
                   (32'hB000_0000 + (DEPTH-1-i)), dout_b);
          errors++;
        end
      end

      $display("[%0t] --- Deterministic test done", $time);
    end
  endtask


  // ============================
  // Randomized test
  // ============================
  task randomized_test(input integer cycles);
    reg [DATA_WIDTH-1:0] golden [0:DEPTH-1];
    integer k;

    // For latency compensation
    reg [ADDR_WIDTH-1:0] addr_a_q, addr_b_q;
    reg is_read_a_q, is_read_b_q;

    begin
      // Init golden model using deterministic pattern
      for (k = 0; k < DEPTH; k++)
        golden[k] = 32'hA000_0000 + k;

      addr_a_q = 0;
      addr_b_q = 0;
      is_read_a_q = 0;
      is_read_b_q = 0;

      $display("[%0t] --- Randomized test start (%0d ops)", $time, cycles);

      for (k = 0; k < cycles; k++) begin
        @(negedge clk);

        // 30% write, 70% read
        if ($urandom_range(0,9) < 3) begin
          // WRITE on A
          we_a_n = 0;
          addr_a = $urandom_range(0, DEPTH-1);
          din_a  = $urandom();
          golden[addr_a] = din_a;
          is_read_a_q = 0;
        end else begin
          // READ on A
          we_a_n = 1;
          addr_a = $urandom_range(0, DEPTH-1);
          is_read_a_q = 1;
        end

        if ($urandom_range(0,9) < 3) begin
          // WRITE on B
          we_b_n = 0;
          addr_b = $urandom_range(0, DEPTH-1);
          din_b  = $urandom();
          golden[addr_b] = din_b;
          is_read_b_q = 0;
        end else begin
          // READ on B
          we_b_n = 1;
          addr_b = $urandom_range(0, DEPTH-1);
          is_read_b_q = 1;
        end

        @(posedge clk);

        // capture for next cycle
        addr_a_q = addr_a;
        addr_b_q = addr_b;

        @(posedge clk);

        if (is_read_a_q && dout_a !== golden[addr_a_q]) begin
          $display("[%0t] ERROR RAND A: addr=%0d expected=%0h got=%0h",
                   $time, addr_a_q, golden[addr_a_q], dout_a);
          errors++;
        end

        if (is_read_b_q && dout_b !== golden[addr_b_q]) begin
          $display("[%0t] ERROR RAND B: addr=%0d expected=%0h got=%0h",
                   $time, addr_b_q, golden[addr_b_q], dout_b);
          errors++;
        end
      end

      $display("[%0t] --- Randomized test done", $time);
    end
  endtask


  // ============================
  // Safety assertion
  // ============================
  reg we_a_prev, we_b_prev;

  always @(posedge clk) begin
    we_a_prev <= we_a_n;
    we_b_prev <= we_b_n;
  end

  property we_no_glitch_A; @(posedge clk) we_a_n == we_a_prev; endproperty
  property we_no_glitch_B; @(posedge clk) we_b_n == we_b_prev; endproperty

  assert property (we_no_glitch_A)
    else $error("[%0t] WE glitch on port A!", $time);

  assert property (we_no_glitch_B)
    else $error("[%0t] WE glitch on port B!", $time);


  // ============================
  // Summary
  // ============================
  task summary_and_finish();
    begin
      #20;
      if (errors == 0)
        $display("[%0t] TEST PASSED: no errors", $time);
      else
        $display("[%0t] TEST FAILED: %0d errors", $time, errors);
      $finish;
    end
  endtask

endmodule
