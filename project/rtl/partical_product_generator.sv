module partical_product_generator(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic [15:0] number_i,
    input logic [15:0] number_inv_i,
    input logic [7:0] neg_i,
    input logic [7:0] two_i,
    input logic [7:0] one_i,
    input logic [7:0] cor_i, // dont use
    input logic [7:0] zero_i,
    output logic signed [31:0] part_prod_o [7:0]
);
    logic signed [31:0] part_prod_next [7:0];
    logic signed [15:0] number_tmp [7:0];
    
    generate
        for(genvar i=0; i<8; i++) begin
            always @(*) begin
                  if(zero_i[i])  number_tmp[i]=16'b0;
                  else if(neg_i[i]) number_tmp[i]=number_inv_i;
                  else number_tmp[i] = number_i;
                  
                  if(two_i[i]) begin
                      part_prod_next[i][2*i:0] = {(2*i+1) {1'b0}};
                      part_prod_next[i][2*i+16:2*i+1] = number_tmp[i];
                      part_prod_next[i][31:2*i+17] = {(31-2*i-17+1) {number_tmp[i][15]}};
                  end else begin
                      if(i>0) part_prod_next[i][2*i-1:0] = {(2*i) {1'b0}};
                      part_prod_next[i][2*i+15:2*i] = number_tmp[i];
                      part_prod_next[i][31:2*i+16] = {(31-2*i-16+1) {number_tmp[i][15]}};
                  end
            end
        end
    endgenerate
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for (int i = 0; i < 8; i++) begin
                part_prod_o[i] <= 32'b0;
            end
        end else if(enable_i) begin
            part_prod_o<=part_prod_next;
        end
    end

endmodule