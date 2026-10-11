module adder_tree_GOLD #(
    parameter int NUM_INPUTS = 5, 
    parameter int BITS_W     = 48,
    parameter int DELAY      = 0    
)(
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     reset_i,
    input  logic signed [BITS_W-1:0] inputs_i [0:NUM_INPUTS-1],
    output logic signed [BITS_W-1:0] summ_o
);

    logic signed [BITS_W-1:0] sum_comb;

    always_comb begin
        sum_comb = '0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            sum_comb = sum_comb + inputs_i[i];
        end
    end

    delay #(
        .D(DELAY),
        .W(BITS_W)
    ) u_delay (
        .clk_i   (clk_i),
        .enable_i(enable_i),
        .reset_i (reset_i),
        .signal_i(sum_comb),
        .signal_o(summ_o)
    );

endmodule