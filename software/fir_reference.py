from pathlib import Path

import random

# FIR coefficients in Q1.7 format
coefficients = [16, 48, 48, 16]
scale = 128

# Previous three valid samples
history = [0, 0, 0]
last_output = 0

# Reproducible random inputs
random.seed(42)

vectors = [
    (8, 1), (16, 1), (24, 1), (32, 1),
    (-8, 1), (-16, 1), (-24, 1), (-32, 1),
    (100, 0), (-100, 0),
    (127, 1), (-128, 1), (0, 1)
]

# Generate 200 additional test cycles
for _ in range(200):
    sample = random.randint(-128, 127)
    valid = random.randint(0, 1)
    vectors.append((sample, valid))

vector_path = Path(__file__).resolve().parents[1] / "sim" / "data" / "fir_vectors.txt"
vector_path.parent.mkdir(parents=True, exist_ok=True)
with vector_path.open("w") as file:
    for sample, valid in vectors:

        if valid:
            samples = [sample] + history

            total = sum(
                c * x for c, x in zip(coefficients, samples)
            )

            # Match RTL arithmetic shift
            last_output = total // scale

            history = [sample] + history[:2]

        file.write(
            f"{sample} {valid} {last_output}\n"
        )

print(f"Generated {len(vectors)} test vectors.")
print("Saved to fir_vectors.txt")
