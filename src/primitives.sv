`timescale 1ns/1ps

// ── Primitive modules ──
// flopenrc, flopr, mux2, adder, sl2, signext

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

module flopr #(parameter WIDTH = 8)
    (input              clk, reset,
     input  [WIDTH-1:0] d,
     output reg [WIDTH-1:0] q);

    always @ (posedge clk, posedge reset)
        if (reset) q <= 0;
        else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
    (input  [WIDTH-1:0] d0, d1,
     input  s,
     output [WIDTH-1:0] y);

    assign y = s ? d1 : d0;
endmodule

module adder
    (input  [31:0] a, b,
     output [31:0] y);

    assign y = a + b;
endmodule

module sl2
    (input  [31:0] a,
     output [31:0] y);

    assign y = {a[29:0], 2'b00};
endmodule

module signext
    (input  [15:0] a,
     output [31:0] y);

    assign y = {{16{a[15]}}, a};
endmodule
