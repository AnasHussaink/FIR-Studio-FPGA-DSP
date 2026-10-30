
import serial
import time

PORT = "COM5"
BAUD = 115200

# Q1.7 equal-weight coefficients
coefficients = [32, 32, 32, 32]
history = [0, 0, 0]

def send_sample(ser, sample):
    global history

    values = [sample] + history
    total = sum(c * x for c, x in zip(coefficients, values))
    expected = total // 128

    # Send sample command + signed 8-bit value
    ser.write(b"S" + bytes([sample & 0xFF]))

    response = ser.read(1)
    if len(response) != 1:
        raise RuntimeError("FPGA sample response timeout")

    actual = int.from_bytes(response, "little", signed=True)

    status = "PASS" if actual == expected else "FAIL"
    print(
        f"Input={sample:4d} | Expected={expected:4d} | "
        f"FPGA={actual:4d} | {status}"
    )

    history = [sample] + history[:2]
    return actual == expected


with serial.Serial(PORT, BAUD, timeout=2) as ser:
    time.sleep(0.3)
    ser.reset_input_buffer()

    print("Loading new FIR coefficients...")

    # Send 'C' followed by 4 coefficient bytes
    ser.write(b"C" + bytes(coefficients))

    ack = ser.read(1)

    if ack != b"K":
        raise RuntimeError(
            f"Coefficient loading failed. Received: {ack!r}"
        )

    print("PASS: FPGA acknowledged coefficient update")

    # Process samples using newly loaded coefficients
    samples = [8, 16, 24, 32, -8, -16, -24, -32]

    results = [send_sample(ser, s) for s in samples]

    if all(results):
        print("\nREAL FPGA PROGRAMMABLE FIR TEST PASSED!")
    else:
        print("\nREAL FPGA PROGRAMMABLE FIR TEST FAILED!")
