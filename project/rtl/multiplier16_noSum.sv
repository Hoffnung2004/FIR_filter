module multiplier16_noSum(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic signed [15:0] a_i,
    input logic signed [15:0] b_i,
    output logic signed [31:0] part_prod_o [7:0]
    );
    logic signed [15:0] number;
    logic signed [15:0] number_inv;
    logic signed [15:0] number_ff;
    logic signed [15:0] number_inv_ff;
    logic [7:0] neg;
    logic [7:0] two;
    logic [7:0] one;
    logic [7:0] cor;
    logic [7:0] zero;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            number_ff<=16'b0;
            number_inv_ff<=16'b0;
        end else if(enable_i) begin
            number_ff<=number;
            number_inv_ff<=number_inv;
        end
    end
    
    one_complement one_comp(
    .clk_i(clk_i),
    .enable_i(enable_i),
    .reset_i(reset_i),
    .number_i(a_i),
    .number_o(number),
    .number_inv_o(number_inv)
    );
    
    booth_encoder booth_enc(
    .clk_i(clk_i),
    .enable_i(enable_i),
    .reset_i(reset_i),
    .number_i(b_i),
    .neg_o(neg),
    .two_o(two),
    .one_o(one),
    .cor_o(cor),
    .zero_o(zero)
    );
    
    partical_product_generator part_prod_gen(
    .clk_i(clk_i),
    .enable_i(enable_i),
    .reset_i(reset_i),
    .number_i(number_ff),
    .number_inv_i(number_inv_ff),
    .neg_i(neg),
    .two_i(two),
    .one_i(one),
    .cor_i(cor), 
    .zero_i(zero),
    .part_prod_o(part_prod_o)
    );



    
endmodule