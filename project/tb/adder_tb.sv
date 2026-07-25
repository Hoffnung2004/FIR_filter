`timescale 1ns / 1ps

module adder_tb();


    localparam int LATENCY = 7; 
    localparam int N = 20;
    logic clk_i;
    logic enable_i;
    logic reset_i;
    logic signed [N-1:0] a_i;
    logic signed [N-1:0] b_i;
    logic signed [N-1:0] s_o;
    logic signed [N-1:0] s_e;
    logic signed [N-1:0] register [LATENCY-1:0];
    logic signed [N-1:0] error;

    adder #(.N(32)) dut (
        .clk_i(clk_i),
        .enable_i(enable_i),
        .reset_i(reset_i),
        .a_i(a_i),
        .b_i(b_i),
        .summ(s_o)
    );
    
    always #5 clk_i = ~clk_i; // 100 МГц (период 10 нс)
    
    initial begin 
        clk_i = 0;
        reset_i = 1;
        enable_i = 0;
        a_i = 0;
        b_i = 0;
        
        #15;
        enable_i=1;
        reset_i=0;
          
    end
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for(int i=0; i<LATENCY; i++) register[i]<=32'b0;
        end else
        if(enable_i) begin
            a_i = $random;
            b_i = $random;
            register = {register[LATENCY-2:0],a_i+b_i};
        end
    end
    assign s_e = register[LATENCY-1];
    assign error = s_e - s_o;

endmodule
