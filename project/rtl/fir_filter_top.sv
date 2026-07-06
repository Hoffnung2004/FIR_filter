`timescale 1ns / 1ps

import fir_filter_params_pkg::*;

module fir_filter_top
#(
    parameter int ARCHITECTURE = 1 //ВЫБОР АРХИТЕКТУРЫ 0 - дерево, 1 - транспонированная
)(
    input  logic clk_i,
    input  logic reset_i, //не используется, добавлен так как есть в тб
    input  logic signed [SIGNAL_WIDTH-1:0] signal_i,
    output logic signed [RESULT_WIDTH-1:0] signal_o
);

wire unused_reset_i = reset_i;
    generate
        if (ARCHITECTURE == 0) begin : g_tree_arch
                logic signed [SIGNAL_WIDTH-1:0] tap_line [0:COEFF_NUM-1];

    always_ff @(posedge clk_i) begin
        tap_line[0] <= signal_i;

        for (int i = 1; i < COEFF_NUM; i++) begin
            tap_line[i] <= tap_line[i-1];
        end
    end

    logic signed [RESULT_WIDTH-1:0] tree_q [0:TREE_LEN-1][0:COEFF_NUM-1];

    for (genvar mul_i = 0; mul_i < TREE_WIDTH[0]; mul_i++) begin : gen_level0
        localparam int W = TREE_BIT_WIDTH[0][mul_i];

        logic signed [W-1:0] result_comb;
        logic signed [W-1:0] q;

        filter_cell #(
            .FACTOR_0_WIDTH(SIGNAL_WIDTH),
            .FACTOR_1_WIDTH(COEFF_WIDTH),
            .ADDEND_WIDTH  (1),
            .RESULT_WIDTH  (W)
        ) mul_cell (
            .i_factor_0(tap_line[mul_i]),
            .i_factor_1(COEFFS[mul_i]),
            .i_addend  (1'sd0),
            .o_result  (result_comb)
        );

        always_ff @(posedge clk_i) begin
            q <= result_comb;
        end

        assign tree_q[0][mul_i] = $signed(q);
    end

    for (genvar level_i = 1; level_i < TREE_LEN; level_i++) begin : gen_level
        for (genvar node_i = 0; node_i < TREE_WIDTH[level_i]; node_i++) begin : gen_node
            localparam int W = TREE_BIT_WIDTH[level_i][node_i];

            logic signed [W-1:0] src_ext   [0:TREE_STEP-1];
            logic signed [W-1:0] sum_chain [0:TREE_STEP];
            logic signed [W-1:0] q = '0;

            assign sum_chain[0] = '0;

            for (genvar term_i = 0; term_i < TREE_STEP; term_i++) begin : gen_term
                localparam int SRC_IDX = node_i * TREE_STEP + term_i;

                if (SRC_IDX < TREE_WIDTH[level_i-1]) begin : gen_valid_term
                    assign src_ext[term_i] = $signed(tree_q[level_i-1][SRC_IDX]);
                end else begin : gen_empty_term
                    assign src_ext[term_i] = '0;
                end

                assign sum_chain[term_i+1] = sum_chain[term_i] + src_ext[term_i];
            end

            always_ff @(posedge clk_i) begin
                q <= sum_chain[TREE_STEP];
            end

            assign tree_q[level_i][node_i] = $signed(q);
        end
    end

    assign signal_o = tree_q[TREE_LEN-1][0];
        end
        else begin : g_transposed_arch

            (* dont_touch = "yes" *)
            logic signed [0:COEFF_NUM-1][SIGNAL_WIDTH-1:0] tree_node [0:INPUT_TREE_LEN-1];
            
            // уровень 0
            always_ff @(posedge clk_i) begin
                tree_node[0][0] <= signal_i;
            end
            
            for (genvar lvl = 1; lvl < INPUT_TREE_LEN; lvl++) begin : g_tree_lvl
                for (genvar node = 0; node < INPUT_TREE_WIDTH[lvl]; node++) begin : g_tree_node
                    localparam int PARENT = node / INPUT_TREE_STEP;
                    
                    always_ff @(posedge clk_i) begin
                        tree_node[lvl][node] <= tree_node[lvl-1][PARENT];
                    end
                end
            end
            
            // листья дерева
            logic signed [SIGNAL_WIDTH-1:0] x_tap [0:COEFF_NUM-1];
            for (genvar i = 0; i < COEFF_NUM; i++) begin : g_x_tap
                assign x_tap[i] = tree_node[INPUT_TREE_LEN-1][i];
            end

            logic signed [RESULT_WIDTH-1:0] mac_result [0:COEFF_NUM-1];
            logic signed [RESULT_WIDTH-1:0] delay_line [0:COEFF_NUM-2];

            // нулевой коэффициент
            filter_cell #(
                .FACTOR_0_WIDTH(SIGNAL_WIDTH),
                .FACTOR_1_WIDTH(COEFF_WIDTH),
                .ADDEND_WIDTH  (1),
                .RESULT_WIDTH  (TRAN_WIDTH[0])
            ) u_mac_0 (
                .i_factor_0(x_tap[0]),
                .i_factor_1(COEFFS[COEFF_NUM-1]),
                .i_addend  (1'b0),
                .o_result  (mac_result[0])
            );

            always_ff @(posedge clk_i) begin
                delay_line[0] <= mac_result[0];
            end

            for (genvar i = 1; i < COEFF_NUM; i++) begin : g_tap
                filter_cell #(
                    .FACTOR_0_WIDTH(SIGNAL_WIDTH),
                    .FACTOR_1_WIDTH(COEFF_WIDTH),
                    .ADDEND_WIDTH  (TRAN_WIDTH[i-1]),
                    .RESULT_WIDTH  (TRAN_WIDTH[i])
                ) u_mac (
                    .i_factor_0(x_tap[i]),
                    .i_factor_1(COEFFS[COEFF_NUM-1-i]),
                    .i_addend  (delay_line[i-1]),
                    .o_result  (mac_result[i])
                );

                if (i < COEFF_NUM-1) begin : g_delay_reg
                    always_ff @(posedge clk_i) begin
                        delay_line[i] <= mac_result[i];
                    end
                end
            end

            assign signal_o = mac_result[COEFF_NUM-1];

        end
    endgenerate

endmodule
