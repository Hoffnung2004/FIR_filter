`timescale 1ns / 1ps
module adder #(parameter N = 32)(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic signed [N-1:0] a_i,
    input logic signed [N-1:0] b_i,
    output logic signed [N-1:0] summ
    );
    localparam int M = (N+7)/8;
    
    logic [N-1:0] memory_a_ff [0:M-1];
    logic [N-1:0] memory_b_ff [0:M-1];
    logic [8:0] memory_s_ff [0:M-1][0:M-1];
    logic [7:0] s_o [0:M-1];
    logic c_o [0:M-1]; 
    
    logic carry_ff [0:M];
    
    generate
        for(genvar i=0; i<M; i++) begin
        adder8 add8(
           .a_i(memory_a_ff[i][8*i+7:8*i]),
           .b_i(memory_b_ff[i][8*i+7:8*i]),
           .c_i(carry_ff[i]),
           .s_o(s_o[i]),
           .c_o(c_o[i])
        );
        end
    endgenerate 
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for(int i=0; i<=M; i++) carry_ff[i] <= 1'b0;
            for(int i=0; i<M; i++)
            for(int j=0; j<M; j++)
             memory_s_ff[i][j]<=8'b0;
            for(int i=0; i<M; i++)
            memory_a_ff[i]<='0;
            for(int i=0; i<M; i++)
            memory_b_ff[i]<='0;
            summ<='0;
            
        end else if(enable_i) begin
            
            carry_ff[0] <= 1'b0; // can get on module input
            
            memory_a_ff<={a_i,memory_a_ff[0:M-2]};
            memory_b_ff<={b_i,memory_b_ff[0:M-2]};
            
            for(int i=0; i<M; i++) begin
                carry_ff[i+1]<=c_o[i];
                memory_s_ff[i]<={s_o[i],memory_s_ff[i][0:M-2]};
                summ[i*8+7 -: 8]<=memory_s_ff[i][M-1-i];
            end
            
        end
    end
    
endmodule
