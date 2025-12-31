# Zig Base64 Tool

A simple CLI utility for Base64 encoding and decoding.

---

### Usage

The program reads from **stdin** and outputs the result to **stdout**.

**Encode:**
```bash
echo -n "hello" | ./main -e
```

**Decode:**
```bash
echo -n "aGVsbG8=" | ./main -d
```

### Commands
* zig build-exe main.zig - Compile the project.
* zig test encoder.zig - Run the test suite.

### Flags
* -e: Encode input text to Base64.
* -d: Decode Base64 text to raw bytes.
