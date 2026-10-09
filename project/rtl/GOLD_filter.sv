module GOLD_filter
#(
    parameter int TAPS   = 8,
    parameter int BITS_W           = poly_filter_pkg::bits_sum(TAPS, 1),
    parameter int DELAY = 0
)(
    input logic clk_i,
    input logic reset_i,
    input logic signed [15:0] signal_i,
    input logic signed [15:0] h_i [0:TAPS-1],
    output logic signed [BITS_W-1:0] signal_o
    );
    
    logic signed [15:0] memory_ff [0:TAPS-1];
    logic signed [BITS_W-1:0] summ;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for(int i=0; i<TAPS; i++) begin
                memory_ff[i]<='0;
            end
        end else begin
            memory_ff<={signal_i,memory_ff[0:TAPS-2]};
        end
    end
    
    always_comb begin
        logic signed [BITS_W-1:0] sum;
        sum = '0;
        for (int tap = 0; tap < TAPS; tap++) begin
            sum += memory_ff[tap] * h_i[tap];
        end
        summ = sum;
    end
    
    delay#(
        .D(DELAY),   
        .W(BITS_W)    
    ) delay_gold(
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(1'b1),
        .signal_i(summ),
        .signal_o(signal_o)
    );
endmodule
