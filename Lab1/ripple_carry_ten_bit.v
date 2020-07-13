`timescale 1ns / 1ps
module ripple_carry_ten_bit(
    input [9:0] A,
    input [9:0] B,
    input Cin,
    input [1:0] control,
    output Cout,
    output [9:0] result
    );

    //Implement the ripple carry adder here
    wire [9:1] Carry;

    one_bit_ALU bit_0(A[0], B[0], Cin     , 2, Carry[1], result[0]);
    one_bit_ALU bit_1(A[1], B[1], Carry[1], 2, Carry[2], result[1]);
    one_bit_ALU bit_2(A[2], B[2], Carry[2], 2, Carry[3], result[2]);
    one_bit_ALU bit_3(A[3], B[3], Carry[3], 2, Carry[4], result[3]);
    one_bit_ALU bit_4(A[4], B[4], Carry[4], 2, Carry[5], result[4]);
    one_bit_ALU bit_5(A[5], B[5], Carry[5], 2, Carry[6], result[5]);
    one_bit_ALU bit_6(A[6], B[6], Carry[6], 2, Carry[7], result[6]);
    one_bit_ALU bit_7(A[7], B[7], Carry[7], 2, Carry[8], result[7]);
    one_bit_ALU bit_8(A[8], B[8], Carry[8], 2, Carry[9], result[8]);
    one_bit_ALU bit_9(A[9], B[9], Carry[9], 2, Cout    , result[9]);

endmodule
