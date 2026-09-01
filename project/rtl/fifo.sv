module fifo
#(
    parameter BITS_W = 16,
    parameter IMPORTANT_BITS_W = 1,
    parameter POW = 4,
    localparam SIZE = 1<<POW,
    localparam MAX_INF = SIZE*3/4
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    
    input logic [BITS_W-1:0] data_i,
    input logic [IMPORTANT_BITS_W-1:0] important_i,
    input logic valid_i,
    output logic ready_i,
    
    output logic [BITS_W-1:0] data_o,
    output logic [IMPORTANT_BITS_W-1:0] important_o,
    output logic valid_o,
    input logic ready_o
    );
    logic handshacke_in;
    logic handshacke_out;
    
    logic [BITS_W-1:0] memory_ff [0:SIZE-1];
    logic [IMPORTANT_BITS_W-1:0] important_ff [0:SIZE-1];
    logic [POW-1:0] addr_in_ff;
    logic [POW-1:0] addr_out_ff;
    
    logic [POW-1:0] addr_delta;
    
    assign addr_delta = addr_in_ff - addr_out_ff;
    assign data_o = memory_ff[addr_out_ff];
    assign important_o = important_ff[addr_out_ff];
    
    always_comb begin
        if(addr_delta<MAX_INF) begin
            ready_i = enable_i;
        end else begin
            ready_i = 0;
        end
        if(addr_out_ff!=addr_in_ff) begin
            valid_o = enable_i;
        end else begin
            valid_o = 0;
        end
    end
    
    assign handshacke_in = valid_i & ready_i;
    assign handshacke_out = valid_o & ready_o;
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            addr_in_ff<='0;
            addr_out_ff<='0;
        end else begin
            if(handshacke_in) begin
                memory_ff[addr_in_ff]<=data_i;
                important_ff[addr_in_ff]<=important_i;
                addr_in_ff <= addr_in_ff + 1;
            end
                
            if(handshacke_out) begin
                //memory_ff[addr_out_ff]<='0; // ракомментировать для более комфортного дебага
                addr_out_ff <= addr_out_ff + 1;
            end
        end
    end
endmodule
