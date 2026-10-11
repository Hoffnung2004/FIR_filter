//////////////////////////////////////////////////////////////////////////////////
// Only for tesbench. Not for design
//////////////////////////////////////////////////////////////////////////////////

module recordDELAY #(
    parameter BITS_W = 4
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic [BITS_W-1:0] signal1_i,
    input logic [BITS_W-1:0] signal2_i,
    output logic [31:0] delay_o
    );
    logic signed [0:31] memory_ff;
    logic enable;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            memory_ff<='0;
            enable<=1'b1;
        end else begin
            if(signal1_i!=0 && signal2_i!=0) begin
                enable<=1'b0;
            end else if((signal1_i!=0 || signal2_i!=0) & enable) begin
                memory_ff = memory_ff + 1;
            end
        end
    end
    assign delay_o = memory_ff;
endmodule


// valid_check - ловец рассинхрона valid_o / data_o 
module valid_check #(
    parameter BITS_W = 4
)(
    input  logic clk_i,
    input  logic reset_i,
    input  logic valid_i,                     // valid_o фильтра
    input  logic order_sel_i,                 // текущий order_sel на входе
    input  logic signed [BITS_W-1:0] data_i,  // data_o фильтра
    input  logic signed [BITS_W-1:0] gold_n_i,     // эталон N
    input  logic signed [BITS_W-1:0] gold_half_i,  // эталон N/2

    output logic match_o,         // данные совпадают хотя бы с одним эталоном
    output logic false_valid_o,   // valid=1, а данные не совпали ни с одним эталоном (мусор наружу)
    output logic missed_valid_o,  // valid=0, а данные уже правильные (потеря отсчётов)
    output logic [31:0] false_cnt_o,
    output logic [31:0] missed_cnt_o,
    output logic [31:0] since_switch_o // тактов с последнего переключения order_sel
);
    logic order_ff;

    assign match_o        = (data_i != 0) && ((data_i == gold_n_i) || (data_i == gold_half_i));
    assign false_valid_o  = !reset_i &&  valid_i && !match_o;
    assign missed_valid_o = !reset_i && !valid_i &&  match_o;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            false_cnt_o    <= '0;
            missed_cnt_o   <= '0;
            since_switch_o <= '0;
            order_ff       <= order_sel_i;
        end else begin
            order_ff <= order_sel_i;
            since_switch_o <= (order_ff != order_sel_i) ? 32'd0 : since_switch_o + 1;
            if (false_valid_o)  false_cnt_o  <= false_cnt_o  + 1;
            if (missed_valid_o) missed_cnt_o <= missed_cnt_o + 1;
        end
    end
endmodule