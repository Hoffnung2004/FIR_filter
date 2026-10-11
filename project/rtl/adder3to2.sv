`timescale 1ns / 1ps

module adder3to2 #(
    parameter int N = 48
)(
    input  logic [N-1:0] a_i,
    input  logic [N-1:0] b_i,
    input  logic [N-1:0] c_i,
    output logic [N-1:0] a_o, // Вектор Sum
    output logic [N-1:0] b_o  // Вектор Carry (сдвинут на 1 бит влево)
);

    assign a_o = a_i ^ b_i ^ c_i;
    assign b_o[0] = 1'b0;
    assign b_o[N-1:1] = (a_i[N-2:0] & b_i[N-2:0]) |
                        (a_i[N-2:0] & c_i[N-2:0]) |
                        (b_i[N-2:0] & c_i[N-2:0]);

endmodule