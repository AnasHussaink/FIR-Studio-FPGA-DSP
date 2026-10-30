`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:23:22 PM
// Design Name: 
// Module Name: fir_programmable
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


module fir_programmable (
    input  logic clk,
    input  logic reset,
    input  logic sample_valid,

    input  logic signed [7:0] sample_in,

    input  logic coeff_load,
    input  logic signed [7:0] coeff0,
    input  logic signed [7:0] coeff1,
    input  logic signed [7:0] coeff2,
    input  logic signed [7:0] coeff3,

    output logic signed [7:0] sample_out,
    output logic output_valid
);

    // Runtime-programmable coefficient registers
    logic signed [7:0] h0, h1, h2, h3;

    // Sample history
    logic signed [7:0] x0, x1, x2;

    // Stage 1: Products
    logic signed [15:0] p0, p1, p2, p3;

    // Stage 2: Partial sums
    logic signed [16:0] s0, s1;

    // Pipeline validity
    logic v1, v2;

    // Widened final sum
    logic signed [17:0] total;

    assign total = {{1{s0[16]}}, s0}
                 + {{1{s1[16]}}, s1};

    always_ff @(posedge clk) begin
        if (reset) begin
            // Default Q1.7 smoothing coefficients
            h0 <= 8'sd16;
            h1 <= 8'sd48;
            h2 <= 8'sd48;
            h3 <= 8'sd16;

            x0 <= '0;
            x1 <= '0;
            x2 <= '0;

            p0 <= '0;
            p1 <= '0;
            p2 <= '0;
            p3 <= '0;

            s0 <= '0;
            s1 <= '0;

            sample_out <= '0;
            output_valid <= 1'b0;
            v1 <= 1'b0;
            v2 <= 1'b0;
        end
        else begin

            // Update coefficients only when requested
            if (coeff_load) begin
                h0 <= coeff0;
                h1 <= coeff1;
                h2 <= coeff2;
                h3 <= coeff3;
            end

            // Update sample history
            if (sample_valid) begin
                x0 <= sample_in;
                x1 <= x0;
                x2 <= x1;
            end

            // Pipeline stage 1: Multiplication
            v1 <= sample_valid;

            if (sample_valid) begin
                p0 <= sample_in * h0;
                p1 <= x0 * h1;
                p2 <= x1 * h2;
                p3 <= x2 * h3;
            end

            // Pipeline stage 2: Pairwise addition
            v2 <= v1;

            if (v1) begin
                s0 <= $signed({p0[15], p0})
                    + $signed({p1[15], p1});

                s1 <= $signed({p2[15], p2})
                    + $signed({p3[15], p3});
            end

            // Pipeline stage 3: Final output
            output_valid <= v2;

            if (v2)
                sample_out <= 8'(total >>> 7);

        end
    end

endmodule

