
import serial
import time

PORT = "COM5"
BAUD = 115200

with serial.Serial(PORT, BAUD, timeout=2) as ser:
    time.sleep(0.5)

    ser.reset_input_buffer()

    # Send ASCII 'A' to FPGA
    ser.write(b"A")
    print("Sent: A")

    # Read echoed byte
    response = ser.read(1)

    if response == b"A":
        print("PASS: FPGA returned A")
        print("REAL FPGA UART LOOPBACK SUCCESS!")
    else:
        print("FAIL: Unexpected response:", response)
