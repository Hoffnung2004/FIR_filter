module booth_encoder_mini(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input  logic [2:0] D_i,
    output logic neg_o,
    output logic two_o,
    output logic one_o,
    output logic cor_o,
    output logic zero_o
    );
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            neg_o <= 1'b0;
            two_o <= 1'b0;
            one_o <= 1'b0;
            cor_o <= 1'b0;
            zero_o <= 1'b0;
        end else if(enable_i) begin
            neg_o <= D_i[2];
            two_o <= D_i[2]&(!D_i[1])&(!D_i[0]) | (!D_i[2])&D_i[1]&D_i[0];
            one_o <= D_i[1]^D_i[0];
            cor_o <= D_i[2]&(!(D_i[1]&D_i[0]));
            zero_o <= (D_i[1] == D_i[2]) & (D_i[0] == D_i[2]);
        end
    end
    
endmodule
