`timescale 1ns/1ps

// ── MIPS Top Module ──
// Wires together: controller, datapath, imem, dmem, pmu, hazard
// No logic here — pure structural connections

module mips
    (input clk, reset);

    // ── controller <-> datapath ──
    wire        memtoregD, memwriteD, branchD;
    wire        alusrcD, regdstD, regwriteD, jumpD;
    wire [2:0]  alucontrolD;
    wire [5:0]  opD, functD;
    wire        equalD;

    // ── datapath <-> imem ──
    wire [31:0] pcF, instrF;

    // ── hazard unit signals ──
    wire [1:0]  forwardAE, forwardBE;
    wire        stallF, stallD, flushE, flushD;
    wire [4:0]  rsE, rtE, rsD, rtD;
    wire [4:0]  writeregM, writeregW;
    wire        regwriteM, regwriteW;
    wire        memtoregE, pcsrcE;

    // ── datapath <-> dmem ──
    wire [31:0] aluoutM, writedataM, readdataM;
    wire        memwriteM;
    wire        memtoregM, branchM, validW, haltW;  // for PMU
    wire [31:0] instrW;                              // instruction at Writeback — for PMU HALT detect

    controller c(
        .op         (opD),
        .funct      (functD),
        .equalD     (equalD),
        .memtoregD  (memtoregD),
        .memwriteD  (memwriteD),
        .branchD    (branchD),
        .alusrcD    (alusrcD),
        .regdstD    (regdstD),
        .regwriteD  (regwriteD),
        .jumpD      (jumpD),
        .alucontrolD(alucontrolD)
    );

    datapath dp(
        .clk        (clk),
        .reset      (reset),
        .pcF        (pcF),
        .instrF     (instrF),
        .readdataM  (readdataM),
        .aluoutM    (aluoutM),
        .writedataM (writedataM),
        .memwriteM  (memwriteM),
        .regwriteD  (regwriteD),
        .memtoregD  (memtoregD),
        .memwriteD  (memwriteD),
        .alusrcD    (alusrcD),
        .regdstD    (regdstD),
        .branchD    (branchD),
        .alucontrolD(alucontrolD),
        .opD        (opD),
        .functD     (functD),
        .equalD     (equalD),
        .forwardAE  (forwardAE),
        .forwardBE  (forwardBE),
        .stallF     (stallF),
        .stallD     (stallD),
        .flushE     (flushE),
        .flushD     (flushD),
        .rsE        (rsE),
        .rtE        (rtE),
        .rsD        (rsD),
        .rtD        (rtD),
        .writeregM  (writeregM),
        .writeregW  (writeregW),
        .regwriteM  (regwriteM),
        .regwriteW  (regwriteW),
        .memtoregE  (memtoregE),
        .pcsrcE     (pcsrcE),
        .memtoregM  (memtoregM),
        .branchM    (branchM),
        .validW     (validW),
        .haltW      (haltW),
        .instrW     (instrW)
    );

    imem imem(
        .a  (pcF[7:2]),
        .rd (instrF)
    );

    dmem dmem(
        .clk(clk),
        .we (memwriteM),
        .a  (aluoutM),
        .wd (writedataM),
        .rd (readdataM)
    );

    // ── PMU wires ──
    wire [63:0] pmu_cycles, pmu_instrs, pmu_mem, pmu_branches, pmu_mispredicts, pmu_stalls;

    pmu pmu_inst(
        .clk              (clk),
        .reset            (reset),
        .validW           (validW),
        .instrW           (instrW),
        .memwriteM        (memwriteM),
        .memtoregM        (memtoregM),
        .branchM          (branchM),
        .pcsrcM           (pcsrcE),        // branch resolves in Execute
        .stallF           (stallF),
        .cycle_count      (pmu_cycles),
        .instr_count      (pmu_instrs),
        .mem_count        (pmu_mem),
        .branch_count     (pmu_branches),
        .mispredict_count (pmu_mispredicts),
        .stall_count      (pmu_stalls)
    );

    hazard hu(
        .rsE       (rsE),
        .rtE       (rtE),
        .rsD       (rsD),
        .rtD       (rtD),
        .writeregM (writeregM),
        .writeregW (writeregW),
        .regwriteM (regwriteM),
        .regwriteW (regwriteW),
        .memtoregE (memtoregE),
        .pcsrcE    (pcsrcE),
        .jumpD     (jumpD),
        .forwardAE (forwardAE),
        .forwardBE (forwardBE),
        .stallF    (stallF),
        .stallD    (stallD),
        .flushE    (flushE),
        .flushD    (flushD)
    );

endmodule

// ── Top Module ──
// Instantiates mips. Drives clk and reset for simulation.

module top;

    reg clk, reset;

    mips mips(.clk(clk), .reset(reset));

    // clock: period = 10 time units
    initial clk = 0;
    always #5 clk = ~clk;

    // reset high for first 2 cycles, then release
    initial begin
        reset = 1;
        #22;
        reset = 0;
    end

endmodule