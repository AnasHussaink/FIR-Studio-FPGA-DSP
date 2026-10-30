`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:24:43 PM
// Design Name: 
// Module Name: tb_fir_programmable
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


module tb_fir_programmable;

    logic clk = 0;
    logic reset = 1;
    logic sample_valid = 0;
    logic signed [7:0] sample_in = 0;

    logic coeff_load = 0;
    logic signed [7:0] coeff0 = 0;
    logic signed [7:0] coeff1 = 0;
    logic signed [7:0] coeff2 = 0;
    logic signed [7:0] coeff3 = 0;

    logic signed [7:0] sample_out;
    logic output_valid;

    int errors = 0;
    int checks = 0;

    // 100 MHz clock
    always #5 clk = ~clk;

    fir_programmable dut (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .coeff_load(coeff_load),
        .coeff0(coeff0),
        .coeff1(coeff1),
        .coeff2(coeff2),
        .coeff3(coeff3),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

    // Reference model state
    int x0 = 0, x1 = 0, x2 = 0;
    int h0 = 16, h1 = 48, h2 = 48, h3 = 16;

    int exp1 = 0, exp2 = 0;
    bit v1 = 0, v2 = 0;
    int expected_output = 0;

    // Check at every clock edge
    always @(posedge clk) begin
        if (reset) begin
            x0 = 0; x1 = 0; x2 = 0;
            h0 = 16; h1 = 48; h2 = 48; h3 = 16;
            exp1 = 0; exp2 = 0;
            v1 = 0; v2 = 0;
            expected_output = 0;
        end
        else begin
            // Predict output from OLD pipeline state
            if (v2)
                expected_output = exp2;

            // Check DUT after nonblocking assignments
            #1;
            checks++;

            if (output_valid !== v2 ||
                $signed(sample_out) !== expected_output) begin
                $error(
                    "FAIL at %0t: expected=%0d actual=%0d",
                    $time, expected_output, $signed(sample_out)
                );
                errors++;
            end

            // Advance reference pipeline
            exp2 = exp1;
            v2 = v1;

            // Calculate from OLD coefficients and history
            if (sample_valid) begin
                exp1 = (h0 * $signed(sample_in)
                      + h1 * x0
                      + h2 * x1
                      + h3 * x2) >>> 7;

                x2 = x1;
                x1 = x0;
                x0 = $signed(sample_in);
            end

            v1 = sample_valid;

            // New coefficients take effect NEXT cycle
            if (coeff_load) begin
                h0 = $signed(coeff0);
                h1 = $signed(coeff1);
                h2 = $signed(coeff2);
                h3 = $signed(coeff3);
            end
        end
    end

    task automatic send_sample(
        input logic signed [7:0] value
    );
        @(negedge clk);
        sample_in = value;
        sample_valid = 1;
    endtask

    initial begin
        // Hold reset across two rising edges
        repeat (2) @(negedge clk);
        reset = 0;

        // Test A: Default smoothing coefficients
        send_sample(8);
        send_sample(16);
        send_sample(24);
        send_sample(32);

        // Stop input while changing coefficients
        @(negedge clk);
        sample_valid = 0;
        coeff_load = 1;
        coeff0 = 32;
        coeff1 = 32;
        coeff2 = 32;
        coeff3 = 32;

        @(negedge clk);
        coeff_load = 0;

        // Test B: Equal-weight moving average
        send_sample(40);
        send_sample(48);
        send_sample(56);
        send_sample(64);

        // Flush remaining pipeline results
        @(negedge clk);
        sample_valid = 0;
        repeat (5) @(negedge clk);
        #2;

        if (errors == 0)
            $display(
                "ALL PROGRAMMABLE FIR CHECKS PASSED: %0d cycles",
                checks
            );
        else
            $fatal(1, "FAILED: %0d errors", errors);

        $finish;
    end

endmodule
