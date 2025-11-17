# Dual-port SRAM — RTL + Testbench



[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Language: SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-orange.svg)]
[![Simulate](https://img.shields.io/badge/simulate-local%20or%20-Questa%2FVCS%2FXcelium-brightgreen.svg)]

---

## Table of contents

- [Project overview](#project-overview)
- [Features](#features)
- [Files](#files)
- [How to run (quick)](#how-to-run-quick)

---

# Project overview

This project implements a small behavioral dual-port synchronous SRAM in SystemVerilog:

- **Port A**: Read/Write synchronous
- **Port B**: Read/Write synchronous
- **Arbitration rule**: When both ports write the *same address in the same cycle*, **Port A wins** (Port A write has precedence).
- Behaviorally oriented — suitable for verification and testbenches.

Two source files are included in this repo (or you can create them from the provided code blocks):

- `dual_port_SRAM.v` — RTL implementation
- `testbench.v` — self-checking testbench (deterministic + randomized) that reports pass/fail and optionally dumps VCD

---

# Features

- Simple behavioral memory with parameterizable `ADDR_WIDTH` and `DATA_WIDTH`
- Self-checking testbench:
  - Deterministic pattern write/read verification
  - Randomized stress test (read/write mix with an internal golden model)
  - Safety assertions to detect WE glitches (SVA)
- VCD dump support (guarded by `ifdef VCD`)
- Clean summary message at end: `TEST PASSED` or `TEST FAILED: <n> errors`

---

# Files

- `dual_port_SRAM.v` — RTL (behavioral)
- `testbench.v` — testbench provided by author
- `README.md` — this file
- `LICENSE` — MIT license (recommended)

---

# How to run (quick)

> Two typical workflows are shown: **(A)** using a commercial/SystemVerilog-capable simulator (recommended for SVA support), and **(B)** using Icarus/iverilog (may require removing assertions/SVA).

---

<details>
<summary><strong>A — Run with a SystemVerilog-capable simulator (recommended)</strong></summary>

These simulators support SVA (the `property` / `assert property` constructs in the testbench):

- **Questa/ModelSim**, **Synopsys VCS**, **Cadence Xcelium**

Typical steps (example for Questa/ModelSim):

```bash
# Example (Questa/ModelSim-like)
vlogan -sverilog dual_port_SRAM.v testbench.v    # compile
vsim -c testbench -do "run -all; quit"          # run in batch mode

```

For VCS:

```bash
vcs -full64 -sverilog dual_port_SRAM.v testbench.v -o simv
./simv
```


This will run the deterministic + randomized tests and print a summary message. If VCD is defined in the testbench, a testbench.vcd will be created for waveform viewing.
```bash
</details> <details> <summary><strong>B — Run with Icarus Verilog (iverilog / vvp)</strong></summary>
```
Icarus (iverilog / vvp) is free and convenient but may not fully support SVA assertions used in the testbench (the property / assert property syntax). If your Icarus version does not support SVA, either:

Comment out or remove the assertion block near the bottom of the testbench (the property we_no_glitch_* and assert property) — safe for basic functional checks.

Or use a commercial/SystemVerilog simulator.

If you strip the assertions, run:
``` bash
# compile (use SystemVerilog support flag)
iverilog -g2012 -o simv dual_port_SRAM.v testbench.v
vvp simv
# if VCD was created:
gtkwave testbench.vcd
```


## Notes:

Use -g2012 or -g2005-sv depending on your iverilog version and feature set.

If $urandom_range or some SV features are missing, you may need to replace with $urandom % DEPTH style or use a simulator with full SystemVerilog support.
```bash
</details>
Expected output (summary)

When the testbench finishes successfully you should see something like:

[<time>] --- Deterministic test start
[<time>] --- Deterministic test done
[<time>] --- Randomized test start (800 ops)
[<time>] --- Randomized test done
[<time>] TEST PASSED: no errors
```

If errors occur the testrig prints detailed error lines such as:
``` bash
[500] ERROR A: addr=12 expected= A0000000 got= ...
[1024] TEST FAILED: 3 errors
```

If VCD tracing is enabled (by defining VCD), testbench.vcd will be generated for waveform inspection.

Design details & arbitration
``` bash
Memory: mem [0:DEPTH-1] where DEPTH = (1 << ADDR_WIDTH).
```
Ports: Both ports register inputs on posedge clk and outputs are read from registered addresses (synchronous reads).

### Write arbitration:

* Implementation registers we_a_r, addr_a_r, din_a_r, etc., then performs writes on the next clock edge.
* The code writes mem[addr_a_r] if we_a_r is asserted (active low we_a_n == 0), then attempts to write mem[addr_b_r] if we_b_r is asserted unless we_a_r also wrote the same address this cycle — in that case A wins (B is suppressed).
* Read latency: The testbench expects two-cycle latency after address change (because both address and outputs are registered).

### Deterministic test:

* Writes pattern 0xA000_0000 + addr on port A to address addr.
* Writes pattern 0xB000_0000 + addr on port B to reversed address (DEPTH-1-addr).

Then reads back and checks expected values.

### Randomized test:

* Builds an internal golden array and performs cycles randomized ops (30% writes, 70% reads per port).
* Synchronizes for read latency and compares dout_* against the golden array.

Assertions:

The testbench contains SVA checks to detect glitching on we_* signals (requires SVA-capable simulator).

Summary: prints PASS/FAIL and finishes simulation.

Quick copy — recommended file layout

Create these files in your repository:
``` bash
/dual_port_SRAM.v
/testbench.v
/README.md    <- (this file)
```




<!-- End of README -->
