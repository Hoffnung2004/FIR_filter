`timescale 1ns / 1ps

module polyphase#(
    parameter int P = 3,        // Число фаз 
    parameter int TAPS_PER_PHASE  = 8, // Число тапсов на фазу
    parameter BITS_W = 40 // (32/5+$clog2(TAPS_PER_PHASE*P)/5)*8 делю на 5 вместо 8, чтобы округлить вверх
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic signed [15:0] signal_i [0:P-1],
    input logic signed [15:0] h_i [0:P-1][0:TAPS_PER_PHASE-1],
    output logic signed [BITS_W-1:0] signal_o [0:P-1]
    );
    
    logic signed [15:0] filter_in [0:P-1][0:P-1];
    logic signed [BITS_W-1:0] filter_out [0:P-1][0:P-1];
    logic signed [BITS_W-1:0] delay_out [0:P-1][0:P-1];
    logic signed [BITS_W-1:0] to_adders [0:P-1][0:P-1];
    
    
    
    generate
        genvar phase_out;
        genvar phase_in;
        genvar taps;
        
        for(genvar phase_in = 0; phase_in < P; phase_in++) begin
            for(genvar num_fil = 0; num_fil < P; num_fil++) begin
                assign filter_in[phase_in][num_fil] = signal_i[phase_in];
            end
        end
        
        
        for(phase_out=0; phase_out<P; phase_out++) begin
            
            for(taps=0; taps<P; taps++) begin
            
                localparam int DELAY_VAL = (phase_out >= taps) ? 0 : 1;
                localparam int PHASE_IN = (phase_out >= taps) ? phase_out-taps : phase_out-taps+P;
                
                 delay #(
                    .D (DELAY_VAL),  
                    .W (BITS_W)
                 )u_delay (
                    .reset_i(reset_i),
                    .clk_i(clk_i),
                    .enable_i(enable_i),
                    .signal_i(filter_out[PHASE_IN][taps]),
                    .signal_o(delay_out[PHASE_IN][taps])
                 );
                 
                 param_filter #(
                    .N(TAPS_PER_PHASE),
                    .BITS_W(BITS_W)
                    )(
                    .reset_i(reset_i),
                    .clk_i(clk_i),
                    .enable_i(enable_i),
                    .signal_i(filter_in[phase_out][taps]),
                    .taps_i(h_i[taps]),
                    .signal_o(filter_out[phase_out][taps])
                    );
                    
                    assign to_adders[phase_out][taps] = delay_out[PHASE_IN][taps];
            end
        end

        
        for(phase_out=0; phase_out<P; phase_out++) begin
            adder_tree #(
            .BITS_W(BITS_W),
            .NUM_INPUTS(P)
            ) add_three(
            .reset_i(reset_i),
            .clk_i(clk_i),
            .enable_i(enable_i),
            .inputs_i(delay_out[phase_out]),
            .summ_o(signal_o[phase_out])
    );
        end
    endgenerate 
    
endmodule
