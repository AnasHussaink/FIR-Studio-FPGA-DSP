`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:15:15 PM
// Design Name: 
// Module Name: tb_fir_python
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

module tb_fir_python;

    logic clk = 0;
    logic reset = 1;
    logic sample_valid = 0;
    logic signed [7:0] sample_in = 0;

    logic signed [7:0] base_out, pipe_out;
    logic base_valid, pipe_valid;

    always #5 clk = ~clk;

    fir_fixed_point baseline (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(base_out),
        .output_valid(base_valid)
    );

    fir_pipelined pipelined (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .sample_out(pipe_out),
        .output_valid(pipe_valid)
    );

    integer file_handle;
    integer read_count;
    integer data_in, valid_in, expected_in;

    integer vectors = 0;
    integer checks = 0;
    integer errors = 0;

    // Golden reference values moving through pipeline
    integer expected_stage1 = 0;
    integer expected_stage2 = 0;
    integer last_base = 0;
    integer last_pipe = 0;

    bit valid_stage1 = 0;
    bit valid_stage2 = 0;

    task automatic check_cycle(
        input integer data,
        input integer valid,
        input integer expected
    );
        @(negedge clk);
        sample_in = 8'(data);
        sample_valid = 1'(valid);

        @(posedge clk);
        #1;  // Allow RTL nonblocking assignments to update

        // Check original FIR
        checks++;

        if (base_valid !== 1'(valid)) begin
            $error("Baseline valid mismatch");
            errors++;
        end

        if (valid != 0)
            last_base = expected;

        if ($signed(base_out) !== last_base) begin
            $error("Baseline: expected=%0d got=%0d",
                   last_base, $signed(base_out));
            errors++;
        end

        // Check pipelined FIR using delayed expectation
        checks++;

        if (pipe_valid !== valid_stage2) begin
            $error("Pipeline valid mismatch");
            errors++;
        end

        if (valid_stage2)
            last_pipe = expected_stage2;

        if ($signed(pipe_out) !== last_pipe) begin
            $error("Pipeline: expected=%0d got=%0d",
                   last_pipe, $signed(pipe_out));
            errors++;
        end

        // Advance golden reference pipeline
        expected_stage2 = expected_stage1;
        expected_stage1 = expected;

        valid_stage2 = valid_stage1;
        valid_stage1 = (valid != 0);
    endtask

    initial begin

        // Reset both designs
        repeat (2) @(negedge clk);
        reset = 0;

        // Read Python-generated data
        file_handle = $fopen(
            "fir_vectors.txt",
            "r"
        );

        if (file_handle == 0)
            $fatal(1, "Cannot open fir_vectors.txt");

        while (!$feof(file_handle)) begin
            read_count = $fscanf(
                file_handle, "%d %d %d\n",
                data_in, valid_in, expected_in
            );

            if (read_count == 3) begin
                check_cycle(data_in, valid_in, expected_in);
                vectors++;
            end
            else if (read_count != -1) begin
                $fatal(1, "Malformed test-vector file");
            end
        end

        $fclose(file_handle);

        // Flush final results through pipeline
        repeat (3)
            check_cycle(0, 0, last_base);

        if (errors == 0)
            $display(
                "ALL PYTHON FIR TESTS PASSED: %0d vectors, %0d checks",
                vectors, checks
            );
        else
            $fatal(1, "FAILED: %0d errors", errors);

        $finish;
    end

endmodule
