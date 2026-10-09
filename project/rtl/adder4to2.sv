`timescale 1ns / 1ps

module adder4to2 #(
    parameter int N = 16
)(
    input  logic [N-1:0] a_i,
    input  logic [N-1:0] b_i,
    input  logic [N-1:0] c_i,
    input  logic [N-1:0] d_i,
    output logic [N-1:0] a_o, 
    output logic [N-1:0] b_o  
);

    logic [N:0] c_horiz;
    logic [N-1:0] c_vert;

    assign c_horiz[0] = 1'b0;

    assign b_o[0] = 1'b0;
    assign b_o[N-1:1] = c_vert[N-2:0];

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_c4to2_slices
            compress4to2 u_c4to2 (
                .x1_i (a_i[i]),
                .x2_i (b_i[i]),
                .x3_i (c_i[i]),
                .x4_i (d_i[i]),
                .c_i  (c_horiz[i]),     
                .s_o  (a_o[i]),         
                .c1_o (c_horiz[i+1]),   
                .c_o  (c_vert[i])       
            );
        end
    endgenerate

endmodule