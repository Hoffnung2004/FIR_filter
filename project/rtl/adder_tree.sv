`timescale 1ns / 1ps

module adder_tree #(
    parameter int NUM_INPUTS = 5, 
    parameter int BITS_W = 48,    
    parameter int LEVEL = 0        
)(
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     reset_i,
    input  logic signed [BITS_W-1:0] inputs_i [0:NUM_INPUTS-1],
    output logic signed [BITS_W-1:0] summ_o
);

    // Вычисляем параметры для следующего уровня рекурсии
    localparam int NUM_PAIRS       = NUM_INPUTS / 2;
    localparam int HAS_ODD         = NUM_INPUTS % 2;
    localparam int NEXT_NUM_INPUTS = NUM_PAIRS + HAS_ODD;

    logic signed [BITS_W-1:0] next_level_inputs [0:NEXT_NUM_INPUTS-1];

    generate
        if(NUM_INPUTS==1) begin : gen_base
            assign summ_o = inputs_i[0];
        end else begin : gen_recursive
            for (genvar i = 0; i < NUM_PAIRS; i++) begin : gen_adders_pairs
                adder #(
                    .N(BITS_W)
                )u_adder_pair(
                    .clk_i(clk_i),
                    .enable_i(enable_i),
                    .reset_i(reset_i),
                    .a_i(inputs_i[2*i]),
                    .b_i(inputs_i[2*i+1]),
                    .summ(next_level_inputs[i])
                );
            end

            if (HAS_ODD) begin : gen_adders_odd
                adder #(
                    .N(BITS_W)
                ) u_adder_dummy (
                    .clk_i(clk_i),
                    .enable_i(enable_i),
                    .reset_i(reset_i),
                    .a_i(inputs_i[NUM_INPUTS-1]),
                    .b_i('0),  // Складываем с нулем. Так и надо
                    .summ(next_level_inputs[NUM_PAIRS])
                );
            end

            adder_tree #(
                .NUM_INPUTS(NEXT_NUM_INPUTS),
                .BITS_W(BITS_W),
                .LEVEL(LEVEL + 1)
            ) u_next_level(
                .clk_i(clk_i),
                .enable_i(enable_i),
                .reset_i(reset_i),
                .inputs_i(next_level_inputs),
                .summ_o(summ_o)
            );
            
        end
    endgenerate

endmodule
