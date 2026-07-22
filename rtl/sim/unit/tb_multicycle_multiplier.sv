`timescale 1ns/1ps

module tb_multicycle_multiplier;

  localparam int ITERATIONS = 32;
  localparam logic [3:0]
    ALU_MUL    = 4'b1010,
    ALU_MULH   = 4'b1011,
    ALU_MULHSU = 4'b1100,
    ALU_MULHU  = 4'b1101;

  logic clk, arst_n, start, consume;
  logic [31:0] operand_a, operand_b, result;
  logic [3:0] alu_ctrl;
  logic busy, done;
  int test_count;

  iterative_multiplier #(.N(32)) dut (
    .i_clk(clk),
    .i_arst_n(arst_n),
    .i_start(start),
    .i_consume(consume),
    .i_operand_a(operand_a),
    .i_operand_b(operand_b),
    .i_alu_ctrl(alu_ctrl),
    .o_busy(busy),
    .o_done(done),
    .o_result(result)
  );

  always #5 clk = ~clk;

  task automatic run_mul(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0]  op,
    input logic [31:0] expected
  );
    int elapsed_cycles;
    begin
      @(negedge clk);
      operand_a = a;
      operand_b = b;
      alu_ctrl  = op;
      start     = 1'b1;
      @(negedge clk);
      start = 1'b0;

      elapsed_cycles = 0;
      do begin
        @(posedge clk);
        elapsed_cycles++;
      end while (!done);
      if (elapsed_cycles != ITERATIONS)
        $fatal(1, "Unexpected iterative latency=%0d, expected=%0d",
               elapsed_cycles, ITERATIONS);
      #1;
      if (result !== expected)
        $fatal(1, "MUL op=%h a=%h b=%h result=%h expected=%h",
               op, a, b, result, expected);

      // A downstream bus stall may delay consumption.  The completed result
      // and done indication must remain stable until the core advances EX.
      repeat (2) begin
        @(posedge clk);
        #1;
        if (!done || !busy || (result !== expected))
          $fatal(1, "Completed result was not held before consume");
      end
      @(negedge clk);
      consume = 1'b1;
      @(negedge clk);
      consume = 1'b0;
      test_count++;
    end
  endtask

  initial begin
    clk       = 1'b0;
    arst_n    = 1'b0;
    start     = 1'b0;
    consume   = 1'b0;
    operand_a = '0;
    operand_b = '0;
    alu_ctrl  = ALU_MUL;
    test_count = 0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    arst_n = 1'b1;

    run_mul(-32'sd3, 32'd7, ALU_MUL, 32'hffff_ffeb);
    run_mul(-32'sd2, 32'd3, ALU_MULH, 32'hffff_ffff);
    run_mul(-32'sd2, 32'hffff_ffff, ALU_MULHSU, 32'hffff_fffe);
    run_mul(32'hffff_ffff, 32'hffff_ffff, ALU_MULHU, 32'hffff_fffe);
    run_mul(32'h8000_0000, 32'hffff_ffff, ALU_MULH, 32'h0000_0000);
    run_mul(32'h8000_0000, 32'hffff_ffff, ALU_MULHSU, 32'h8000_0000);
    run_mul(32'h8000_0000, 32'd2, ALU_MULHU, 32'h0000_0001);
    run_mul(32'hffff_ffff, 32'hffff_ffff, ALU_MUL, 32'h0000_0001);

    $display("*** MULTICYCLE MULTIPLIER TEST PASSED ***");
    $display("Verified %0d radix-2 operations at latency %0d",
             test_count, ITERATIONS);
    $finish;
  end

  initial begin
    repeat (400) @(posedge clk);
    $fatal(1, "Timeout waiting for multicycle multiplier test");
  end

endmodule
