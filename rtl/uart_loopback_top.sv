`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:44:23 PM
// Design Name: 
// Module Name: uart_loopback_top
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

module uart_loopback_top (
    input  logic clk,
    input  logic reset,
    input  logic uart_rx_pin,
    output logic uart_tx_pin
);

    logic [7:0] rx_data;
    logic rx_valid;

    logic [7:0] tx_data;
    logic tx_start;
    logic tx_busy;

    typedef enum logic [1:0] {
        WAIT_RX,
        SEND_BYTE,
        WAIT_TX_START,
        WAIT_TX_DONE
    } state_t;

    state_t state;

    uart_rx receiver (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_pin),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    uart_tx transmitter (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .data_in(tx_data),
        .tx(uart_tx_pin),
        .tx_busy(tx_busy)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= WAIT_RX;
            tx_data <= 0;
            tx_start <= 0;
        end
        else begin
            // Default: transmit request is a one-clock pulse
            tx_start <= 0;

            case (state)
                WAIT_RX: begin
                    if (rx_valid) begin
                        tx_data <= rx_data;
                        state <= SEND_BYTE;
                    end
                end

                SEND_BYTE: begin
                    if (!tx_busy) begin
                        tx_start <= 1;
                        state <= WAIT_TX_START;
                    end
                end

                WAIT_TX_START: begin
                    if (tx_busy)
                        state <= WAIT_TX_DONE;
                end

                WAIT_TX_DONE: begin
                    if (!tx_busy)
                        state <= WAIT_RX;
                end

                default: state <= WAIT_RX;
            endcase
        end
    end

endmodule
