`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 02:16:37 PM
// Design Name: 
// Module Name: fir_moving_average
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



module fir_moving_average #(
    parameter int WIDTH = 8
)(
    input  logic clk,
    input  logic reset,
    input  logic sample_valid,
    input  logic [WIDTH-1:0] sample_in,
    output logic [WIDTH-1:0] sample_out,
    output logic output_valid
);

logic [WIDTH-1:0] x0, x1, x2, x3;
logic [WIDTH+1:0] sum;

assign sum = {2'b00, sample_in}
           + {2'b00, x0}
           + {2'b00, x1}
           + {2'b00, x2};

always_ff @(posedge clk) begin
    if (reset) begin
        x0 <= '0;
        x1 <= '0;
        x2 <= '0;
        x3 <= '0;
        sample_out <= '0;
        output_valid <= 1'b0;
    end
    else begin
        output_valid <= sample_valid;

        if (sample_valid) begin
            x0 <= sample_in;
            x1 <= x0;
            x2 <= x1;
            x3 <= x2;

            sample_out <= sum >> 2;
        end
    end
end

endmodule
