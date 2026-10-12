module adder_tree_new #(
    parameter int NUM_INPUTS = 64,
    parameter int BITS_W     = 48
)(
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     reset_i,
    input  logic signed [BITS_W-1:0] inputs_i [0:NUM_INPUTS-1],
    output logic signed [BITS_W-1:0] summ_o
);

    localparam int TREE_OUT_COUNT = (NUM_INPUTS == 1) ? 1 : 2;
    logic signed [BITS_W-1:0] tree_outputs [0:TREE_OUT_COUNT-1];
    logic [BITS_W-1:0] summ;

    compress_tree #(
        .NUM_INPUTS(NUM_INPUTS),
        .BITS_W    (BITS_W),
        .LEVEL     (0)
    ) u_compress_tree (
        .clk_i    (clk_i),
        .enable_i (enable_i),
        .reset_i  (reset_i),
        .inputs_i (inputs_i),
        .outputs_o(tree_outputs)
    );

    if (NUM_INPUTS == 1) begin : gen_out_single
        delay #( // Для унификации задержки + добавление регистра
            .D(1),
            .W(BITS_W)
            ) u_delay (
            .clk_i   (clk_i),
            .enable_i(enable_i),
            .reset_i (reset_i),
            .signal_i(tree_outputs[0]),
            .signal_o(summ_o)
        );

    end else begin : gen_out_final_adder
        adder #(.N(BITS_W)) u_final_adder (
            .clk_i   (clk_i),
            .enable_i(enable_i),
            .reset_i (reset_i),
            .a_i     (tree_outputs[0]),
            .b_i     (tree_outputs[1]),
            .summ    (summ)
        );
        delay #( // Для унификации задержки
            .D((NUM_INPUTS==2 ? 1 : 0)),
            .W(BITS_W)
            ) u_delay (
            .clk_i   (clk_i),
            .enable_i(enable_i),
            .reset_i (reset_i),
            .signal_i(summ),
            .signal_o(summ_o)
        );
    end

endmodule