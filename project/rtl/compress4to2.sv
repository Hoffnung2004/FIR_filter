module compress4to2(
    input logic x1_i,
    input logic x2_i,
    input logic x3_i,
    input logic x4_i,
    input logic c_i,
    output logic s_o,
    output logic c1_o,
    output logic c_o
    );
    logic s;
    assign s = x2_i^x3_i^x4_i;
    assign c1_o = (x2_i&x3_i)|(x3_i&x4_i)|(x2_i&x4_i);
    assign s_o = x1_i^c_i^s;
    assign c_o = (x1_i&c_i)|(x1_i&s)|(c_i&s);
endmodule
