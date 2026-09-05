`timescale 1ns / 1ps

module poly_filter_top_mini_tb;

    // Параметры
    parameter int P = 2;
    parameter int TAPS_PER_PHASE = 4;
    parameter int BITS_W = fir_pkg::bits_sum(TAPS_PER_PHASE, P);

    localparam int TOTAL_COEFF_NUM = P * TAPS_PER_PHASE;

    localparam logic [5:0] REG_COEFF_ADDR = 6'h00;
    localparam logic [5:0] REG_COEFF_DATA = 6'h04;
    localparam logic [5:0] REG_CONTROL    = 6'h08;

    // Сигналы top-модуля
    logic clk_i;
    logic reset_i;
    logic enable_i;
    logic order_sel_i;
    logic apply_all_i;

    logic [5:0] s_axi_awaddr;
    logic [2:0] s_axi_awprot;
    logic s_axi_awvalid;
    logic s_axi_awready;

    logic [31:0] s_axi_wdata;
    logic [3:0] s_axi_wstrb;
    logic s_axi_wvalid;
    logic s_axi_wready;

    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;

    logic [5:0] s_axi_araddr;
    logic [2:0] s_axi_arprot;
    logic s_axi_arvalid;
    logic s_axi_arready;

    logic [31:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready;

    logic [15:0] data_i;
    logic valid_i;
    logic ready_i;

    logic [BITS_W-1:0] data_o;
    logic valid_o;
    logic ready_o;

    logic busy_o;
    logic done_o;

    int error_count;

    // Генерация тактового сигнала
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    // Наборы коэффициентов для проверки
    function automatic logic signed [15:0] coeff_value(
        input int set_id,
        input int addr
    );
        int value;

        begin
            value = 100 + set_id * 1000 + addr;

            if (addr % 2 == 0)
                coeff_value = value;
            else
                coeff_value = -value;
        end
    endfunction

    // Запись одного регистра через AXI4-Lite
    task automatic axi_write(
        input logic [5:0] addr,
        input logic [31:0] data
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
            s_axi_wstrb = 4'hF;
            s_axi_wvalid = 1'b1;

            while (!(aw_done && w_done)) begin
                @(posedge clk_i);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1'b1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1'b1;

                @(negedge clk_i);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;
            end

            wait (s_axi_bvalid);

            if (s_axi_bresp !== 2'b00) begin
                $error("AXI WRITE ERROR: addr=%h, bresp=%b", addr, s_axi_bresp);
                error_count++;
            end

            s_axi_bready = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            s_axi_bready = 1'b0;
        end
    endtask

    // Загрузка полной ИХ в shadow
    task automatic load_coefficients(input int set_id);
        logic signed [15:0] coeff;

        begin
            for (int addr = 0; addr < TOTAL_COEFF_NUM; addr++) begin
                coeff = coeff_value(set_id, addr);

                axi_write(
                    REG_COEFF_ADDR,
                    addr
                );

                axi_write(
                    REG_COEFF_DATA,
                    {16'b0, coeff}
                );
            end
        end
    endtask

    // Проверка коэффициентов на входе polyphase
    task automatic check_coefficients(input int set_id);
        int addr;
        logic signed [15:0] expected;

        begin
            for (int phase_id = 0; phase_id < P; phase_id++) begin
                for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
                    addr = tap_id * P + phase_id;
                    expected = coeff_value(set_id, addr);

                    if (dut.h[phase_id][tap_id] !== expected) begin
                        $error(
                            "COEFF ERROR: phase=%0d tap=%0d expected=%0d received=%0d",
                            phase_id,
                            tap_id,
                            expected,
                            dut.h[phase_id][tap_id]
                        );
                        error_count++;
                    end
                end
            end
        end
    endtask

    // Полный перенос shadow -> active
    task automatic apply_all;
        begin
            @(negedge clk_i);
            apply_all_i = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            apply_all_i = 1'b0;
        end
    endtask

    // Один шаг последовательного переноса
    task automatic enable_one_clock;
        begin
            @(negedge clk_i);
            enable_i = 1'b1;

            @(posedge clk_i);
            @(negedge clk_i);

            enable_i = 1'b0;
        end
    endtask

    // Одновременная подача apply_i и apply_all_i
    task automatic forbidden_11;
        begin
            fork
                begin
                    axi_write(
                        REG_CONTROL,
                        32'h0000_0001
                    );
                end

                begin
                    wait (dut.coeff_storage.apply_core === 1'b1);

                    @(negedge clk_i);
                    apply_all_i = 1'b1;

                    @(posedge clk_i);
                    @(negedge clk_i);

                    apply_all_i = 1'b0;
                end
            join
        end
    endtask

    // Блок входных воздействий
    initial begin
        reset_i = 1'b1;
        enable_i = 1'b0;
        order_sel_i = 1'b0;
        apply_all_i = 1'b0;

        data_i = '0;
        valid_i = 1'b0;
        ready_o = 1'b1;

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

        // Сброс
        repeat (5) @(posedge clk_i);

        @(negedge clk_i);
        reset_i = 1'b0;

        // 01 - полный перенос
        $display("TEST 01: apply_all");

        load_coefficients(0);
        apply_all();
        check_coefficients(0);

        if (busy_o !== 1'b0) begin
            $error("01: busy_o must be 0");
            error_count++;
        end

        if (done_o !== 1'b0) begin
            $error("01: done_o must be 0");
            error_count++;
        end

        // 00 - перенос не выполняется
        $display("TEST 00: no command");

        load_coefficients(1);

        repeat (2) @(posedge clk_i);

        check_coefficients(0);

        // 10 - последовательный перенос
        $display("TEST 10: sequential apply");

        axi_write(
            REG_CONTROL,
            32'h0000_0001
        );

        if (busy_o !== 1'b1) begin
            $error("10: busy_o was not asserted");
            error_count++;
        end

        for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
            enable_one_clock();
        end

        check_coefficients(1);

        if (busy_o !== 1'b0) begin
            $error("10: busy_o did not clear");
            error_count++;
        end

        if (done_o !== 1'b1) begin
            $error("10: done_o was not asserted");
            error_count++;
        end

        @(posedge clk_i);
        @(negedge clk_i);

        // 11 - запрещённая комбинация
        $display("TEST 11: forbidden combination");

        load_coefficients(2);
        forbidden_11();

        repeat (2) @(posedge clk_i);

        if (busy_o !== 1'b0) begin
            $error("11: sequential transfer started");
            error_count++;
        end

        if (done_o !== 1'b0) begin
            $error("11: done_o was asserted");
            error_count++;
        end

        check_coefficients(1);

        // Результат проверки
        if (error_count == 0) begin
            $display("TEST PASSED");
            $display("00 - no command           OK");
            $display("01 - apply_all             OK");
            $display("10 - sequential apply      OK");
            $display("11 - forbidden combination OK");
        end
        else begin
            $fatal(1, "TEST FAILED: %0d errors", error_count);
        end

        $finish;
    end

    // Ограничение времени симуляции
    initial begin
        #100000;
        $fatal(1, "TEST TIMEOUT");
    end

    // Инстанцирование тестируемого модуля
    poly_filter_top #(
        .P              (P),
        .TAPS_PER_PHASE (TAPS_PER_PHASE),
        .BITS_W         (BITS_W)
    ) dut (
        .clk_i       (clk_i),
        .reset_i     (reset_i),
        .enable_i    (enable_i),
        .order_sel_i (order_sel_i),
        .apply_all_i (apply_all_i),

        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),

        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),

        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),

        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),

        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready),

        .data_i  (data_i),
        .valid_i (valid_i),
        .ready_i (ready_i),

        .data_o  (data_o),
        .valid_o (valid_o),
        .ready_o (ready_o),

        .busy_o (busy_o),
        .done_o (done_o)
    );

endmodule