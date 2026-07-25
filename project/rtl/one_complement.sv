`timescale 1ns / 1ps

module one_complement(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic signed [15:0] number_i,
    output logic signed [15:0] number_o,
    output logic signed [15:0] number_inv_o
    );
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            number_o <= 0;
            number_inv_o <= 0;
        end else if(enable_i) begin
            number_o <= number_i;
            number_inv_o <= 0-number_i;
        end
    end
endmodule
