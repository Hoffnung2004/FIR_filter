`timescale 1ns / 1ps
module delay#(
    parameter int D = 4,        // Задержка
    parameter int W = 8     // Ширина регистра
    )(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic [W-1:0] signal_i,
    output logic [W-1:0] signal_o
    );
    generate 
    if(D==0) begin
        assign signal_o = signal_i;
    end else if(D==1) begin
        logic [W-1:0] memory_ff;
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                memory_ff<='0;
            end else if(enable_i) begin
                memory_ff<=signal_i;
            end
        end
        assign signal_o = memory_ff;
    end else begin
        logic [W-1:0] memory_ff [0:D-1];
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                for(int i=0; i<D; i++) memory_ff[i]<='0;
            end else if(enable_i) begin
                memory_ff<={signal_i,memory_ff[0:D-2]};
            end
        end
        assign signal_o = memory_ff[D-1];
    end
    endgenerate 
endmodule
