`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 03:06:04 PM
// Design Name: 
// Module Name: tb_fir_fixed_point
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


`timescale 1ns / 1ps

module tb_fir_fixed_point;

    logic clk = 0;
    logic reset = 1;
    logic sample_valid = 0;
    logic signed [7:0] sample_in = 0;

    logic signed [7:0] sample_out;
    logic output_valid;

    int errors = 0;
    int tests = 0;

    always #5 clk = ~clk;

    fir_fixed_point dut (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

    task automatic check_sample(
        input logic signed [7:0] data,
        input logic signed [7:0] expected
    );
        @(negedge clk);
        sample_in = data;
        sample_valid = 1;

        @(posedge clk);
        #1;

        tests++;

        if (output_valid !== 1'b1 ||
            sample_out !== expected) begin
            $error("FAIL: in=%0d expected=%0d got=%0d",
                   data, expected, sample_out);
            errors++;
        end
        else
            $display("PASS: in=%0d out=%0d",
                     data, sample_out);

        @(negedge clk);
        sample_valid = 0;
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;

        // Positive inputs
        check_sample(8, 1);
        check_sample(16, 5);
        check_sample(24, 12);
        check_sample(32, 20);
        
        check_sample(-8, 22);
        check_sample(-16, 10);
        check_sample(-24, -8);
        check_sample(-32, -20);

        // Verify no output when input is invalid
        @(negedge clk);
        sample_valid = 0;
        sample_in = 100;

        @(posedge clk);
        #1;

        tests++;
        if (output_valid !== 0 || sample_out !== -20) begin
            $error("FAIL: invalid sample changed output");
            errors++;
        end
        else
            $display("PASS: sample_valid gating");

        if (errors == 0)
            $display("ALL %0d FIR TESTS PASSED", tests);
        else
            $fatal(1, "%0d FIR TESTS FAILED", errors);

        $finish;
    end

endmodule
