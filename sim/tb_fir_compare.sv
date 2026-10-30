`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 03:37:08 PM
// Design Name: 
// Module Name: tb_fir_compare
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

module tb_fir_compare;

    logic clk = 0;
    logic reset = 1;
    logic sample_valid = 0;
    logic signed [7:0] sample_in = 0;

    logic signed [7:0] base_out, pipe_out;
    logic base_valid, pipe_valid;

    always #5 clk = ~clk;

    // Original architecture
    fir_fixed_point baseline (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(base_out),
        .output_valid(base_valid)
    );

    // Pipelined architecture
    fir_pipelined pipelined (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(pipe_out),
        .output_valid(pipe_valid)
    );

    // Independent mathematical reference
    integer x0 = 0, x1 = 0, x2 = 0;
    integer result;
    integer exp1 = 0, exp2 = 0;
    bit v1 = 0, v2 = 0;

    integer errors = 0;
    integer checks = 0;

    always @(posedge clk) begin
        if (reset) begin
            x0 = 0;
            x1 = 0;
            x2 = 0;
            exp1 = 0;
            exp2 = 0;
            v1 = 0;
            v2 = 0;

            #1;
            if (base_valid !== 0 ||
                pipe_valid !== 0) begin
                $error("Reset validity check failed");
                errors++;
            end
        end
        else begin
            // Calculate before updating history
            result = (16 * $signed(sample_in)
                    + 48 * x0
                    + 48 * x1
                    + 16 * x2) >>> 7;

            // Wait until RTL registers update
            #1;

            checks++;

            if (base_valid !== sample_valid) begin
                $error("Baseline valid mismatch");
                errors++;
            end

            if (sample_valid && base_out !== result) begin
                $error("Baseline: expected=%0d got=%0d",
                       result, base_out);
                errors++;
            end

            if (pipe_valid !== v2) begin
                $error("Pipeline valid mismatch");
                errors++;
            end

            if (v2 && pipe_out !== exp2) begin
                $error("Pipeline: expected=%0d got=%0d",
                       exp2, pipe_out);
                errors++;
            end

            // Advance reference pipeline
            exp2 = exp1;
            exp1 = result;

            v2 = v1;
            v1 = sample_valid;

            if (sample_valid) begin
                x2 = x1;
                x1 = x0;
                x0 = $signed(sample_in);
            end
        end
    end

    task automatic send(
        input logic signed [7:0] data,
        input bit valid
    );
        @(negedge clk);
        sample_in = data;
        sample_valid = valid;
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;

        // Continuous positive and negative samples
        send(8, 1);
        send(16, 1);
        send(24, 1);
        send(32, 1);
        send(-8, 1);
        send(-16, 1);
        send(-24, 1);
        send(-32, 1);

        // Invalid gaps
        send(100, 0);
        send(-100, 0);

        // Boundary and mixed-value cases
        send(127, 1);
        send(-128, 1);
        send(0, 1);
        send(50, 1);
        send(-50, 1);

        // Flush the pipeline
        repeat (5) send(0, 0);

        #2;

        if (errors == 0)
            $display("ALL %0d COMPARISON CHECKS PASSED",
                     checks);
        else
            $fatal(1, "%0d COMPARISON ERRORS", errors);

        $finish;
    end

endmodule
