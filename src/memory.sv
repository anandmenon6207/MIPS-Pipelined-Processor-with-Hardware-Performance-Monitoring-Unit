`timescale 1ns/1ps

// ── Memory modules ──
// imem, dmem

module imem
    (input  [5:0]  a,
     output [31:0] rd);

    reg [31:0] RAM[63:0]; // 64 locations, 32 bits wide

    initial
        $readmemh("memfile.dat", RAM);

    assign rd = RAM[a];
endmodule

module dmem
    (input         clk, we,
     input  [31:0] a, wd,
     output [31:0] rd);

    reg [31:0] RAM[63:0]; // 64 locations, 32 bits wide

    assign rd = RAM[a[31:2]];

    always @ (posedge clk)
        if (we) RAM[a[31:2]] <= wd;
endmodule