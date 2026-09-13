module filter_cell #(
    parameter int FACTOR_0_WIDTH = 16,
    parameter int FACTOR_1_WIDTH = 16,
    parameter int ADDEND_WIDTH   = 40,
    parameter int RESULT_WIDTH   = 40
)(
    input  logic signed [FACTOR_0_WIDTH-1:0] factor_0_i,
    input  logic signed [FACTOR_1_WIDTH-1:0] factor_1_i,
    input  logic signed [ADDEND_WIDTH-1:0]   addend_i,

    output logic signed [RESULT_WIDTH-1:0]   result_o
);

    logic signed [FACTOR_0_WIDTH+FACTOR_1_WIDTH-1:0] product;
    logic signed [RESULT_WIDTH-1:0] product_ext;
    logic signed [RESULT_WIDTH-1:0] addend_ext;

    assign product = factor_0_i * factor_1_i;

    assign product_ext = product;
    assign addend_ext  = addend_i;

    assign result_o = product_ext + addend_ext;

endmodule