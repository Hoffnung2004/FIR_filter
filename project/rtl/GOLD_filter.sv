module GOLD_filter
#(
    parameter int TAPS   = 8,
    parameter int BITS_W           = fir_pkg::bits_sum(TAPS, 1)
)(
    input logic clk_i,
    input logic reset_i,
    input logic [15:0] signal_i,
    input logic [15:0] h_i [0:TAPS-1],
    output logic [BITS_W-1:0] signal_o
    );
    
    logic [15:0] memory_ff [0:TAPS-1];
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for(int i=0; i<TAPS; i++) begin
                memory_ff[i]<='0;
            end
        end else begin
            memory_ff<={signal_i,memory_ff[0:TAPS-1]};
        end
    end
    
    always_comb begin
        logic signed [BITS_W-1:0] sum;
        sum = '0;
        for (int tap = 0; tap < TAPS; tap++) begin
            sum += memory_ff[tap] * coeff_i[tap];
        end
        signal_o = sum;
    end
    
endmodule
