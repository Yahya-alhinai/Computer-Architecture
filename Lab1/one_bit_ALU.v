`timescale 1ns / 1ps
module one_bit_ALU(
    input A,
    input B,
    input Cin,
    input [1:0] control,
    output Cout,
    output result
    );

//Implement the 1-bit ALU here

    assign result = (control == 0)? (A & B) : (control == 1)? (A | B) : (A ^ B ^ Cin);
    assign Cout = (A & B)|(A & Cin)|(B & Cin);

endmodule
