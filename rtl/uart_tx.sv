`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:42:58 PM
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
    input  logic clk,
    input  logic reset,
    input  logic tx_start,
    input  logic [7:0] data_in,
    output logic tx,
    output logic tx_busy
);

    // 100 MHz clock / 115200 baud
    localparam int CLKS_PER_BIT = 868;

    typedef enum logic [1:0] {
        IDLE, START, DATA, STOP
    } state_t;

    state_t state;

    logic [9:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] tx_data;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            tx_data <= 0;
        end
        else begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (tx_start) begin
                        tx_data <= data_in;
                        tx_busy <= 1'b1;
                        tx <= 1'b0;
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 0;
                        tx <= tx_data[0];
                        state <= DATA;
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 0;

                        if (bit_index == 7) begin
                            tx <= 1'b1;
                            state <= STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1;
                            tx <= tx_data[bit_index + 1'b1];
                        end
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 0;
                        tx_busy <= 1'b0;
                        state <= IDLE;
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule

