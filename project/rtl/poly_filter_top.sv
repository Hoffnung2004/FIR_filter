package fir_pkg;
    function automatic int bits_phase(input int taps_per_phase);
        return ((32 + $clog2(taps_per_phase) + 7) / 8) * 8;
    endfunction

    function automatic int bits_sum(input int taps_per_phase, input int p);
        return ((bits_phase(taps_per_phase) + $clog2(p) + 7) / 8) * 8;
    endfunction
    
    function automatic int delay(input int taps_per_phase, input int p);
        int mult_latancy = 21;
        int bw = bits_sum(taps_per_phase,p);
        
        int serdes_in = 1;
        int phase = mult_latancy + $clog2(taps_per_phase)*(bw/8+2)+2;
        int poly_phase = $clog2(p)*(bw/8+2);
        
        return serdes_in+phase+poly_phase+1;
    endfunction
    
    function automatic int delay_halfN(input int taps_per_phase, input int p);
        int mult_latancy = 21;
        int bw = bits_sum(taps_per_phase,p);
        
        int serdes_in = 1;
        int phase = (mult_latancy + $clog2(taps_per_phase)*(bw/8+2))*2+3;
        int poly_phase = $clog2(p)*(bw/8+2);
        
        return serdes_in+phase+poly_phase+1;
    endfunction
    
    function automatic int delay_after(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        int poly_phase = $clog2(p)*(bw/8+2)+1;
        return poly_phase;
    endfunction
    
    function automatic int delay_bw(input int taps_per_phase, input int p);
        return $clog2(delay_halfN(taps_per_phase,p))+2; // Чтобы счётчик при реконфигаруации фильтра не переполнился прибвавил +2 а не +1
    endfunction
endpackage

module poly_filter_top
#(
    parameter int P                = 3,
    parameter int TAPS_PER_PHASE   = 12,
    parameter int BITS_PER_PHASE_W = fir_pkg::bits_phase(TAPS_PER_PHASE),
    parameter int BITS_W           = fir_pkg::bits_sum(TAPS_PER_PHASE, P)
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic order_sel_i,
    
    input logic [15:0] data_i,
    input logic valid_i,
    output logic ready_i,
    
    output logic [BITS_W-1:0] data_o,
    output logic valid_o,
    input logic ready_o
    );
    
    logic enable;
    logic module_enable;
    logic [15:0] fifo_out;
    logic [15:0] h [0:P-1][0:TAPS_PER_PHASE-1];
    logic [15:0] phase_in [0:P-1];
    logic [BITS_W-1:0] phase_out [0:P-1];
    logic clk_P;
    logic clk_2P;
    logic [BITS_W-1:0] pre_out;
    logic out_valid;
    localparam DELAY = fir_pkg::delay(TAPS_PER_PHASE,P);
    localparam DELAY_HALF_N = fir_pkg::delay_halfN(TAPS_PER_PHASE,P);
    localparam DELAY_BW = fir_pkg::delay_bw(TAPS_PER_PHASE,P);
    localparam DELAY_AFTER = fir_pkg::delay_after(TAPS_PER_PHASE,P);
    logic signed [DELAY_BW-1:0] valid_counter;
    logic signed [DELAY_BW-1:0] valid_counter_after;
    logic signed [DELAY_BW-1:0] valid_next;
    logic pre_valid;
    logic valid_delay [0:3];
    logic valid_delay_after [0:3];
    logic order_sel_old;
    logic reconf;
    
    assign module_enable=enable&(ready_o | !out_valid);
    assign pre_valid = valid_counter==0;
    
    fifo #( // Каждый такт - отсчёт
        .BITS_W(16),
        .POW(4)
    ) fifo_in (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(enable_i),
        .data_i(data_i),
        .valid_i(valid_i),
        .ready_i(ready_i),
        .data_o(fifo_out),
        .valid_o(enable),
        .ready_o(ready_o | !out_valid)
    );
    
    coeff_storage_axi_lite #(
        .COEFF_WIDTH(16),
        .PHASE_NUM(P),
        .TAPS_PER_PHASE(TAPS_PER_PHASE),
        .AXI_DATA_WIDTH(32),
        .AXI_ADDR_WIDTH(6)
    ) coeff_storage (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(enable_i),

        .s_axi_awaddr(), // [AXI_ADDR_WIDTH-1:0]
        .s_axi_awprot(), // [2:0]
        .s_axi_awvalid(),
        .s_axi_awready(),

        .s_axi_wdata(), // [AXI_DATA_WIDTH-1:0]
        .s_axi_wstrb(), // [AXI_DATA_WIDTH/8-1:0]
        .s_axi_wvalid(),
        .s_axi_wready(),
        .s_axi_bresp(), // [1:0]
        .s_axi_bvalid(),
        .s_axi_bready(),
        .s_axi_araddr(), // [AXI_ADDR_WIDTH-1:0]
        .s_axi_arprot(), // [2:0]
        .s_axi_arvalid(),
        .s_axi_arready(),
        .s_axi_rdata(), //[AXI_DATA_WIDTH-1:0]
        .s_axi_rresp(), // [1:0]
        .s_axi_rvalid(),
        .s_axi_rready(),
        .coeff_o(h),
        .busy_o(),
        .done_o()
    );
    
    
    serdes_in  #( // Каждые P тактов - отсчёт
            .P(P),
            .BITS_W(16),
            .REVERSE(1)
        ) serder_to_poly (
            .reset_i(reset_i),
            .clk_i(clk_i),
            .enable_i(module_enable),
            .data_i(fifo_out),
            .data_o(phase_in),
            .new_data(clk_P),
            .new_data2(clk_2P)
        );
    
    polyphase#(
        .P(P), 
        .TAPS_PER_PHASE(TAPS_PER_PHASE), 
        .BITS_W(BITS_W)
    ) polyphase_struct (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(clk_P),
        .strob_i(clk_2P),
        .order_sel_i(order_sel_i),
        .signal_i(phase_in),
        .h_i(h),
        .signal_o(phase_out)
    );
    
    serdes_out#(
        .P(P),
        .BITS_W(BITS_W),
        .REVERSE(1)
    ) serdeser_out (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(module_enable),
        .data_i(phase_out),
        .new_data(clk_P),
        .data_o(pre_out)
    );
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
          //  out_valid <= 1'b0;
            data_o <= '0;
        end else begin
          //  out_valid <= 1'b1;
            data_o<=pre_out;
        end
    end
    
    always_comb begin
        case({order_sel_i,order_sel_old})
            2'b00: valid_next = valid_counter;
            2'b01: valid_next = -DELAY-TAPS_PER_PHASE;
            2'b10: valid_next = -DELAY_HALF_N-TAPS_PER_PHASE; 
            2'b11: valid_next = valid_counter;
            endcase
    end
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            order_sel_old<=order_sel_i;
            reconf<=1'b0;
        end else if(clk_P) begin
            reconf<=(order_sel_old^order_sel_i);
            order_sel_old<=order_sel_i;
        end
    end

    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            if(order_sel_i) valid_counter<=-DELAY_HALF_N-1;
            else valid_counter<=-DELAY-1;
            valid_counter_after<=0;
        end else if(clk_P) begin 
            if(valid_counter<0) valid_counter<=valid_counter+1;
            else valid_counter<=valid_next;
            if(valid_counter_after<0) valid_counter_after<=valid_counter_after+1;
            else if(order_sel_i^order_sel_old) valid_counter_after<=-DELAY_AFTER;
        end
    end
    
    always_ff @(posedge clk_i) begin
        
        if(reset_i | (order_sel_i^order_sel_old)) begin
            for(int i=0; i<4; i++) valid_delay[i]<=1'b0;
            for(int i=0; i<4; i++) valid_delay_after[i]<=1'b0;
        end else if(clk_P) begin 
            if(pre_valid) valid_delay <= {1'b1, valid_delay[0:2]};
            else for(int i=0; i<4; i++) valid_delay[i]<=1'b0;
            if(valid_counter_after<0) valid_delay_after <= {1'b1, valid_delay_after[0:2]};
            else for(int i=0; i<4; i++) valid_delay_after[i]<=1'b0;
        end
    end
    assign out_valid = valid_delay[1];
    assign out_valid_after = valid_delay_after[0];
    assign valid_o = enable & (out_valid | out_valid_after | (order_sel_i^order_sel_old) | reconf);
    
    
endmodule
