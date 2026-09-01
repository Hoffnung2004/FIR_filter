module serdes_in#(
    parameter int P        = 3,
    parameter int BITS_W   = 8,
    parameter int REVERSE   = 1,
    parameter int FIRST_ONE = 0
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic [BITS_W-1:0] data_i,
    output logic new_data,
    output logic new_data2,
    output logic [BITS_W-1:0] data_o [0:P-1]
);
    logic [BITS_W-1:0] memory_ff [0:P-1];
    logic memory_stat_ff [0:P-1];
    logic for_new_data;
    logic [BITS_W-1:0] data_tmp; 
    if(P==1) begin
        
        
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                if(FIRST_ONE==1) begin
                    data_tmp<=1'b1;
                end else begin
                    data_tmp<=1'b0;
                end
            end else if(enable_i) begin
                data_tmp<=data_i;
            end
        end

    
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                memory_stat_ff[0]<=1'b1;
                memory_ff[0]<='0;
            end else if(enable_i) begin
                memory_ff[0]<=data_i;
            end
        end
    
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                data_o[0]<='0;
            end else if(enable_i&memory_stat_ff[0]) begin
                 data_o[0]<=memory_ff[0];
            end
        end        
        
        always @(posedge clk_i) begin
            if(reset_i) begin
                new_data<=1'b0;
                for_new_data<=1'b0;
                new_data2<=1'b0;
            end else if(enable_i) begin
                new_data<=memory_stat_ff[0];
                for_new_data<=memory_stat_ff[0]^for_new_data;
                new_data2<=for_new_data&memory_stat_ff[0];
            end
        end
        
    end else begin 
    
    
    
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                if(FIRST_ONE==1) begin
                    data_tmp<=1'b1;
                end else begin
                    data_tmp<=1'b0;
                end
            end else if(enable_i) begin
                data_tmp<=data_i;
            end
        end

    
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                memory_stat_ff[0]<=1'b1;
                for(int i=1; i<P; i++) memory_stat_ff[i]<=1'b0;
                for(int i=0; i<P; i++) memory_ff[i]<='0;
            end else if(enable_i) begin
                memory_ff<={data_tmp,memory_ff[0:P-2]};
                memory_stat_ff<={memory_stat_ff[P-1],memory_stat_ff[0:P-2]};
            end
        end
    
        always_ff @(posedge clk_i) begin
            if(reset_i) begin
                for(int i=0; i<P; i++) data_o[i]<='0;
            end else if(enable_i&memory_stat_ff[0]) begin
            
                if(REVERSE) begin
                    for(int i=0; i<P; i++) data_o[i]<=memory_ff[P-i-1];
                end else begin
                    data_o<=memory_ff;
                end
            end
        end
    
        always @(posedge clk_i) begin
            if(reset_i) begin
                new_data<=1'b0;
                for_new_data<=1'b0;
                new_data2<=1'b0;
            end else if(enable_i) begin
                new_data<=memory_stat_ff[0];
                for_new_data<=memory_stat_ff[0]^for_new_data;
                new_data2<=for_new_data&memory_stat_ff[0];
            end
        end
    end
endmodule
