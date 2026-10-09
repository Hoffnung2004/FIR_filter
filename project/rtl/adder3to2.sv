module adder3to2
#(
    parameter int N = 16 // >=2
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic [N-1:0] a_i,
    input logic [N-1:0] b_i,
    input logic [N-1:0] c_i,
    output logic [N-1:0] a_o,
    output logic [N-1:0] b_o
    );
    
    assign a_o = a_i^b_i^c_i;
    assign b_o = {(a_i[N-2:0]&b_i[N-2:0])|(a_i[N-2:0]&c_i[N-2:0])|(b_i[N-2:0]&c_i[N-2:0]),1'b0};
endmodule
