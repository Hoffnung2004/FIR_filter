module booth_encoder(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic [15:0] number_i,
    output logic [7:0] neg_o,
    output logic [7:0] two_o,
    output logic [7:0] one_o,
    output logic [7:0] cor_o,
    output logic [7:0] zero_o
    );
    logic [16:0] number_tmp;
    assign number_tmp = {number_i,1'b0};
    
    generate
    for(genvar i=0; i<8; i++) begin
        booth_encoder_mini booth_enc_mini(
            .clk_i(clk_i),
            .enable_i(enable_i),
            .reset_i(reset_i),
            .D_i(number_tmp[2*i+2:2*i]),
            .neg_o(neg_o[i]),
            .two_o(two_o[i]),
            .one_o(one_o[i]),
            .cor_o(cor_o[i]),
            .zero_o(zero_o[i])
        );
    end
    endgenerate
    
 endmodule