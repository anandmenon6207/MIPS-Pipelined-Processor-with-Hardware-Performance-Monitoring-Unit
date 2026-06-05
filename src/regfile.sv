`timescale 1ns/1ps

// ── Register File ──
// 32 registers, 32 bits wide
// Write-then-read forwarding for same-cycle write/read

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