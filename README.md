<div align="center">

# 🔬 MIPS Pipelined Processor with Hardware Performance Monitoring Unit

**A 5-stage pipelined MIPS processor implementing a Hardware Performance Monitoring Unit (PMU) in SystemVerilog**

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-IEEE_1800-blue?style=flat-square)
![Simulator](https://img.shields.io/badge/Simulator-Icarus_Verilog_12.0-brightgreen?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-success?style=flat-square)
![Institution](https://img.shields.io/badge/IIIT-Bangalore-orange?style=flat-square)

*IE2025005 · Computer Architecture — Open Systems Lab*

</div>

---

## 📌 Overview

This project implements a **Hardware Performance Monitoring Unit (PMU)** on a fully functional 5-stage pipelined MIPS processor. The PMU passively observes internal pipeline signals and counts performance events in real time — without modifying the pipeline's functional behaviour in any way.

The pipeline handles all data and control hazards:
- **Forwarding** for RAW hazards (EX→EX and MEM→EX paths)
- **Load-use stall** detection and insertion
- **Branch resolution in the Execute stage** with single-cycle flush

---

## 📁 Repository Structure

```
├── src/
│   ├── IE2025005_pipeline.sv       # Full pipeline + PMU (all modules in one file)
│   └── IE2025005_pipeline_tb.sv    # Testbench — waits for HALT, prints PMU report
│
├── program/
│   ├── IE2025005_memfile.dat       # Hex-encoded MIPS program loaded into imem
│   └── memfile_notes.txt           # Assembly listing + expected PMU values
│
├── docs/
│   └── pipeline_diagram.svg        # Architecture diagram
│
├── waveforms/
│   └── IE2025005_pipeline.vcd      # GTKWave waveform output
│
└── README.md
```

---

## 🏗️ Architecture

### Pipeline Stages

| Stage | Key Components |
|---|---|
| **Fetch** | PC register, PC+4 adder, instruction memory, PC mux |
| **Decode** | Register file, sign extender, controller (maindec + aludec) |
| **Execute** | ALU, 3-way forwarding muxes, branch adder, branch resolution |
| **Memory** | Data memory (lw / sw) |
| **Writeback** | Result mux → register file write |

### Pipeline Registers

Each stage boundary uses `flopenrc` (with enable and clear) or `flopr` (reset only) registers. A **valid bit** and **halt bit** are pipelined alongside every instruction to track whether a slot contains a real instruction or a bubble.

### Hazard Unit

Purely combinational — no clock. Produces:
- `forwardAE`, `forwardBE` — 2-bit mux selects for EX stage forwarding
- `stallF`, `stallD` — freeze PC and F/D register on load-use hazard
- `flushE` — insert bubble into D/E register on load-use hazard
- `flushD` — kill Decode slot on branch taken or jump

---

## 📊 PMU — Performance Monitoring Unit

The PMU observes 6 pipeline signals and maintains 64-bit counters:

| Counter | Signal Observed | Description |
|---|---|---|
| `cycle_count` | `!isHaltW` | Total CPU cycles until HALT |
| `instr_count` | `validW && !isHaltW` | Real instructions retired |
| `mem_count` | `memtoregM \| memwriteM` | lw + sw in Memory stage |
| `branch_count` | `branchM` | All branch instructions |
| `mispredict_count` | `pcsrcE` | Taken branches (static not-taken predictor) |
| `stall_count` | `stallF` | Load-use stall cycles |

**Key design decision:** HALT is detected combinationally via `isHaltW = (instrW === 32'hFC000000)`. This avoids the same-posedge race condition that would occur if `haltW` (a clocked register) were used to gate the counters directly.

**Derived metrics** (computed in testbench):
- CPI = `cycle_count / instr_count`
- Pipeline Efficiency = `(cycles - stalls - mispredicts) / cycles`
- Prediction Accuracy = `(branches - mispredicts) / branches`

---

## ⚙️ Supported Instructions

| Type | Instructions |
|---|---|
| R-type | `add`, `sub`, `and`, `or`, `slt` |
| I-type | `addi`, `lw`, `sw`, `beq` |
| J-type | `j` |
| Pseudo | `FC000000` — HALT (required at end of every program) |

> ⚠️ **Every program must end with `fc000000` in the memfile.** The testbench waits for this instruction to reach Writeback before printing results. Instruction memory supports up to 64 instructions.

---

## 🚀 Running the Simulation

**Requirements:** Icarus Verilog 12.0, GTKWave (optional)

```bash
# Compile
iverilog -g2012 -o sim src/IE2025005_pipeline.sv src/IE2025005_pipeline_tb.sv

# Simulate
vvp sim

# View waveforms (optional)
gtkwave waveforms/IE2025005_pipeline.vcd
```

> Make sure `IE2025005_memfile.dat` is in the **same directory** as the compiled binary when running `vvp sim`.

---

## 📈 Sample Output

```
==================================================
       IE2025005 -- PMU Performance Report
==================================================
  Pipeline: 5-stage in-order, static not-taken
--------------------------------------------------
  EXECUTION SUMMARY
    CPU Cycles           : 15
    Instructions Retired : 10
    CPI                  : 1.50
--------------------------------------------------
  MEMORY
    Memory Accesses      : 2
    Memory Access Rate   : 20.0%
--------------------------------------------------
  BRANCH ANALYSIS
    Branch Count         : 1
    Branch Frequency     : 10.0%
    Mispredictions       : 0
    Prediction Accuracy  : 100.0%
--------------------------------------------------
  HAZARD ANALYSIS
    Load-Use Stall Cycles: 1
    Branch Flush Cycles  : 0
    Useful Cycles        : 14
    Pipeline Efficiency  : 93.3%
==================================================
```

---

## 🛠️ Tools

| Tool | Version | Purpose |
|---|---|---|
| Icarus Verilog | 12.0 | Compilation and simulation |
| GTKWave | — | Waveform viewer |
| VS Code | — | Development environment |

---

<div align="center">
<sub>IIIT Bangalore · Computer Architecture Open Systems Lab · 2025</sub>
</div>
