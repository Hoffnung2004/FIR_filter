module param_filter
#(
    parameter int N = 10, // N of taps
    parameter int BITS_W=40
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic signed [15:0] signal_i,
    input logic signed [15:0] taps_i [0:N-1], // можете поменять порядок на N-1:0
    output logic signed [BITS_W-1:0] signal_o   
);
    assign signal_o = {24'b0,signal_i};
endmodule 