`timescale 1ns/1ps

// ── Datapath ──
// Full 5-stage pipelined MIPS datapath.
// Includes valid/halt bit pipeline and instrW pipeline for PMU.

module datapath
    (input         clk, reset,
     // Fetch stage — memory interface
     output [31:0] pcF,
     input  [31:0] instrF,
     // Memory stage — dmem interface
     input  [31:0] readdataM,
     output [31:0] aluoutM,
     output [31:0] writedataM,
     output        memwriteM,
     // Control signals into datapath (from controller)
     input         regwriteD,
     input         memtoregD,
     input         memwriteD,
     input         alusrcD,
     input         regdstD,
     input         branchD,
     input  [2:0]  alucontrolD,
     // Signals out to controller (for decoding)
     output [5:0]  opD,
     output [5:0]  functD,
     output        equalD,
     // Hazard unit — forwarding selects
     input  [1:0]  forwardAE,
     input  [1:0]  forwardBE,
     // Hazard unit — stall and flush
     input         stallF,
     input         stallD,
     input         flushE,
     input         flushD,
     // Signals out to hazard unit
     output [4:0]  rsE, rtE,
     output [4:0]  rsD, rtD,
     output [4:0]  writeregM, writeregW,
     output        regwriteM, regwriteW,
     output        memtoregE,
     output        pcsrcE,
     // PMU signals
     output        memtoregM,
     output        branchM,
     output        validW,
     output        haltW,
     output [31:0] instrW);      // instrW: instruction word pipelined to Writeback for HALT detection

    // ════════════════════════════════════
    // FETCH STAGE
    // ════════════════════════════════════
    wire [31:0] pcplus4F, pcnextF;

    flopenrc #(32) pcreg(clk, reset, ~stallF, 1'b0, pcnextF, pcF);  // enable=~stallF, no clear needed for PC
    adder pcadd(pcF, 32'b100, pcplus4F);               // pc = pc+4
    mux2 #(32) pcmux(pcplus4F, pcbranchE, pcsrcE, pcnextF); // branch resolved in Execute

    // ── F/D pipeline register ──
    wire validD, validE, validM;
    wire halt = (instrF === 32'hFC000000);  // HALT instruction detected
    flopenrc #(1) validDreg (clk, reset, ~stallD, flushD, ~halt, validD);  // invalid after HALT... validD = complement of halt
    wire haltD, haltE, haltM;
    flopenrc #(1) haltDreg  (clk, reset, ~stallD, flushD, halt,  haltD);   // pipeline halt bit
    wire [31:0] instrD, pcplus4D;

    flopenrc #(32) instreg(clk, reset, ~stallD, flushD, instrF,   instrD);    // saves instruction
    flopenrc #(32) pcreg4 (clk, reset, ~stallD, flushD, pcplus4F, pcplus4D); // saves pc+4 value

    // ════════════════════════════════════
    // DECODE STAGE
    // ════════════════════════════════════
    wire [31:0] resultW;
    wire [4:0]  rdD;
    wire [31:0] rd1D, rd2D, signimmD;

    assign rsD    = instrD[25:21];    // rs field
    assign rtD    = instrD[20:16];    // rt field
    assign rdD    = instrD[15:11];    // rd field
    assign opD    = instrD[31:26];    // opcode — sent to controller
    assign functD = instrD[5:0];      // funct  — sent to controller
    assign equalD = (rd1D == rd2D);   // are the two source registers equal?
    signext se(instrD[15:0], signimmD);
    regfile rf(clk, regwriteW, rsD, rtD, writeregW, resultW, rd1D, rd2D);

    // ── D/E pipeline register ──
    flopenrc #(1) validEreg (clk, reset, 1'b1, flushE | flushD, validD, validE);  // cleared by load-use flush OR branch flush
    flopenrc #(1) haltEreg  (clk, reset, 1'b1, flushE, haltD,  haltE);

    wire        regwriteE, memwriteE, alusrcE, regdstE, branchE;
    wire [2:0]  alucontrolE;
    wire [4:0]  rdE, writeregE;
    wire [31:0] rd1E, rd2E, signimmE, pcplus4E;
    wire [31:0] instrE;   // instruction word pipelined through Execute

    // control signals
    flopenrc #(1)  regwriteEreg  (clk, reset, 1'b1, flushE, regwriteD,   regwriteE);
    flopenrc #(1)  memtoregEreg  (clk, reset, 1'b1, flushE, memtoregD,   memtoregE);
    flopenrc #(1)  memwriteEreg  (clk, reset, 1'b1, flushE, memwriteD,   memwriteE);
    flopenrc #(1)  alusrcEreg    (clk, reset, 1'b1, flushE, alusrcD,     alusrcE);
    flopenrc #(1)  regdstEreg    (clk, reset, 1'b1, flushE, regdstD,     regdstE);
    flopenrc #(1)  branchEreg    (clk, reset, 1'b1, flushE, branchD,     branchE);
    flopenrc #(3)  alucontrolEreg(clk, reset, 1'b1, flushE, alucontrolD, alucontrolE);
    // data signals
    flopenrc #(32) rd1Ereg       (clk, reset, 1'b1, flushE, rd1D,        rd1E);
    flopenrc #(32) rd2Ereg       (clk, reset, 1'b1, flushE, rd2D,        rd2E);
    flopenrc #(32) signimmEreg   (clk, reset, 1'b1, flushE, signimmD,    signimmE);
    flopenrc #(32) pc4Ereg       (clk, reset, 1'b1, flushE, pcplus4D,    pcplus4E);
    flopenrc #(5)  rsEreg        (clk, reset, 1'b1, flushE, rsD,         rsE);
    flopenrc #(5)  rtEreg        (clk, reset, 1'b1, flushE, rtD,         rtE);
    flopenrc #(5)  rdEreg        (clk, reset, 1'b1, flushE, rdD,         rdE);
    flopenrc #(32) instrEreg     (clk, reset, 1'b1, flushE, instrD,      instrE);  // pipeline instr word D→E

    // ════════════════════════════════════
    // EXECUTE STAGE
    // ════════════════════════════════════
    wire [31:0] srcAE, srcBE, signimmshE, pcbranchE;
    assign pcsrcE = (branchE === 1'b1) & (zeroE === 1'b1);  // branch resolved in Execute
    reg  [31:0] fwdAE, fwdBE;
    wire [31:0] aluoutE;
    wire        zeroE;

    mux2 #(5)  wregmux (rtE, rdE, regdstE, writeregE);       // choose reg to write to
    mux2 #(32) srcbmux (fwdBE, signimmE, alusrcE, srcBE);    // forwarded rd2 feeds into imm/reg mux
    sl2  immsh (signimmE, signimmshE);                         // left shift
    adder branchadd(pcplus4E, signimmshE, pcbranchE);          // calc branch target
    alu  alu   (srcAE, srcBE, alucontrolE, aluoutE, zeroE);   // do alu op

    // 3-way forwarding mux for srcAE
    always @(*)
        case (forwardAE)
            2'b10:   fwdAE = aluoutM;   // forward from Memory stage (EX/MEM)
            2'b01:   fwdAE = resultW;   // forward from Writeback stage (MEM/WB)
            default: fwdAE = rd1E;      // no hazard, use register file
        endcase
    assign srcAE = fwdAE;

    // 3-way forwarding mux for srcBE
    always @(*)
        case (forwardBE)
            2'b10:   fwdBE = aluoutM;   // forward from Memory stage (EX/MEM)
            2'b01:   fwdBE = resultW;   // forward from Writeback stage (MEM/WB)
            default: fwdBE = rd2E;      // no hazard, use register file
        endcase

    // ── E/M pipeline register ──
    wire [31:0] pcbranchM;
    wire        zeroM;
    wire [31:0] instrM;   // instruction word pipelined through Memory

    // control signals — flopr only, all hazards dealt with in F/D/EX
    flopr #(1)  regwriteMreg  (clk, reset, regwriteE,  regwriteM);
    flopr #(1)  memtoregMreg  (clk, reset, memtoregE,  memtoregM);
    flopr #(1)  memwriteMreg  (clk, reset, memwriteE,  memwriteM);
    flopr #(1)  branchMreg    (clk, reset, branchE,    branchM);
    // data signals
    flopr #(32) aluoutMreg    (clk, reset, aluoutE,    aluoutM);
    flopr #(32) writedataMreg (clk, reset, fwdBE,      writedataM);  // use forwarded value, not raw rd2E
    flopr #(5)  writeregMreg  (clk, reset, writeregE,  writeregM);
    flopr #(1)  zeroMreg      (clk, reset, zeroE,      zeroM);
    flopr #(32) pcbranchMreg  (clk, reset, pcbranchE,  pcbranchM);
    flopr #(1)  validMreg     (clk, reset, validE,     validM);   // valid bit E→M
    flopr #(1)  haltMreg      (clk, reset, haltE,      haltM);
    flopr #(32) instrMreg     (clk, reset, instrE,     instrM);   // pipeline instr word E→M

    // ════════════════════════════════════
    // MEMORY STAGE
    // ════════════════════════════════════

    // ── M/W pipeline register ──
    wire        memtoregW;
    wire [31:0] aluoutW, readdataW;

    flopr #(1)  regwriteWreg (clk, reset, regwriteM, regwriteW);
    flopr #(1)  memtoregWreg (clk, reset, memtoregM, memtoregW);
    flopr #(32) aluoutWreg   (clk, reset, aluoutM,   aluoutW);
    flopr #(32) readdataWreg (clk, reset, readdataM, readdataW);
    flopr #(5)  writeregWreg (clk, reset, writeregM, writeregW);
    flopr #(1)  validWreg    (clk, reset, validM,    validW);    // valid bit M→W
    flopr #(1)  haltWreg     (clk, reset, haltM,     haltW);
    flopr #(32) instrWreg    (clk, reset, instrM,    instrW);    // pipeline instr word M→W (used by PMU for combinational HALT detect)

    // ════════════════════════════════════
    // WRITEBACK STAGE
    // ════════════════════════════════════
    mux2 #(32) resmux(aluoutW, readdataW, memtoregW, resultW);  // ALU output or memory read data

endmodule