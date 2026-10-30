`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:41:55 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    output logic [7:0] data_out,
    output logic data_valid
);

    // 100 MHz clock / 115200 baud ≈ 868
    localparam int CLKS_PER_BIT = 868;

    typedef enum logic [1:0] {
        IDLE, START, DATA, STOP
    } state_t;

    state_t state = IDLE;

    logic rx_meta, rx_sync;
    logic [9:0] clk_count = 0;
    logic [2:0] bit_index = 0;
    logic [7:0] rx_data = 0;

    // Synchronize asynchronous UART input
    always_ff @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_data <= 0;
            data_out <= 0;
            data_valid <= 0;
        end
        else begin
            data_valid <= 0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;

                    if (rx_sync == 0)
                        state <= START;
                end

                START: begin
                    if (clk_count == (CLKS_PER_BIT/2)-1) begin
                        clk_count <= 0;
                        if (rx_sync == 0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 0;
                        rx_data[bit_index] <= rx_sync;

                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 0;
                        state <= IDLE;

                        if (rx_sync == 1) begin
                            data_out <= rx_data;
                            data_valid <= 1;
                        end
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

