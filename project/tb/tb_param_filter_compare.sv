`timescale 1ns / 1ps

module tb_param_filter_compare;

    parameter int N            = 32;
    parameter int BITS_W       = 40;
    parameter int OLD_MULT_LAT = 21;

    logic clk = 0;
    logic reset;
    logic enable_i;
    logic strob_i;
    logic order_sel;
    logic signed [15:0] signal_in;
    logic signed [15:0] taps [0:N-1];

    logic signed [BITS_W-1:0] old_signal_o;

    logic signed [BITS_W-1:0] new_a_o;
    logic signed [BITS_W-1:0] new_b_o;
    logic signed [BITS_W-1:0] new_sum_o;

    assign new_sum_o = new_a_o + new_b_o;

    param_filter #(
        .N(N), .BITS_W(BITS_W), .MULT_LATENCY(OLD_MULT_LAT)
    ) old_dut (
        .clk_i(clk), .reset_i(reset), .enable_i(enable_i), .strob_i(strob_i),
        .signal_i(signal_in), .taps_i(taps), .order_sel_i(order_sel), .signal_o(old_signal_o)
    );

    param_filter_new #(
        .N(N), .BITS_W(BITS_W)
    ) new_dut (
        .clk_i(clk), .reset_i(reset), .enable_i(enable_i), .strob_i(strob_i),
        .signal_i(signal_in), .taps_i(taps), .order_sel_i(order_sel), .a_o(new_a_o), .b_o(new_b_o)
    );

    always #5 clk = ~clk;

    assign enable_i = 1'b1;
    logic [1:0] strob_cnt = 0;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) strob_cnt <= 0;
        else       strob_cnt <= strob_cnt + 1;
    end
    assign strob_i = (strob_cnt == 0);

    int sample_cnt = 0;
    always_ff @(posedge clk) begin
        if (reset) begin
            sample_cnt <= 0;
            signal_in  <= 0;
        end else if (!order_sel) begin
            signal_in <= (sample_cnt < 2) ? 16'sd1 : 16'sd0;
            sample_cnt <= sample_cnt + (sample_cnt < 2 ? 1 : 0);
        end else begin
            if (strob_cnt == 3 && sample_cnt == 0) begin
                signal_in <= 1;
                sample_cnt <= 1;
            end else if (sample_cnt == 1) begin
                signal_in <= 1;
                sample_cnt <= 2;
            end else begin
                signal_in <= 0;
            end
        end
    end

    logic signed [BITS_W-1:0] old_q[$];
    logic signed [BITS_W-1:0] new_q[$];

    always_ff @(posedge clk) begin
        if (!reset) begin
            if (!$isunknown(old_signal_o) && old_signal_o != 0) old_q.push_back(old_signal_o);
            if (!$isunknown(new_sum_o)    && new_sum_o != 0)    new_q.push_back(new_sum_o);
        end
    end

    initial begin
        int mismatches;

        for (int i = 0; i < N; i++) begin
            taps[i] = i + 1;
        end

        // TEST 1: Mode N (order_sel = 0)
        $display("\n=== TEST 1: order_sel = 0 (Mode N) ===");
        reset = 1;
        order_sel = 0;
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(500) @(posedge clk); // Увеличено время ожидания, чтобы конвейер точно опустел

        if (old_q.size() != new_q.size()) begin
            $display("ERROR: Queue sizes do not match! Old: %0d, New: %0d", old_q.size(), new_q.size());
        end else if (old_q.size() == 0) begin
            $display("ERROR: Queues are empty! No data was captured.");
        end else begin
            mismatches = 0;
            for (int i = 0; i < old_q.size(); i++) begin
                if (old_q[i] !== new_q[i]) begin
                    $display("Mismatch [%0d]: Old = %0d, New = %0d", i, old_q[i], new_q[i]);
                    mismatches++;
                end
            end
            if (mismatches == 0) $display("RESULT: TEST 1 PASSED (%0d values matched).", old_q.size());
            else                 $display("RESULT: TEST 1 FAILED.");
        end

        // TEST 2: Mode N/2 (order_sel = 1)
        $display("\n=== TEST 2: order_sel = 1 (Mode N/2) ===");
        old_q.delete();
        new_q.delete();
        
        reset = 1;
        order_sel = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(500) @(posedge clk);

        if (old_q.size() != new_q.size()) begin
            $display("ERROR: Queue sizes do not match! Old: %0d, New: %0d", old_q.size(), new_q.size());
        end else if (old_q.size() == 0) begin
            $display("ERROR: Queues are empty! No data was captured.");
        end else begin
            mismatches = 0;
            for (int i = 0; i < old_q.size(); i++) begin
                if (old_q[i] !== new_q[i]) begin
                    $display("Mismatch [%0d]: Old = %0d, New = %0d", i, old_q[i], new_q[i]);
                    mismatches++;
                end
            end
            if (mismatches == 0) $display("RESULT: TEST 2 PASSED (%0d values matched).", old_q.size());
            else                 $display("RESULT: TEST 2 FAILED.");
        end

        $display("\n=== Simulation finished ===");
        $finish;
    end

    initial begin
        $dumpfile("tb_compare.vcd");
        $dumpvars(0, tb_param_filter_compare);
    end

endmodule
