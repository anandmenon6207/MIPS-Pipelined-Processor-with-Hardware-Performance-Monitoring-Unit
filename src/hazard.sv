`timescale 1ns/1ps

// ── Hazard Unit ──
// Purely combinational — no clock.
// Handles forwarding, load-use stalls, and branch flushes.

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
    //   2'b10 = forward from Memory  (aluoutM)
    //   2'b01 = forward from Writeback (resultW)
    //   2'b00 = no forwarding, use register file
    always @(*) begin
        if      ((regwriteM === 1'b1) & (writeregM != 5'b0) & (writeregM == rsE))
            forwardAE = 2'b10;   // EX/MEM forward — newer, takes priority
        else if ((regwriteW === 1'b1) & (writeregW != 5'b0) & (writeregW == rsE))
            forwardAE = 2'b01;   // MEM/WB forward
        else
            forwardAE = 2'b00;   // no hazard
    end

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