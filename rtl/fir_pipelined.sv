`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 03:34:52 PM
// Design Name: 
// Module Name: fir_pipelined
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


module fir_pipelined (
    input  logic clk,
    input  logic reset,
    input  logic sample_valid,
    input  logic signed [7:0] sample_in,
    output logic signed [7:0] sample_out,
    output logic output_valid
);

    localparam logic signed [7:0] H0 = 8'sd16;
    localparam logic signed [7:0] H1 = 8'sd48;
    localparam logic signed [7:0] H2 = 8'sd48;
    localparam logic signed [7:0] H3 = 8'sd16;

    logic signed [7:0] x0, x1, x2;

    // Stage 1: Registered products
    logic signed [15:0] p0, p1, p2, p3;

    // Stage 2: Registered partial sums
    logic signed [16:0] s0, s1;

    // Valid signal pipeline
    logic v1, v2;

    always_ff @(posedge clk) begin
        if (reset) begin
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

            v1 <= 0;
            v2 <= 0;
            output_valid <= 0;
        end
        else begin
            // Shift input history only for valid samples
            if (sample_valid) begin
                x0 <= sample_in;
                x1 <= x0;
                x2 <= x1;
            end

            // Stage 1: Multiply
            v1 <= sample_valid;

            if (sample_valid) begin
                p0 <= sample_in * H0;
                p1 <= x0 * H1;
                p2 <= x1 * H2;
                p3 <= x2 * H3;
            end

            // Stage 2: Add pairs
            v2 <= v1;

            if (v1) begin
                s0 <= $signed(p0) + $signed(p1);
                s1 <= $signed(p2) + $signed(p3);
            end

            // Stage 3: Final sum and scaling
            output_valid <= v2;

            if (v2) begin
                sample_out <= 8'(($signed(s0) + $signed(s1)) >>> 7);
            end
        end
    end

endmodule
