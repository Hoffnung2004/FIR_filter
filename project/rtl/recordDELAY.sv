//////////////////////////////////////////////////////////////////////////////////
// Only for tesbench. Not for design
//////////////////////////////////////////////////////////////////////////////////

module recordDELAY #(
    parameter BITS_W = 4
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic [BITS_W-1:0] signal1_i,
    input logic [BITS_W-1:0] signal2_i,
    output logic [31:0] delay_o
    );
    logic signed [0:31] memory_ff;
    logic enable;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            memory_ff<='0;
            enable<=1'b1;
        end else begin
            if(signal1_i!=0 && signal2_i!=0) begin
                enable<=1'b0;
            end else if((signal1_i!=0 || signal2_i!=0) & enable) begin
                memory_ff = memory_ff + 1;
            end
        end
    end
    assign delay_o = memory_ff;
endmodule
