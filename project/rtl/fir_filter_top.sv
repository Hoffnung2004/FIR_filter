`timescale 1ns / 1ps

module fir_filter_top
    import fir_filter_params_pkg::*;
#(
    parameter logic ARCHITECTURE = 1'b1 //ВЫБОР АРХИТЕКТУРЫ 0 - дерево, 1 - транспонированная
)(
    input  logic clk_i,
    input  logic signed [SIGNAL_WIDTH-1:0] signal_i,
    output logic signed [RESULT_WIDTH-1:0] signal_o
);

    generate
        if (ARCHITECTURE == 0) begin : g_tree_arch

            logic signed [SIGNAL_WIDTH-1:0] tap_line_ff [0:COEFF_NUM-1];

            always_ff @(posedge clk_i) begin
                tap_line_ff[0] <= signal_i;

                for (int i = 1; i < COEFF_NUM; i++) begin
                    tap_line_ff[i] <= tap_line_ff[i-1];
                end
            end

            logic signed [RESULT_WIDTH-1:0] tree_q [0:TREE_LEN-1][0:COEFF_NUM-1];

            for (genvar mul_i = 0; mul_i < TREE_WIDTH[0]; mul_i++) begin : gen_level0
                localparam int NODE_WIDTH = TREE_BIT_WIDTH[0][mul_i];

                logic signed [NODE_WIDTH-1:0] result_comb;
                logic signed [NODE_WIDTH-1:0] q_ff;

                filter_cell #(
                    .FACTOR_0_WIDTH(SIGNAL_WIDTH),
                    .FACTOR_1_WIDTH(COEFF_WIDTH),
                    .ADDEND_WIDTH  (1),
                    .RESULT_WIDTH  (NODE_WIDTH)
                ) mul_cell (
                    .factor_0_i(tap_line_ff[mul_i]),
                    .factor_1_i(COEFFS[mul_i]),
                    .addend_i  (1'sd0),
                    .result_o  (result_comb)
                );

                always_ff @(posedge clk_i) begin
                    q_ff <= result_comb;
                end

                assign tree_q[0][mul_i] = q_ff;
            end : gen_level0

            for (genvar level_i = 1; level_i < TREE_LEN; level_i++) begin : gen_level
                for (genvar node_i = 0; node_i < TREE_WIDTH[level_i]; node_i++) begin : gen_node
                    localparam int NODE_WIDTH = TREE_BIT_WIDTH[level_i][node_i];

                    logic signed [NODE_WIDTH-1:0] src_ext   [0:TREE_STEP-1];
                    logic signed [NODE_WIDTH-1:0] sum_chain [0:TREE_STEP];
                    logic signed [NODE_WIDTH-1:0] q_ff = '0;

                    assign sum_chain[0] = '0;

                    for (genvar term_i = 0; term_i < TREE_STEP; term_i++) begin : gen_term
                        localparam int SOURCE_NODE_ID =
                            node_i * TREE_STEP + term_i;

                        if (SOURCE_NODE_ID < TREE_WIDTH[level_i-1]) begin : gen_valid_term
                            assign src_ext[term_i] =
                                tree_q[level_i-1][SOURCE_NODE_ID];
                        end : gen_valid_term
                        else begin : gen_empty_term
                            assign src_ext[term_i] = '0;
                        end : gen_empty_term

                        assign sum_chain[term_i+1] =
                            sum_chain[term_i] + src_ext[term_i];
                    end : gen_term

                    always_ff @(posedge clk_i) begin
                        q_ff <= sum_chain[TREE_STEP];
                    end

                    assign tree_q[level_i][node_i] = q_ff;
                end : gen_node
            end : gen_level

            assign signal_o = tree_q[TREE_LEN-1][0];

        end : g_tree_arch
        else begin : g_transposed_arch

            (* dont_touch = "yes" *)
            logic signed [0:COEFF_NUM-1][SIGNAL_WIDTH-1:0]
                tree_node_ff [0:INPUT_TREE_LEN-1];

            // уровень 0
            always_ff @(posedge clk_i) begin
                tree_node_ff[0][0] <= signal_i;
            end

            for (
                genvar level_id = 1;
                level_id < INPUT_TREE_LEN;
                level_id++
            ) begin : g_tree_lvl

                for (
                    genvar node_id = 0;
                    node_id < INPUT_TREE_WIDTH[level_id];
                    node_id++
                ) begin : g_tree_node

                    localparam int PARENT_NODE_ID =
                        node_id / INPUT_TREE_STEP;

                    always_ff @(posedge clk_i) begin
                        tree_node_ff[level_id][node_id] <=
                            tree_node_ff[level_id-1][PARENT_NODE_ID];
                    end
                end : g_tree_node
            end : g_tree_lvl

            // листья дерева
            logic signed [SIGNAL_WIDTH-1:0] x_tap [0:COEFF_NUM-1];

            for (
                genvar tap_id = 0;
                tap_id < COEFF_NUM;
                tap_id++
            ) begin : g_x_tap

                assign x_tap[tap_id] =
                    tree_node_ff[INPUT_TREE_LEN-1][tap_id];
            end : g_x_tap

            logic signed [RESULT_WIDTH-1:0] mac_result [0:COEFF_NUM-1];
            logic signed [RESULT_WIDTH-1:0] delay_line_ff [0:COEFF_NUM-2];

            // нулевой коэффициент
            filter_cell #(
                .FACTOR_0_WIDTH(SIGNAL_WIDTH),
                .FACTOR_1_WIDTH(COEFF_WIDTH),
                .ADDEND_WIDTH  (1),
                .RESULT_WIDTH  (TRAN_WIDTH[0])
            ) u_mac_0 (
                .factor_0_i(x_tap[0]),
                .factor_1_i(COEFFS[COEFF_NUM-1]),
                .addend_i  (1'b0),
                .result_o  (mac_result[0])
            );

            always_ff @(posedge clk_i) begin
                for (int delay_id = 0; delay_id < COEFF_NUM-1; delay_id++) begin
                    delay_line_ff[delay_id] <= mac_result[delay_id];
                end
            end

            for (
                genvar tap_id = 1;
                tap_id < COEFF_NUM;
                tap_id++
            ) begin : g_tap

                filter_cell #(
                    .FACTOR_0_WIDTH(SIGNAL_WIDTH),
                    .FACTOR_1_WIDTH(COEFF_WIDTH),
                    .ADDEND_WIDTH  (TRAN_WIDTH[tap_id-1]),
                    .RESULT_WIDTH  (TRAN_WIDTH[tap_id])
                ) u_mac (
                    .factor_0_i(x_tap[tap_id]),
                    .factor_1_i(COEFFS[COEFF_NUM-1-tap_id]),
                    .addend_i  (delay_line_ff[tap_id-1]),
                    .result_o  (mac_result[tap_id])
                );

            end : g_tap

            assign signal_o = mac_result[COEFF_NUM-1];

        end : g_transposed_arch
    endgenerate

endmodule