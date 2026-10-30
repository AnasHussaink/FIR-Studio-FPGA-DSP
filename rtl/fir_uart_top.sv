`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 05:14:46 PM
// Design Name: 
// Module Name: fir_uart_top
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


module fir_uart_top (
    input  logic clk,
    input  logic reset,
    input  logic uart_rx_pin,
    output logic uart_tx_pin
);

    // UART receiver signals
    logic [7:0] rx_data;
    logic rx_valid;

    // UART transmitter signals
    logic [7:0] tx_data;
    logic tx_start;
    logic tx_busy;

    // FIR signals
    logic signed [7:0] sample_in;
    logic sample_valid;
    logic signed [7:0] sample_out;
    logic output_valid;

    // Coefficient registers / inputs
    logic signed [7:0] c0, c1, c2, c3;
    logic coeff_load;

    // UART receiver
    uart_rx receiver (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_pin),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    // UART transmitter
    uart_tx transmitter (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .data_in(tx_data),
        .tx(uart_tx_pin),
        .tx_busy(tx_busy)
    );

    // Our programmable FIR accelerator
    fir_programmable fir (
        .clk(clk),
        .reset(reset),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .coeff_load(coeff_load),
        .coeff0(c0),
        .coeff1(c1),
        .coeff2(c2),
        .coeff3(c3),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

    typedef enum logic [3:0] {
        WAIT_CMD,
        WAIT_SAMPLE,
        WAIT_C0,
        WAIT_C1,
        WAIT_C2,
        WAIT_C3,
        LOAD_COEFF,
        WAIT_RESULT,
        SEND_REQUEST,
        WAIT_TX_BUSY,
        WAIT_TX_DONE
    } state_t;

    state_t state;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= WAIT_CMD;

            sample_in <= 0;
            sample_valid <= 0;
            coeff_load <= 0;

            c0 <= 0;
            c1 <= 0;
            c2 <= 0;
            c3 <= 0;

            tx_data <= 0;
            tx_start <= 0;
        end
        else begin

            // Default: one-clock control pulses
            sample_valid <= 0;
            coeff_load <= 0;
            tx_start <= 0;

            case (state)

                WAIT_CMD: begin
                    if (rx_valid) begin
                        if (rx_data == 8'h53)
                            state <= WAIT_SAMPLE;  // 'S'
                        else if (rx_data == 8'h43)
                            state <= WAIT_C0;      // 'C'
                    end
                end

                // Receive a single sample
                WAIT_SAMPLE: begin
                    if (rx_valid) begin
                        sample_in <= $signed(rx_data);
                        sample_valid <= 1;
                        state <= WAIT_RESULT;
                    end
                end

                // Receive four coefficients
                WAIT_C0: begin
                    if (rx_valid) begin
                        c0 <= $signed(rx_data);
                        state <= WAIT_C1;
                    end
                end

                WAIT_C1: begin
                    if (rx_valid) begin
                        c1 <= $signed(rx_data);
                        state <= WAIT_C2;
                    end
                end

                WAIT_C2: begin
                    if (rx_valid) begin
                        c2 <= $signed(rx_data);
                        state <= WAIT_C3;
                    end
                end

                WAIT_C3: begin
                    if (rx_valid) begin
                        c3 <= $signed(rx_data);
                        state <= LOAD_COEFF;
                    end
                end

                LOAD_COEFF: begin
                    coeff_load <= 1;
                    tx_data <= 8'h4B; // 'K' acknowledgement
                    state <= SEND_REQUEST;
                end

                // Wait for FIR pipeline output
                WAIT_RESULT: begin
                    if (output_valid) begin
                        tx_data <= sample_out;
                        state <= SEND_REQUEST;
                    end
                end

                // Start UART transmission
                SEND_REQUEST: begin
                    if (!tx_busy) begin
                        tx_start <= 1;
                        state <= WAIT_TX_BUSY;
                    end
                end

                WAIT_TX_BUSY: begin
                    if (tx_busy)
                        state <= WAIT_TX_DONE;
                end

                WAIT_TX_DONE: begin
                    if (!tx_busy)
                        state <= WAIT_CMD;
                end

                default: state <= WAIT_CMD;

            endcase
        end
    end

endmodule
