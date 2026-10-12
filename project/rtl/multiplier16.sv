module multiplier16(
    input logic clk_i,
    input logic enable_i,
    input logic reset_i,
    input logic signed [15:0] a_i,
    input logic signed [15:0] b_i,
    output logic signed [31:0] m_o
    );

    logic signed [31:0] part_prod1 [7:0];
    logic signed [31:0] part_prod2 [3:0];
    logic signed [31:0] part_prod3 [1:0];
    
    multiplier16_noSum part_gen(
     .clk_i(clk_i),
     .enable_i(enable_i),
     .reset_i(reset_i),
     .a_i(a_i),
     .b_i(b_i),
     .part_prod_o(part_prod1)
    );

    genvar i; 

    generate
        for (i = 0; i < 4; i++) begin : gen_add1
            adder add_inst (
                .clk_i(clk_i),
                .enable_i(enable_i),
                .reset_i(reset_i),
                .a_i(part_prod1[i]),
                .b_i(part_prod1[i+4]),
                .summ(part_prod2[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < 2; i++) begin : gen_add2
            adder add_inst (
                .clk_i(clk_i),
                .enable_i(enable_i),
                .reset_i(reset_i),
                .a_i(part_prod2[i]),
                .b_i(part_prod2[i+2]),
                .summ(part_prod3[i])
            );
        end
    endgenerate

    adder add3 (
        .clk_i(clk_i),
        .enable_i(enable_i),
        .reset_i(reset_i),
        .a_i(part_prod3[0]),
        .b_i(part_prod3[1]),
        .summ(m_o)
    );

    
endmodule