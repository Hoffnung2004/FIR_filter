module diff_detect(
    input logic clk_i,
    input logic enable_i,
    input logic signal_i,
    input logic reset_i,
    output logic diff_o,
    output logic sign_o // = 0 => signal _|-, = 1 => signal -|_
    );
    
    logic signal_old_ff;
    logic signal_ff;
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            signal_ff<=signal_i;
            signal_old_ff<=signal_i;
        end else if(enable_i) begin
            signal_ff<=signal_i;
            signal_old_ff<=signal_ff;
        end           
    end  
    
    assign diff_o = signal_ff^signal_old_ff;
    assign sign_o = signal_old_ff&(~signal_ff);
    
endmodule
