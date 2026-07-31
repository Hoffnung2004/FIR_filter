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
    logic [N-1:0] a_ff;
    logic [N-1:0] b_ff;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            a_ff<='0;
            b_ff<='0;
        end else if(enable_i) begin
            a_ff<=a_i^b_i^c_i;
            b_ff<={(a_i[N-2:0]&b_i[N-2:0])|(a_i[N-2:0]&c_i[N-2:0])|(b_i[N-2:0]&c_i[N-2:0]),1'b0};
        end
    end
    assign a_o = a_ff;
    assign b_o = b_ff;
endmodule
