`timescale 1ns/1ps

// ── PMU — Hardware Performance Monitoring Unit ──
// Observes pipeline signals and counts performance events.
// All counters are 64-bit to avoid overflow.
// CPI is derived: cycles / instructions (real number).
//
// HALT detection: instrW is pipelined to Writeback and checked
// combinationally via isHaltW — avoids same-posedge race condition.

module pmu
    (input         clk, reset,
     // Signals from pipeline
     input         validW,        // 1 = real instruction in Writeback, 0 = bubble
     input  [31:0] instrW,        // instruction word at Writeback — used to detect HALT combinationally
     input         memwriteM,     // 1 when store is in Memory stage
     input         memtoregM,     // 1 when load is in Memory stage
     input         branchM,       // 1 when branch is in Memory stage
     input         pcsrcM,        // 1 when branch is taken (mispredict/flush)
     input         stallF,        // 1 when load-use stall is happening
     // Counter outputs
     output reg [63:0] cycle_count,
     output reg [63:0] instr_count,
     output reg [63:0] mem_count,
     output reg [63:0] branch_count,
     output reg [63:0] mispredict_count,
     output reg [63:0] stall_count);

    // Combinational HALT detect — sees correct value within same cycle, no posedge race
    wire isHaltW = (instrW === 32'hFC000000);

    // ── 1. CPU Cycles ──────────────────────────────────────
    // Stops when HALT reaches Writeback
    always @(posedge clk or posedge reset)
        if (reset)         cycle_count <= 0;
        else if (!isHaltW) cycle_count <= cycle_count + 1;

    // ── 2. Instructions Retired ────────────────────────────
    // validW=1 means real instruction in Writeback
    // !isHaltW excludes HALT itself from the count
    always @(posedge clk or posedge reset)
        if (reset) instr_count <= 0;
        else if (validW && !isHaltW)
            instr_count <= instr_count + 1;

    // ── 3. Memory Accesses (lw + sw) ───────────────────────
    always @(posedge clk or posedge reset)
        if (reset) mem_count <= 0;
        else if (memtoregM | memwriteM)
            mem_count <= mem_count + 1;

    // ── 4. Branch Count ────────────────────────────────────
    always @(posedge clk or posedge reset)
        if (reset) branch_count <= 0;
        else if (branchM)
            branch_count <= branch_count + 1;

    // ── 5. Branch Mispredictions ───────────────────────────
    // pcsrcM=1 means branch was taken — pipeline flushed (1 cycle penalty)
    // In our static not-taken predictor, every taken branch is a mispredict
    always @(posedge clk or posedge reset)
        if (reset) mispredict_count <= 0;
        else if (pcsrcM)
            mispredict_count <= mispredict_count + 1;

    // ── 6. Stall Cycles (load-use) ────────────────────────
    always @(posedge clk or posedge reset)
        if (reset) stall_count <= 0;
        else if (stallF) stall_count <= stall_count + 1;

    // ── 7. CPI (derived) ───────────────────────────────────
    // Computed in testbench: cpi = cycle_count / instr_count

endmodule