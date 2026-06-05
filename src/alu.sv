`timescale 1ns/1ps

// ── ALU + Decoder modules ──
// alu, maindec, aludec

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
            6'b000101: controls = 9'b000100001; // bne -- same as beq from decoder POV
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
                default:   alucontrol = 3'bxxx;
            endcase
        endcase
endmodule