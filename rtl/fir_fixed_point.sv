`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 02:59:14 PM
// Design Name: 
// Module Name: fir_fixed_point
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


module fir_fixed_point (
    input  logic clk,
    input  logic reset,
    input  logic sample_valid,
    input  logic signed [7:0] sample_in,
    output logic signed [7:0] sample_out,
    output logic output_valid
);

    // Q1.7 coefficients
    localparam logic signed [7:0] H0 = 8'sd16;
    localparam logic signed [7:0] H1 = 8'sd48;
    localparam logic signed [7:0] H2 = 8'sd48;
    localparam logic signed [7:0] H3 = 8'sd16;

    // Previous three samples
    logic signed [7:0] x0, x1, x2;

    // Full precision multiplication
    logic signed [15:0] p0, p1, p2, p3;

    // Accumulator with headroom
    logic signed [17:0] sum;

    assign p0 = sample_in * H0;
    assign p1 = x0 * H1;
    assign p2 = x1 * H2;
    assign p3 = x2 * H3;

    assign sum = {{2{p0[15]}}, p0}
               + {{2{p1[15]}}, p1}
               + {{2{p2[15]}}, p2}
               + {{2{p3[15]}}, p3};

    always_ff @(posedge clk) begin
        if (reset) begin
            x0 <= '0;
            x1 <= '0;
            x2 <= '0;
            sample_out <= '0;
            output_valid <= 1'b0;
        end
        else begin
            output_valid <= sample_valid;

            if (sample_valid) begin
                x0 <= sample_in;
                x1 <= x0;
                x2 <= x1;

                sample_out <= 8'(sum >>> 7);
            end
        end
    end

endmodule
