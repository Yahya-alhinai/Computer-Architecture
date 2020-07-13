`timescale 1ns / 1ps

module Carry_Lookahead_Adder(
    input [9:0] A,
    input [9:0] B,
    input Cin,
    output [9:0] S,
    output Cout
    );

    wire [9:0] P; //propagate values are stored here
    wire [9:0] G; //generate values are stores
    wire [9:0] C; //carry for each bit position

    PG_Block PG(A, B, P, G);
    
    assign C[0] = Cin;
    Carry_Block_1 CB1(C[1], P, G, Cin);
    Carry_Block_3 CB3(C[3], P, G, Cin);
    Carry_Block_2 CB2(C[2], P, G, Cin);
    Carry_Block_5 CB5(C[5], P, G, Cin);
    Carry_Block_4 CB4(C[4], P, G, Cin);
    Carry_Block_6 CB6(C[6], P, G, Cin);
    Carry_Block_7 CB7(C[7], P, G, Cin);
    Carry_Block_8 CB8(C[8], P, G, Cin);
    Carry_Block_9 CB9(C[9], P, G, Cin);
    Carry_Block_10 CB10(Cout, P, G, Cin);

    assign S = P ^ C;


endmodule
