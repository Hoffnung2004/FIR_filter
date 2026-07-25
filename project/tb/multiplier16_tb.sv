`timescale 1ns / 1ps

module multiplier16_tb();


    localparam int LATENCY = 21; 
    logic clk_i;
    logic enable_i;
    logic reset_i;
    logic signed [15:0] a;
    logic signed [15:0] b;
    logic signed [15:0] a_i;
    logic signed [15:0] b_i;
    logic signed [31:0] m_o;
    logic signed [31:0] m_e;
    logic signed [31:0] register [LATENCY-1:0];
    logic signed [31:0] error;

    // Подключение модуля (DUT)
    multiplier16 dut (
        .clk_i   (clk_i),
        .enable_i(enable_i),
        .reset_i (reset_i),
        .a_i     (a_i),
        .b_i     (b_i),
        .m_o     (m_o)
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
            a = $urandom_range(0, 65535);
            b = $urandom_range(0, 65535);
            a_i = a; 
            b_i = b; 
            register = {register[LATENCY-2:0],a*b};
        end
    end
    assign m_e = register[LATENCY-1];
    assign error = m_e - m_o;

endmodule
