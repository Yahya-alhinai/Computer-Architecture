`timescale 1ns / 1ps

module PG_Block(
    input [9:0] A,
    input [9:0] B,
    output [9:0] P,
    output [9:0] G
    );

    assign G = A & B;
    assign P = A ^ B;


endmodule
