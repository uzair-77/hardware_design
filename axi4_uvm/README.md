# AXI4 slave memory: UVM verification environment

A UVM 1.2 testbench for a small AXI4 slave memory. Built to show a full DV flow on my own:
stimulus, checking, assertions, coverage and a test plan.

## DUT (`rtl/axi4_mem.sv`)
- 32-bit data, 16-bit address, 4-bit ID, 16 KB memory at 0x0000-0x3FFF.
- FIXED, INCR and WRAP bursts, 1/2/4-byte beats, byte strobes.
- One write and one read at a time (they can overlap each other).
- Access outside 16 KB gives SLVERR and writes nothing.
- Random wait states on WREADY and RVALID, so the env sees back-pressure.

## Environment (`uvm/`)
| File | What it does |
|---|---|
| `axi_item.sv` | One burst. Constraints keep it legal: aligned, no 4 KB crossing, WRAP length 2/4/8/16, strobes only on active lanes. About 10% of items are out of range on purpose. |
| `axi_driver.sv` | Drives the 5 channels through a clocking block, with random idle gaps and random BREADY/RREADY delays. |
| `axi_monitor.sv` | Rebuilds each burst from the bus. Checks WLAST/RLAST position and BID/RID. |
| `axi_scoreboard.sv` | Reference model (byte array). Checks read data, strobes, narrow beats and every response code. |
| `axi_coverage.sv` | Covergroups: direction, burst, size, length, in/out of range, ID, 4 KB pages, strobe patterns, plus crosses. |
| `axi_seqs.sv` | Random mix, write-then-read-back, strobe test, error-only. |
| `axi_tests.sv` | One test per sequence, plus a regression test that runs all of them. |
| `../rtl/axi_checker.sv` | SVA: VALID held until READY, payload stable, no X, reset values, reserved burst, WRAP length, 4 KB rule, WLAST position. |

## Run (needs Questa, VCS or Xcelium)
    make questa TEST=axi_regress_test SEED=1
    make vcs    TEST=axi_random_test
    make xrun   TEST=axi_error_test
Pass line: `TEST PASSED` from the scoreboard, and no `UVM_ERROR` or assertion failure.

## What was actually checked
- The DUT and the assertions were run with Verilator (`make smoke`): 400 random bursts plus directed cases,
  0 errors, no assertion failures. Two deliberately broken DUTs (WRAP not wrapping, strobes ignored) were both caught.
- The whole UVM code (against the Accellera UVM source) compiles clean with the slang front-end.
- The UVM tests themselves were not run here, since there is no commercial simulator in this environment.
  Run them first on your own tool and fix anything simulator-specific.

## Design choices (for interview questions)
- Driver sends one transaction at a time, so the reference model has no read/write race on the same address.
  A next step is concurrent traffic on separate address regions.
- Scoreboard is in order and checks bytes, not words, so strobes and narrow transfers are checked exactly.
- Assertions sit in a separate module on the bus wires, so they check the DUT whatever the testbench does.
- Coverage crosses matter more than single bins: burst x length, direction x size, direction x range.
- To prove the env finds bugs, break the DUT on purpose (for example, ignore `wstrb`) and check the scoreboard fails.
