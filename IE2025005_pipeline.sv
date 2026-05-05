`timescale 1ns/1ps

//flopenrc
//flopr
//signext
//sl2
//adder
//regfile
//alu
//maindec
//aludec
//imem
//dmem


module flopenrc #(parameter WIDTH = 8)
    (input              clk, reset,
     input              en, clear,
     input  [WIDTH-1:0] d,
     output reg [WIDTH-1:0] q);

    always @(posedge clk, posedge reset)
        if (reset)      q <= 0;
        else if (clear) q <= 0;
        else if (en)    q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
    (input  [WIDTH-1:0] d0, d1,
     input  s,
     output [WIDTH-1:0] y);
    
    assign y = s ? d1 : d0;
endmodule

module flopr #(parameter WIDTH = 8)
    (input              clk, reset,
     input  [WIDTH-1:0] d,
     output reg [WIDTH-1:0] q);

    always @ (posedge clk, posedge reset)
        if (reset) q <= 0;
        else       q <= d;
endmodule

module signext
    (input  [15:0] a,
     output [31:0] y);

    assign y = {{16{a[15]}}, a};
endmodule

module sl2
    (input  [31:0] a,
     output [31:0] y);

    assign y = {a[29:0], 2'b00};
endmodule

module adder
    (input  [31:0] a, b,
     output [31:0] y);

    assign y = a + b;
endmodule

module regfile
    (input         clk,
     input         we3,
     input  [4:0]  ra1, ra2, wa3,
     input  [31:0] wd3,
     output [31:0] rd1, rd2);

    reg [31:0] rf[31:0];

    integer i;

    always @ (posedge clk)
        if (we3) rf[wa3] <= wd3;

    // synthesis off — simulation init only
    initial begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] = 0;
    end

    // Write-then-read: if reading the same reg being written, forward write data
    assign rd1 = (ra1 == 0) ? 32'b0 :
                 (we3 && wa3 == ra1) ? wd3 : rf[ra1];
    assign rd2 = (ra2 == 0) ? 32'b0 :
                 (we3 && wa3 == ra2) ? wd3 : rf[ra2];
endmodule

module alu
    (input  [31:0] a, b,
     input  [2:0]  alucontrol,
     output reg [31:0] result,
     output         zero);

    always @ (*)
        case (alucontrol)
            3'b000: result = a & b;
            3'b001: result = a | b;
            3'b010: result = a + b;
            3'b110: result = a - b;
            3'b111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'bx;
        endcase

    assign zero = (result == 0);
endmodule

module maindec
    (input  [5:0] op,
     output       memtoreg, memwrite,
     output       branch, alusrc,
     output       regdst, regwrite,
     output       jump,
     output       bne,
     output [1:0] aluop);

    reg [8:0] controls;

    assign {regwrite, regdst, alusrc,
            branch, memwrite,
            memtoreg, jump, aluop} = controls;

    assign bne = (op == 6'b000101);  // bne flag

    always @ (*)
        case (op)
            6'b000000: controls = 9'b110000010; // R-type
            6'b100011: controls = 9'b101001000; // lw
            6'b101011: controls = 9'b001010000; // sw
            6'b000100: controls = 9'b000100001; // beq
            6'b001000: controls = 9'b101000000; // addi
            6'b000010: controls = 9'b000000100; // j
            6'b000101: controls = 9'b000100001; // bne -- we assign it same as beq because from a decoder point of view they have the same path . only diff at controller.
            default:   controls = 9'bxxxxxxxxx; // invalid
        endcase
endmodule

module aludec
    (input  [5:0] funct,
     input  [1:0] aluop,
     output reg [2:0] alucontrol);

    always @ (*)
        case (aluop)
            2'b00: alucontrol = 3'b010; // add
            2'b01: alucontrol = 3'b110; // sub
            default: case (funct)       // R-type
                6'b100000: alucontrol = 3'b010; // add
                6'b100010: alucontrol = 3'b110; // sub
                6'b100100: alucontrol = 3'b000; // and
                6'b100101: alucontrol = 3'b001; // or
                6'b101010: alucontrol = 3'b111; // slt
                default:   alucontrol = 3'bxxx; // ???
            endcase
        endcase
endmodule

module dmem
    (input         clk, we,
     input  [31:0] a, wd,
     output [31:0] rd);

    reg [31:0] RAM[63:0];

    assign rd = RAM[a[31:2]];

    always @ (posedge clk)
        if (we) RAM[a[31:2]] <= wd;
endmodule

module imem
    (input  [5:0]  a,
     output [31:0] rd);

    reg [31:0] RAM[63:0];

    initial
        $readmemh("IE2025005_memfile.dat", RAM);

    assign rd = RAM[a];
endmodule


 





module datapath     //mips pipelined datapath
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
    //assign pcnextF = pcplus4F;                         // for now pcnext is just pc+4. branch/jump mux comes later
    mux2 #(32) pcmux(pcplus4F, pcbranchE, pcsrcE, pcnextF); // branch resolved in Execute

    // ── F/D pipeline register ──                     // clk, reset, en, clear, d, q
    // stallD, flushD are now input ports from hazard unit
    // valid bit: 1 = real instruction, 0 = bubble
    wire validD, validE, validM;
    wire halt = (instrF === 32'hFC000000);  // HALT instruction detected
    flopenrc #(1) validDreg (clk, reset, ~stallD, flushD, ~halt, validD);  // invalid after HALT
    wire haltD, haltE, haltM;
    flopenrc #(1) haltDreg  (clk, reset, ~stallD, flushD, halt,  haltD);   // pipeline halt bit
    wire [31:0] instrD, pcplus4D;                      // signals coming out of F/D register into decode stage

    flopenrc #(32) instreg(clk, reset, ~stallD, flushD, instrF,   instrD);    // saves instruction. ~stallD - if stalling en=0 register holds old value. flushD - if flushing register is cleared
    flopenrc #(32) pcreg4 (clk, reset, ~stallD, flushD, pcplus4F, pcplus4D); // saves pc+4 value

    // ════════════════════════════════════
    // DECODE STAGE
    // ════════════════════════════════════
    // regwriteW is now an output port
    // writeregW is now an output port
    wire [31:0] resultW;           // result from ALU or mem. for writeback stage

    wire [4:0]  rdD;     // rsD, rtD are now output ports
    wire [31:0] rd1D, rd2D, signimmD;
    // regwriteD, memtoregD, memwriteD, alusrcD, regdstD, branchD, alucontrolD
    // are now input ports — no wire declaration needed here

    assign rsD = instrD[25:21];    // rs field
    assign rtD = instrD[20:16];    // rt field
    assign rdD = instrD[15:11];    // rd field
    assign opD    = instrD[31:26]; // opcode — sent to controller
    assign functD = instrD[5:0];   // funct  — sent to controller
    assign equalD = (rd1D == rd2D); // are the two source registers equal? used by controller for branch
    signext se(instrD[15:0], signimmD);                                        // extend imm from 16 bit to 32 bit
    regfile rf(clk, regwriteW, rsD, rtD, writeregW, resultW, rd1D, rd2D);    // clk, write enable, ra1, ra2, wa3 write address, wd3 write data, rd1, rd2

    // ── D/E pipeline register ──
    // flushE is now an input port from hazard unit
    flopenrc #(1) validEreg (clk, reset, 1'b1, flushE | flushD, validD, validE);  // cleared by load-use flush OR branch flush
    flopenrc #(1) haltEreg  (clk, reset, 1'b1, flushE, haltD,  haltE);
    wire        regwriteE, memwriteE, alusrcE, regdstE, branchE;  // memtoregE is now an output port
    wire [2:0]  alucontrolE;
    wire [4:0]  rdE, writeregE;  // rsE, rtE are now output ports
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
    // pcsrcE is an output port — driven here
    assign pcsrcE = (branchE === 1'b1) & (zeroE === 1'b1);  // branch resolved in Execute
    reg  [31:0] fwdAE, fwdBE;  // reg because driven by always blocks
    wire [31:0] aluoutE;
    wire        zeroE;

    mux2 #(5) wregmux(rtE, rdE, regdstE, writeregE);  // choose reg to write to. rt or rd
    mux2 #(32) srcbmux(fwdBE, signimmE, alusrcE, srcBE); // forwarded rd2 feeds into imm/reg mux
    sl2 immsh(signimmE, signimmshE);                     // left shif
    adder branchadd(pcplus4E, signimmshE, pcbranchE);    // calc branch target
    alu alu(srcAE, srcBE, alucontrolE, aluoutE, zeroE);  //do alu op

    // 3-way forwarding mux for srcAE
    always @(*)
        case (forwardAE)
            2'b10:    fwdAE = aluoutM;   // forward from Memory stage
            2'b01:    fwdAE = resultW;   // forward from Writeback stage
            default:    fwdAE = rd1E;      // no hazard, use register file
        endcase
    assign srcAE = fwdAE;

    // 3-way forwarding mux for srcBE (feeds into srcbmux)
    always @(*)
        case (forwardBE)
            2'b10:    fwdBE = aluoutM;   // forward from Memory stage
            2'b01:    fwdBE = resultW;   // forward from Writeback stage
            default:    fwdBE = rd2E;      // no hazard, use register file
        endcase

    // ── E/M pipeline register ──
    // memtoregM, branchM are now output ports
    // writeregM is now an output port
    wire [31:0] pcbranchM;                        // aluoutM, writedataM are now output ports
    wire        zeroM;
    wire [31:0] instrM;   // instruction word pipelined through Memory

    // control signals
    // when some beq issue happens and we need to flush after EX stage, we set flushD =1
    //when load use hazard, stallF = 1, stallD = 1 and flushE = 1
    flopr #(1)  regwriteMreg  (clk, reset, regwriteE,  regwriteM);      //we use only flopr cuz all hazards r dealt with in F,D,EX
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
    mux2 #(32) resmux(aluoutW, readdataW, memtoregW, resultW);  //ALU output or memory read data


endmodule

// ════════════════════════════════════════════════════════════
// CONTROLLER
// Decodes the instruction in Decode stage.
// Instantiates maindec and aludec — same as single-cycle.
// ════════════════════════════════════════════════════════════
module controller
    (input  [5:0] op, funct,
     input        equalD,
     output       memtoregD, memwriteD,
     output       branchD,
     output       alusrcD,
     output       regdstD, regwriteD,
     output       jumpD,
     output [2:0] alucontrolD);

    wire [1:0] aluopD;   // internal: connects maindec to aludec
    wire       bne_unused; // maindec produces bne but we don't use it

    maindec md(
        .op      (op),
        .memtoreg(memtoregD),
        .memwrite(memwriteD),
        .branch  (branchD),
        .alusrc  (alusrcD),
        .regdst  (regdstD),
        .regwrite(regwriteD),
        .jump    (jumpD),
        .bne     (bne_unused),
        .aluop   (aluopD)
    );

    aludec ad(
        .funct     (funct),
        .aluop     (aluopD),
        .alucontrol(alucontrolD)
    );

endmodule

// ════════════════════════════════════════════════════════════
// MIPS TOP MODULE
// Wires together: controller, datapath, imem, dmem
// No logic here — pure structural connections
// ════════════════════════════════════════════════════════════
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
        // hazard signals
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
        .instrW           (instrW),        // replaces haltW gating — combinational HALT detect inside PMU
        .memwriteM        (memwriteM),
        .memtoregM        (memtoregM),
        .branchM          (branchM),
        .pcsrcM           (pcsrcE),        // branch resolves in Execute, so pcsrcE is the right signal
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

// ════════════════════════════════════════════════════════════
// HAZARD UNIT
// Purely combinational — no clock.
// Handles forwarding, load-use stalls, and branch flushes.
// ════════════════════════════════════════════════════════════
module hazard
    (// Register numbers
     input  [4:0] rsE, rtE,       // source regs in Execute
     input  [4:0] rsD, rtD,       // source regs in Decode (for load-use)
     input  [4:0] writeregM,      // dest reg in Memory
     input  [4:0] writeregW,      // dest reg in Writeback
     // Control signals
     input        regwriteM,      // is Memory stage writing a reg?
     input        regwriteW,      // is Writeback stage writing a reg?
     input        memtoregE,      // is Execute stage a load?
     input        pcsrcE,         // branch taken in Execute?
     input        jumpD,          // jump in Decode?
     // Forwarding mux selects
     output reg [1:0] forwardAE,  // mux select for srcAE
     output reg [1:0] forwardBE,  // mux select for srcBE
     // Stall and flush signals
     output       stallF,         // freeze PC
     output       stallD,         // freeze F/D register
     output       flushE,         // bubble into D/E register
     output       flushD);        // flush D on branch/jump

    // ── Forwarding logic ──
    // forwardAE: controls what feeds srcAE in Execute
    //   2'b10 = forward from Memory  (aluoutM)
    //   2'b01 = forward from Writeback (resultW)
    //   2'b00 = no forwarding, use rd1E from register file
    always @(*) begin
        if      ((regwriteM === 1'b1) & (writeregM != 5'b0) & (writeregM == rsE))
            forwardAE = 2'b10;   // EX/MEM forward — newer, takes priority
        else if ((regwriteW === 1'b1) & (writeregW != 5'b0) & (writeregW == rsE))
            forwardAE = 2'b01;   // MEM/WB forward
        else
            forwardAE = 2'b00;   // no hazard
    end

    // forwardBE: same logic but for srcBE, uses rtE instead of rsE
    always @(*) begin
        if      ((regwriteM === 1'b1) & (writeregM != 5'b0) & (writeregM == rtE))
            forwardBE = 2'b10;
        else if ((regwriteW === 1'b1) & (writeregW != 5'b0) & (writeregW == rtE))
            forwardBE = 2'b01;
        else
            forwardBE = 2'b00;
    end

    // ── Load-use stall logic ──
    // Stall if: Execute has a load AND it's writing a reg that Decode needs
    wire lwstall;
    assign lwstall = (memtoregE === 1'b1) & ((rtE == rsD) | (rtE == rtD));

    assign stallF = lwstall;
    assign stallD = lwstall;
    assign flushE = lwstall;   // insert bubble into Execute

    // ── Branch/jump flush logic ──
    // If branch taken or jump: kill the wrong instruction sitting in Decode
    assign flushD = (pcsrcE === 1'b1) | (jumpD === 1'b1);  // branch resolved in Execute

endmodule

// ════════════════════════════════════════════════════════════
// TOP MODULE
// Instantiates mips. Drives clk and reset for simulation.
// ════════════════════════════════════════════════════════════
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

// ════════════════════════════════════════════════════════════
// PMU — Hardware Performance Monitoring Unit
// Observes pipeline signals and counts performance events.
// All counters are 64-bit to avoid overflow.
// CPI is derived: cycles / instructions (real number).
//
// KEY CHANGE: instrW (32-bit instruction word at Writeback) replaces
// haltW/haltM gating. isHaltW is combinational — no clock edge, no
// same-posedge race. Removed ports: regwriteW, writeregW, haltW, haltM.
// ════════════════════════════════════════════════════════════
module pmu
    (input         clk, reset,
     // Signals from pipeline
     input         validW,        // 1 = real instruction in Writeback, 0 = bubble
     input  [31:0] instrW,        // instruction word at Writeback — used to detect HALT combinationally
     input         memwriteM,    // 1 when store is in Memory stage
     input         memtoregM,    // 1 when load is in Memory stage
     input         branchM,      // 1 when branch is in Memory stage
     input         pcsrcM,       // 1 when branch is taken (mispredict/flush)
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