`timescale 1ns / 1ps

module Carry_Block_10(
    output Cout,
    input [9:0] p,
    input [9:0] g,
    input Cin
    );

    assign Cout = g[9] + (p[9] & (g[8] + (p[8] & (g[7] + (p[7] & (g[6] + (p[6] & (g[5] + (p[5] & (g[4] + (p[4] & (g[3] + (p[3] & (g[2] + (p[2] & (g[1] + (p[1] & (g[0] + (p[0] & Cin)))))))))))))))))));

endmodule
