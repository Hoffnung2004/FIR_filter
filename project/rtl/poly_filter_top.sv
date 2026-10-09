module poly_filter_top
#(
    parameter int P                = poly_filter_pkg::P,
    parameter int TAPS_PER_PHASE   = poly_filter_pkg::TAPS_PER_PHASE,
    parameter int BITS_W           = poly_filter_pkg::bits_sum(TAPS_PER_PHASE, P),
    parameter logic signed [15:0] H [0:P-1][0:TAPS_PER_PHASE-1] = '{default:0}
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic order_sel_i,
    input logic apply_all_i,

    input logic [5:0] s_axi_awaddr,
    input logic [2:0] s_axi_awprot,
    input logic s_axi_awvalid,
    output logic s_axi_awready,

    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,

    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,

    input logic [5:0] s_axi_araddr,
    input logic [2:0] s_axi_arprot,
    input logic s_axi_arvalid,
    output logic s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,
    
    input logic [15:0] data_i,
    input logic valid_i,
    output logic ready_i,
    
    output logic [BITS_W-1:0] data_o,
    output logic valid_o,
    input logic ready_o,

    output logic busy_o,
    output logic done_o
    );
    
    logic enable;
    logic module_enable;
    logic [15:0] fifo_out;
    logic signed [15:0] h [0:P-1][0:TAPS_PER_PHASE-1];

    logic [15:0] phase_in [0:P-1];
    logic signed [15:0] phase_in_signed [0:P-1];

    logic signed [BITS_W-1:0] phase_out_signed [0:P-1];
    logic [BITS_W-1:0] phase_out [0:P-1];
    logic [BITS_W-1:0] pre_out;

    logic pre_clk_P;
    logic clk_P;
    logic clk_2P;


    generate
        for(genvar phase_id = 0; phase_id < P; phase_id++) begin
            assign phase_in_signed[phase_id] = $signed(phase_in[phase_id]);
            assign phase_out[phase_id] = $unsigned(phase_out_signed[phase_id]);
        end
    endgenerate
    
    assign module_enable=enable&(ready_o | !valid_o);
    
    fifo #( // Каждый такт - отсчёт
        .BITS_W(16),
        .IMPORTANT_BITS_W(1),
        .POW(4)
    ) fifo_in (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(enable_i),
        .data_i(data_i),
        .important_i(order_sel_i),
        .valid_i(valid_i),
        .ready_i(ready_i),
        .data_o(fifo_out),
        .important_o(order_sel),
        .valid_o(enable),
        .ready_o(ready_o | !out_valid)
    );
    
    coeff_storage_axi_lite #(
        .COEFF_WIDTH(16),
        .PHASE_NUM(P),
        .TAPS_PER_PHASE(TAPS_PER_PHASE),
        .AXI_DATA_WIDTH(32),
        .AXI_ADDR_WIDTH(6),
        .H(H)
    ) coeff_storage (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(enable_i),
        .apply_all_i(apply_all_i),

        .s_axi_awaddr(s_axi_awaddr), // [AXI_ADDR_WIDTH-1:0]
        .s_axi_awprot(s_axi_awprot), // [2:0]
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata), // [AXI_DATA_WIDTH-1:0]
        .s_axi_wstrb(s_axi_wstrb), // [AXI_DATA_WIDTH/8-1:0]
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), // [1:0]
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), // [AXI_ADDR_WIDTH-1:0]
        .s_axi_arprot(s_axi_arprot), // [2:0]
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), //[AXI_DATA_WIDTH-1:0]
        .s_axi_rresp(s_axi_rresp), // [1:0]
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .coeff_o(h),
        .busy_o(busy_o),
        .done_o(done_o)
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
            .pre_new_data(pre_clk_P),
            .new_data(clk_P),
            .new_data2(clk_2P)
        );
    
    polyphase2 #(
        .P(P), 
        .TAPS_PER_PHASE(TAPS_PER_PHASE), 
        .BITS_W(BITS_W)
    ) polyphase_struct (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(clk_P),
        .strob_i(clk_2P),
        .order_sel_i(order_sel),
        .signal_i(phase_in_signed),
        .h_i(h),
        .signal_o(phase_out_signed)
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
    
    

    
    
    valid_fsm #(
        .P(P),
        .TAPS_PER_PHASE(TAPS_PER_PHASE)
    ) valid_module (
     .clk_i(clk_i),
     .reset_i(reset_i),
     .enable_i(enable),
     .clk_P(clk_P),
     .clk_2P(clk_2P),
     .pre_clk_P(pre_clk_P),
     .order_sel_i(order_sel_i),
     .valid_o(valid_o)
    );
   
    
endmodule