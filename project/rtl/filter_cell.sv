module filter_cell #(
    parameter int FACTOR_0_WIDTH = 16,
    parameter int FACTOR_1_WIDTH = 16,
    parameter int ADDEND_WIDTH   = 40,
    parameter int RESULT_WIDTH   = 40
)(
    input  logic signed [FACTOR_0_WIDTH-1:0] i_factor_0,
    input  logic signed [FACTOR_1_WIDTH-1:0] i_factor_1,
    input  logic signed [ADDEND_WIDTH-1:0]   i_addend,

    output logic signed [RESULT_WIDTH-1:0]   o_result
);

    logic signed [FACTOR_0_WIDTH+FACTOR_1_WIDTH-1:0] product;
    logic signed [RESULT_WIDTH-1:0] product_ext;
    logic signed [RESULT_WIDTH-1:0] addend_ext;

    assign product = $signed(i_factor_0) * $signed(i_factor_1);

    assign product_ext = $signed(product);
    assign addend_ext  = $signed(i_addend);

    assign o_result = product_ext + addend_ext;

endmodule