module serdes_out#(
    parameter int P        = 3,
    parameter int BITS_W   = 8,
    parameter int REVERSE   = 1
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic [BITS_W-1:0] data_i [0:P-1],
    input logic new_data,
    output logic [BITS_W-1:0] data_o
);
    logic [BITS_W-1:0] memory_ff [0:P-1];
    logic [BITS_W-1:0] data_i_tmp [0:P-1];
    
    always_comb begin
        if (REVERSE) begin
            data_i_tmp = data_i;
        end else begin
             for (int i = 0; i < P; i++) begin
                data_i_tmp[i] = data_i[P - 1 - i];
            end
        end
    end
    
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            for(int i=0; i<P; i++) memory_ff[i]<='0;
        end else if(enable_i) begin
            if (new_data) begin
                memory_ff <= data_i_tmp; 
            end else begin
                for (int i = 0; i < P - 1; i++) begin
                    memory_ff[i] <= memory_ff[i+1];
                end
                memory_ff[P-1] <= '0; 
            end
        end
    end
    
    assign data_o=memory_ff[0];
    
endmodule
