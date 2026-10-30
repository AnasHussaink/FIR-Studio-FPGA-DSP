`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 02:20:29 PM
// Design Name: 
// Module Name: tb_fir_moving_average
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


module tb_fir_moving_average;

    logic clk = 0;
    logic reset = 1;
    logic sample_valid = 0;
    logic [7:0] sample_in = 0;

    logic [7:0] sample_out;
    logic output_valid;

    int errors = 0;

    // 100 MHz clock
    always #5 clk = ~clk;

    // Device Under Test
    fir_moving_average #(
        .WIDTH(8)
    ) dut (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

    // Apply one sample and verify the result
    task automatic send_sample(
        input logic [7:0] data,
        input logic [7:0] expected
    );
        @(negedge clk);
        sample_in = data;
        sample_valid = 1;

        @(posedge clk);
        #1;

        if (output_valid !== 1'b1 ||
            sample_out !== expected) begin
            $error("FAIL: input=%0d expected=%0d actual=%0d",
                   data, expected, sample_out);
            errors++;
        end
        else
            $display("PASS: input=%0d output=%0d",
                     data, sample_out);

        @(negedge clk);
        sample_valid = 0;
    endtask

    initial begin
        // Reset the FIR registers
        repeat (2) @(negedge clk);
        reset = 0;

        // Expected values use the PREVIOUS four samples
        send_sample(8,  2);
        send_sample(12, 5);
        send_sample(16, 9);
        send_sample(20, 14);
        send_sample(24, 18);
        send_sample(28, 22);
        

        if (errors == 0)
            $display("ALL FIR TESTS PASSED");
        else
            $fatal(1, "FIR TEST FAILED: %0d errors", errors);

        $finish;
    end

endmodule
