`timescale 1ns / 1ps

module coeff_storage_axi_lite_tb;

    parameter int COEFF_WIDTH = 16;
    parameter int PHASE_NUM = 3;
    parameter int TAPS_PER_PHASE = 8;
    parameter int AXI_DATA_WIDTH = 32;
    parameter int AXI_ADDR_WIDTH = 6;
    parameter int CLK_PERIOD = 10;

    localparam int TOTAL_COEFF_NUM = PHASE_NUM * TAPS_PER_PHASE;
    localparam int COEFF_ADDR_WIDTH = (TOTAL_COEFF_NUM <= 1) ? 1 : $clog2(TOTAL_COEFF_NUM);
    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_COEFF_ADDR = 0;
    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_COEFF_DATA = 4;
    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_CONTROL = 8;
    localparam logic [AXI_ADDR_WIDTH-1:0] ADDR_STATUS = 12;

    localparam logic [1:0] AXI_OKAY = 2'b00;
    localparam logic [1:0] AXI_SLVERR = 2'b10;

    localparam logic [AXI_STRB_WIDTH-1:0] FULL_STRB = {AXI_STRB_WIDTH{1'b1}};

    logic reset_i;
    logic clk_i;
    logic enable_i;

    logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0] s_axi_awprot;
    logic s_axi_awvalid;
    logic s_axi_awready;

    logic [AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [AXI_STRB_WIDTH-1:0] s_axi_wstrb;
    logic s_axi_wvalid;
    logic s_axi_wready;

    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;

    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0] s_axi_arprot;
    logic s_axi_arvalid;
    logic s_axi_arready;

    logic [AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready;

    logic signed [COEFF_WIDTH-1:0] coeff_o [0:PHASE_NUM-1][0:TAPS_PER_PHASE-1];

    logic busy_o;
    logic done_o;

    int unsigned error_count;

    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    function automatic logic signed [COEFF_WIDTH-1:0] coeff_pattern(
        input int pattern_id,
        input int linear_addr
    );
        case (pattern_id)
            0: coeff_pattern = 100 + linear_addr;
            1: coeff_pattern = -(1000 + linear_addr);
            default: coeff_pattern = '0;
        endcase
    endfunction

    task automatic axi_write(
        input logic [AXI_ADDR_WIDTH-1:0] addr,
        input logic [AXI_DATA_WIDTH-1:0] data,
        input logic [AXI_STRB_WIDTH-1:0] strb,
        input logic [1:0] expected_resp
    );
        bit aw_done;
        bit w_done;

        begin
            aw_done = 1'b0;
            w_done = 1'b0;

            @(negedge clk_i);

            s_axi_awaddr = addr;
            s_axi_awvalid = 1'b1;

            s_axi_wdata = data;
            s_axi_wstrb = strb;
            s_axi_wvalid = 1'b1;

            s_axi_bready = 1'b0;

            while (!(aw_done && w_done)) begin
                @(posedge clk_i);

                if (s_axi_awvalid && s_axi_awready) begin
                    aw_done = 1'b1;
                end

                if (s_axi_wvalid && s_axi_wready) begin
                    w_done = 1'b1;
                end

                @(negedge clk_i);

                if (aw_done) begin
                    s_axi_awvalid = 1'b0;
                end

                if (w_done) begin
                    s_axi_wvalid = 1'b0;
                end
            end

            while (!s_axi_bvalid) begin
                @(negedge clk_i);
            end

            if (s_axi_bresp !== expected_resp) begin
                $error(
                    "AXI WRITE: addr=0x%0h, expected BRESP=%b, received BRESP=%b",
                    addr,
                    expected_resp,
                    s_axi_bresp
                );
                error_count++;
            end

            s_axi_bready = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            s_axi_bready = 1'b0;
        end
    endtask

    task automatic axi_read(
        input logic [AXI_ADDR_WIDTH-1:0] addr,
        output logic [AXI_DATA_WIDTH-1:0] data,
        input logic [1:0] expected_resp
    );
        begin
            @(negedge clk_i);

            s_axi_araddr = addr;
            s_axi_arvalid = 1'b1;
            s_axi_rready = 1'b0;

            do begin
                @(posedge clk_i);
            end while (!(s_axi_arvalid && s_axi_arready));

            @(negedge clk_i);
            s_axi_arvalid = 1'b0;

            while (!s_axi_rvalid) begin
                @(negedge clk_i);
            end

            data = s_axi_rdata;

            if (s_axi_rresp !== expected_resp) begin
                $error(
                    "AXI READ: addr=0x%0h, expected RRESP=%b, received RRESP=%b",
                    addr,
                    expected_resp,
                    s_axi_rresp
                );
                error_count++;
            end

            s_axi_rready = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            s_axi_rready = 1'b0;
        end
    endtask

    task automatic load_pattern(input int pattern_id);
        logic signed [COEFF_WIDTH-1:0] coeff_value;
        logic [AXI_DATA_WIDTH-1:0] axi_value;

        begin
            for (int linear_addr = 0; linear_addr < TOTAL_COEFF_NUM; linear_addr++) begin
                coeff_value = coeff_pattern(pattern_id, linear_addr);

                axi_write(
                    ADDR_COEFF_ADDR,
                    linear_addr,
                    FULL_STRB,
                    AXI_OKAY
                );

                axi_value = '0;
                axi_value[COEFF_WIDTH-1:0] = coeff_value;

                axi_write(
                    ADDR_COEFF_DATA,
                    axi_value,
                    FULL_STRB,
                    AXI_OKAY
                );
            end
        end
    endtask

    task automatic pulse_enable;
        begin
            @(negedge clk_i);
            enable_i = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            enable_i = 1'b0;
        end
    endtask

    task automatic check_pattern(input int pattern_id);
        logic signed [COEFF_WIDTH-1:0] expected_value;
        int linear_addr;

        begin
            for (int phase_id = 0; phase_id < PHASE_NUM; phase_id++) begin
                for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
                    linear_addr = tap_id * PHASE_NUM + phase_id;
                    expected_value = coeff_pattern(pattern_id, linear_addr);

                    if (coeff_o[phase_id][tap_id] !== expected_value) begin
                        $error(
                            "COEFF ERROR: phase=%0d tap=%0d expected=%0d received=%0d",
                            phase_id,
                            tap_id,
                            expected_value,
                            coeff_o[phase_id][tap_id]
                        );
                        error_count++;
                    end
                end
            end
        end
    endtask

    task automatic check_transition(
        input int updated_taps,
        input int old_pattern_id,
        input int new_pattern_id
    );
        logic signed [COEFF_WIDTH-1:0] expected_value;
        int linear_addr;

        begin
            for (int phase_id = 0; phase_id < PHASE_NUM; phase_id++) begin
                for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
                    linear_addr = tap_id * PHASE_NUM + phase_id;

                    if (tap_id < updated_taps) begin
                        expected_value = coeff_pattern(new_pattern_id, linear_addr);
                    end
                    else begin
                        expected_value = coeff_pattern(old_pattern_id, linear_addr);
                    end

                    if (coeff_o[phase_id][tap_id] !== expected_value) begin
                        $error(
                            "TRANSITION ERROR: enable=%0d phase=%0d tap=%0d expected=%0d received=%0d",
                            updated_taps,
                            phase_id,
                            tap_id,
                            expected_value,
                            coeff_o[phase_id][tap_id]
                        );
                        error_count++;
                    end
                end
            end
        end
    endtask

    initial begin : p_test
        logic [AXI_DATA_WIDTH-1:0] read_data;

        clk_i = 1'b0;
        reset_i = 1'b1;
        enable_i = 1'b0;

        s_axi_awaddr = '0;
        s_axi_awprot = '0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata = '0;
        s_axi_wstrb = '0;
        s_axi_wvalid = 1'b0;

        s_axi_bready = 1'b0;

        s_axi_araddr = '0;
        s_axi_arprot = '0;
        s_axi_arvalid = 1'b0;

        s_axi_rready = 1'b0;

        error_count = 0;

        repeat (3) @(posedge clk_i);

        @(negedge clk_i);
        reset_i = 1'b0;

        @(negedge clk_i);

        if (busy_o !== 1'b0) begin
            $error("After reset BUSY must be 0");
            error_count++;
        end

        if (done_o !== 1'b0) begin
            $error("After reset DONE must be 0");
            error_count++;
        end

        $display("TEST: loading first impulse response");

        load_pattern(0);

        axi_write(
            ADDR_CONTROL,
            32'h0000_0001,
            FULL_STRB,
            AXI_OKAY
        );

        if (busy_o !== 1'b1) begin
            $error("BUSY was not asserted after first APPLY");
            error_count++;
        end

        for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
            pulse_enable();
        end

        check_pattern(0);

        if (busy_o !== 1'b0) begin
            $error("BUSY did not clear after first impulse response update");
            error_count++;
        end

        if (done_o !== 1'b1) begin
            $error("DONE pulse was not asserted after first impulse response update");
            error_count++;
        end

        @(posedge clk_i);
        @(negedge clk_i);

        axi_read(
            ADDR_STATUS,
            read_data,
            AXI_OKAY
        );

        if (read_data[1:0] !== 2'b10) begin
            $error(
                "STATUS after first update must be DONE=1 BUSY=0, received=%b",
                read_data[1:0]
            );
            error_count++;
        end

        $display("TEST: loading second impulse response");

        load_pattern(1);

        check_pattern(0);

        axi_read(
            ADDR_COEFF_ADDR,
            read_data,
            AXI_OKAY
        );

        if (read_data[COEFF_ADDR_WIDTH-1:0] !== TOTAL_COEFF_NUM - 1) begin
            $error(
                "COEFF_ADDR readback error: expected=%0d received=%0d",
                TOTAL_COEFF_NUM - 1,
                read_data[COEFF_ADDR_WIDTH-1:0]
            );
            error_count++;
        end

        $display("TEST: starting shadow-to-active transition");

        axi_write(
            ADDR_CONTROL,
            32'h0000_0001,
            FULL_STRB,
            AXI_OKAY
        );

        if (busy_o !== 1'b1) begin
            $error("BUSY was not asserted after second APPLY");
            error_count++;
        end

        axi_write(
            ADDR_COEFF_DATA,
            32'h0000_5555,
            FULL_STRB,
            AXI_SLVERR
        );

        axi_read(
            ADDR_STATUS,
            read_data,
            AXI_OKAY
        );

        if (read_data[1:0] !== 2'b01) begin
            $error(
                "STATUS during update must be DONE=0 BUSY=1, received=%b",
                read_data[1:0]
            );
            error_count++;
        end

        repeat (3) @(posedge clk_i);
        @(negedge clk_i);

        check_pattern(0);

        if (busy_o !== 1'b1) begin
            $error("BUSY cleared without enable_i");
            error_count++;
        end

        for (int updated_taps = 1; updated_taps <= TAPS_PER_PHASE; updated_taps++) begin
            pulse_enable();
            check_transition(updated_taps, 0, 1);
        end

        if (busy_o !== 1'b0) begin
            $error("BUSY did not clear after all enable_i pulses");
            error_count++;
        end

        if (done_o !== 1'b1) begin
            $error("DONE pulse was not asserted after second update");
            error_count++;
        end

        check_pattern(1);

        @(posedge clk_i);
        @(negedge clk_i);

        if (done_o !== 1'b0) begin
            $error("done_o must be a one-cycle pulse");
            error_count++;
        end

        axi_read(
            ADDR_STATUS,
            read_data,
            AXI_OKAY
        );

        if (read_data[1:0] !== 2'b10) begin
            $error(
                "Final STATUS must be DONE=1 BUSY=0, received=%b",
                read_data[1:0]
            );
            error_count++;
        end

        axi_write(
            ADDR_COEFF_ADDR,
            TOTAL_COEFF_NUM,
            FULL_STRB,
            AXI_SLVERR
        );

        if (error_count == 0) begin
            $display("========================================");
            $display("TEST PASSED: all checks completed");
            $display("========================================");
        end
        else begin
            $fatal(1, "TEST FAILED: %0d errors found", error_count);
        end

        $finish;
    end : p_test

    initial begin : p_timeout
        #100000;
        $fatal(1, "TEST TIMEOUT");
    end : p_timeout

    coeff_storage_axi_lite #(
        .COEFF_WIDTH(COEFF_WIDTH),
        .PHASE_NUM(PHASE_NUM),
        .TAPS_PER_PHASE(TAPS_PER_PHASE),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) dut (
        .reset_i(reset_i),
        .clk_i(clk_i),
        .enable_i(enable_i),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .coeff_o(coeff_o),
        .busy_o(busy_o),
        .done_o(done_o)
    );

endmodule