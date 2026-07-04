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

    generate
        if (ARCHITECTURE == 0) begin : g_tree_arch
            assign signal_o = '0; // МЕСТО ПОД ФИЛЬТР ДЕРЕВО
        end
        else begin : g_transposed_arch

            logic signed [SIGNAL_WIDTH-1:0] input_tree [0:INPUT_TREE_LEN-1][0:COEFF_NUM-1];
            logic signed [SIGNAL_WIDTH-1:0] x_tap     [0:COEFF_NUM-1];

            always_ff @(posedge clk_i) begin
                input_tree[0][0] <= signal_i; 
            end

            for (genvar lvl = 1; lvl < INPUT_TREE_LEN; lvl++) begin : g_in_tree_lvl
                for (genvar node = 0; node < INPUT_TREE_WIDTH[lvl]; node++) begin : g_in_tree_node
                    always_ff @(posedge clk_i) begin
                        input_tree[lvl][node] <= input_tree[lvl-1][node / INPUT_TREE_STEP];
                    end
                end
            end

            for (genvar i = 0; i < COEFF_NUM; i++) begin : g_x_tap
                assign x_tap[i] = input_tree[INPUT_TREE_LEN-1][i];
            end

            logic signed [RESULT_WIDTH-1:0] mac_result [0:COEFF_NUM-1];
            logic signed [RESULT_WIDTH-1:0] delay_line [0:COEFF_NUM-2];

            //нулевой коэффициент
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