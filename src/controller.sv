`timescale 1ns/1ps

// ── Controller ──
// Decodes instruction in Decode stage.
// Instantiates maindec and aludec.

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