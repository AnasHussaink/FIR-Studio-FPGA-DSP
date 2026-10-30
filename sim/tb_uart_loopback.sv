`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 04:49:33 PM
// Design Name: 
// Module Name: tb_uart_loopback
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




module tb_uart_loopback;

    logic clk = 0;
    logic reset = 1;
    logic uart_rx_pin = 1;
    logic uart_tx_pin;

    localparam int BIT_TIME = 8680; // ns at 115200 baud

    always #5 clk = ~clk;  // 100 MHz

    uart_loopback_top dut (
        .clk(clk),
        .reset(reset),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin)
    );

    // Simulate the PC sending a UART byte
    task automatic send_byte(input logic [7:0] data);
        uart_rx_pin = 0;  // Start bit
        #BIT_TIME;

        for (int i = 0; i < 8; i++) begin
            uart_rx_pin = data[i];
            #BIT_TIME;
        end

        uart_rx_pin = 1;  // Stop bit
        #BIT_TIME;
    endtask

    // Receive and check the FPGA's UART reply
    task automatic check_reply(input logic [7:0] expected);
        logic [7:0] received;

        @(negedge uart_tx_pin);
        #(BIT_TIME + BIT_TIME/2);

        for (int i = 0; i < 8; i++) begin
            received[i] = uart_tx_pin;
            #BIT_TIME;
        end

        if (received === expected)
            $display("PASS: received %c (%0d)",
                     received, received);
        else
            $fatal(1, "FAIL: expected=%0d got=%0d",
                   expected, received);
    endtask

    initial begin
        repeat (5) @(posedge clk);
        @(negedge clk);
        reset = 0;

        fork
            send_byte(8'd65);   // ASCII 'A'
            check_reply(8'd65);
        join

        $display("UART LOOPBACK TEST PASSED");
        $finish;
    end

    initial begin
        #300000; // 300 us safety timeout
        $fatal(1, "UART simulation timeout");
    end

endmodule
