`timescale 1ns / 1ps

module coeff_storage_axi_lite #(
    parameter int COEFF_WIDTH = 16,
    parameter int PHASE_NUM = 3,
    parameter int TAPS_PER_PHASE = 8,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_ADDR_WIDTH = 6,

    localparam int TOTAL_COEFF_NUM = PHASE_NUM * TAPS_PER_PHASE,
    localparam int COEFF_ADDR_WIDTH = (TOTAL_COEFF_NUM <= 1) ? 1 : $clog2(TOTAL_COEFF_NUM)
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic apply_all_i,

    input logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input logic [2:0] s_axi_awprot,
    input logic s_axi_awvalid,
    output logic s_axi_awready,

    input logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,

    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,

    input logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input logic [2:0] s_axi_arprot,
    input logic s_axi_arvalid,
    output logic s_axi_arready,

    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,

    output logic signed [COEFF_WIDTH-1:0] coeff_o [0:PHASE_NUM-1][0:TAPS_PER_PHASE-1],

    output logic busy_o,
    output logic done_o
);

    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int ADDR_LSB = $clog2(AXI_STRB_WIDTH);
    localparam int COEFF_BYTE_NUM = (COEFF_WIDTH + 7) / 8;
    localparam int COEFF_ADDR_BYTE_NUM = (COEFF_ADDR_WIDTH + 7) / 8;

    localparam int REG_COEFF_ADDR = 0;
    localparam int REG_COEFF_DATA = 1;
    localparam int REG_CONTROL = 2;
    localparam int REG_STATUS = 3;

    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;

    initial begin : p_parameter_check
        if (AXI_DATA_WIDTH % 8 != 0) begin
            $fatal(1, "coeff_storage_axi_lite: AXI_DATA_WIDTH must be divisible by 8");
        end

        if (AXI_DATA_WIDTH < COEFF_WIDTH) begin
            $fatal(1, "coeff_storage_axi_lite: AXI_DATA_WIDTH must be >= COEFF_WIDTH");
        end

        if (AXI_DATA_WIDTH < COEFF_ADDR_WIDTH) begin
            $fatal(1, "coeff_storage_axi_lite: AXI_DATA_WIDTH is too small for coefficient address");
        end

        if (AXI_ADDR_WIDTH < ADDR_LSB + 2) begin
            $fatal(1, "coeff_storage_axi_lite: AXI_ADDR_WIDTH is too small");
        end
    end : p_parameter_check

    logic [AXI_ADDR_WIDTH-1:0] awaddr_ff;
    logic aw_pending_ff;

    logic [AXI_DATA_WIDTH-1:0] wdata_ff;
    logic [AXI_STRB_WIDTH-1:0] wstrb_ff;
    logic w_pending_ff;

    logic [1:0] bresp_ff;
    logic bvalid_ff;

    logic [AXI_DATA_WIDTH-1:0] rdata_ff;
    logic [1:0] rresp_ff;
    logic rvalid_ff;

    logic [COEFF_ADDR_WIDTH-1:0] coeff_addr_ff;

    logic wr_ena_core;
    logic [COEFF_ADDR_WIDTH-1:0] wr_addr_core;
    logic signed [COEFF_WIDTH-1:0] wr_data_core;
    logic apply_core;

    logic busy_core;
    logic done_core;
    logic done_status_ff;

    logic coeff_addr_strobe_valid;
    logic coeff_data_strobe_valid;
    logic storage_busy;

    always_comb begin : c_strobe_check
        coeff_addr_strobe_valid = 1'b1;
        coeff_data_strobe_valid = 1'b1;

        for (int byte_id = 0; byte_id < COEFF_ADDR_BYTE_NUM; byte_id++) begin
            coeff_addr_strobe_valid &= wstrb_ff[byte_id];
        end

        for (int byte_id = 0; byte_id < COEFF_BYTE_NUM; byte_id++) begin
            coeff_data_strobe_valid &= wstrb_ff[byte_id];
        end
    end : c_strobe_check

    assign s_axi_awready = !aw_pending_ff && !bvalid_ff;
    assign s_axi_wready = !w_pending_ff && !bvalid_ff;

    assign s_axi_bresp = bresp_ff;
    assign s_axi_bvalid = bvalid_ff;

    assign s_axi_arready = !rvalid_ff;
    assign s_axi_rdata = rdata_ff;
    assign s_axi_rresp = rresp_ff;
    assign s_axi_rvalid = rvalid_ff;

    assign wr_addr_core = coeff_addr_ff;

    assign storage_busy = busy_core || apply_core;

    assign busy_o = storage_busy;
    assign done_o = done_core;

    always_ff @(posedge clk_i) begin : p_axi_write
        if (reset_i) begin
            awaddr_ff <= '0;
            aw_pending_ff <= 1'b0;
            wdata_ff <= '0;
            wstrb_ff <= '0;
            w_pending_ff <= 1'b0;
            bresp_ff <= AXI_OKAY;
            bvalid_ff <= 1'b0;
            coeff_addr_ff <= '0;
            wr_ena_core <= 1'b0;
            wr_data_core <= '0;
            apply_core <= 1'b0;
            done_status_ff <= 1'b0;
        end
        else begin
            wr_ena_core <= 1'b0;
            apply_core <= 1'b0;

            if (done_core) begin
                done_status_ff <= 1'b1;
            end

            if (s_axi_awready && s_axi_awvalid) begin
                awaddr_ff <= s_axi_awaddr;
                aw_pending_ff <= 1'b1;
            end

            if (s_axi_wready && s_axi_wvalid) begin
                wdata_ff <= s_axi_wdata;
                wstrb_ff <= s_axi_wstrb;
                w_pending_ff <= 1'b1;
            end

            if (bvalid_ff && s_axi_bready) begin
                bvalid_ff <= 1'b0;
            end

            if (aw_pending_ff && w_pending_ff && !bvalid_ff) begin
                aw_pending_ff <= 1'b0;
                w_pending_ff <= 1'b0;
                bvalid_ff <= 1'b1;
                bresp_ff <= AXI_OKAY;

                case (awaddr_ff[AXI_ADDR_WIDTH-1:ADDR_LSB])
                    REG_COEFF_ADDR: begin
                        if (coeff_addr_strobe_valid && ($unsigned(wdata_ff) < TOTAL_COEFF_NUM)) begin
                            coeff_addr_ff <= wdata_ff[COEFF_ADDR_WIDTH-1:0];
                        end
                        else begin
                            bresp_ff <= AXI_SLVERR;
                        end
                    end

                    REG_COEFF_DATA: begin
                        if (coeff_data_strobe_valid && !storage_busy && !apply_all_i) begin
                            wr_data_core <= $signed(wdata_ff[COEFF_WIDTH-1:0]);
                            wr_ena_core <= 1'b1;
                        end
                        else begin
                            bresp_ff <= AXI_SLVERR;
                        end
                    end

                    REG_CONTROL: begin
                        if (wstrb_ff[0]) begin
                            if (wdata_ff[0]) begin
                                if (!storage_busy && !apply_all_i) begin
                                    apply_core <= 1'b1;
                                    done_status_ff <= 1'b0;
                                end
                                else begin
                                    bresp_ff <= AXI_SLVERR;
                                end
                            end
                        end
                        else begin
                            bresp_ff <= AXI_SLVERR;
                        end
                    end

                    default: begin
                        bresp_ff <= AXI_SLVERR;
                    end
                endcase
            end
        end
    end : p_axi_write

    always_ff @(posedge clk_i) begin : p_axi_read
        if (reset_i) begin
            rdata_ff <= '0;
            rresp_ff <= AXI_OKAY;
            rvalid_ff <= 1'b0;
        end
        else begin
            if (rvalid_ff && s_axi_rready) begin
                rvalid_ff <= 1'b0;
            end

            if (s_axi_arready && s_axi_arvalid) begin
                rdata_ff <= '0;
                rresp_ff <= AXI_OKAY;
                rvalid_ff <= 1'b1;

                case (s_axi_araddr[AXI_ADDR_WIDTH-1:ADDR_LSB])
                    REG_COEFF_ADDR: begin
                        rdata_ff[COEFF_ADDR_WIDTH-1:0] <= coeff_addr_ff;
                    end

                    REG_COEFF_DATA: begin
                        rdata_ff <= '0;
                    end

                    REG_CONTROL: begin
                        rdata_ff <= '0;
                    end

                    REG_STATUS: begin
                        rdata_ff[0] <= storage_busy;
                        rdata_ff[1] <= done_status_ff;
                    end

                    default: begin
                        rresp_ff <= AXI_SLVERR;
                    end
                endcase
            end
        end
    end : p_axi_read

    coeff_storage_core #(
        .COEFF_WIDTH(COEFF_WIDTH),
        .PHASE_NUM(PHASE_NUM),
        .TAPS_PER_PHASE(TAPS_PER_PHASE)
    ) u_coeff_storage_core (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(enable_i),
        .apply_i(apply_core),
        .apply_all_i(apply_all_i),

        .wr_ena_i(wr_ena_core),
        .wr_addr_i(wr_addr_core),
        .wr_data_i(wr_data_core),

        .coeff_o(coeff_o),
        .busy_o(busy_core),
        .done_o(done_core)
    );

endmodule