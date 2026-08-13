`timescale 1ns / 1ps

module tb_simple_param_filter;

    parameter int N            = 32;
    parameter int BITS_W       = 40;
    parameter int MULT_LATENCY = 21;
    parameter int IMPULSE_LEN  = 1;        // длина импульса

    int  tb_order_sel  = 1;               // 1 = режим N/2, 0 = режим N
    int  tb_enable_div = 2;               // 2 = strob_i раз в 2 такта clk

    localparam int TREE_LAT  = (N/4 <= 1) ? 0 : $clog2(N/4);
    localparam int TOTAL_LAT = MULT_LATENCY + TREE_LAT + 2;

    logic clk = 0, reset;
    logic enable;
    logic strob_i;
    logic order_sel;
    logic signed [15:0] signal_in;
    logic signed [15:0] taps [0:N-1];
    logic signed [BITS_W-1:0] signal_out;
    
    logic signed [BITS_W-1:0] dbg_y_current;
    logic signed [BITS_W-1:0] dbg_y_prev;
    logic signed [BITS_W-1:0] dbg_saved_prev;
    logic dbg_psc_phase;

    param_filter #( .N(N), .BITS_W(BITS_W), .MULT_LATENCY(MULT_LATENCY) )
    dut (
        .clk_i      (clk),
        .reset_i    (reset),
        .enable_i   (enable),
        .strob_i    (strob_i),
        .signal_i   (signal_in),
        .taps_i     (taps),
        .order_sel_i(order_sel),
        .signal_o   (signal_out)
    );

    assign dbg_y_current  = dut.y_current_ff;
    assign dbg_y_prev     = dut.y_prev_ff;
    assign dbg_saved_prev = dut.saved_prev;
    assign dbg_psc_phase  = dut.psc_phase_ff;

    always #5 clk = ~clk;

    assign enable = 1'b1;   // или logic enable = 1;

    logic [7:0] enable_cnt = 0;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) 
            enable_cnt <= 0;
        else 
            enable_cnt <= (enable_cnt >= tb_enable_div-1) ? 0 : enable_cnt + 1;
    end
    assign strob_i = (enable_cnt == 0);

    int sample_cnt = 0;
    always_ff @(posedge clk) begin
        if (reset) begin
            sample_cnt <= 0;
            signal_in  <= 0;
        end else if (enable) begin   // enable_i всегда 1
            signal_in <= (sample_cnt < IMPULSE_LEN) ? 16'sd1 : 16'sd0;
            sample_cnt <= sample_cnt + (sample_cnt < IMPULSE_LEN ? 1 : 0);
        end
    end

    int d = 1;
    initial begin
        for (int i = 0; i < N; i++) begin
                taps[i] = d[15:0];
                d = d + 1;
        end
    end

    always_ff @(posedge clk)
        if (!reset)
            $display("%0t | en=%b | strob=%b | in=%0d | y_cur=%0d | y_prev=%0d | phase=%b | out=%0d",
                     $time, enable, strob_i, signal_in,
                     dbg_y_current, dbg_y_prev, dbg_psc_phase, signal_out);

    initial begin
        $dumpfile("tb_param_filter.vcd");
        $dumpvars(0, tb_param_filter);
    end

    initial begin
        $display("=== Test: N/2 mode, enable_div=%0d ===", tb_enable_div);
        order_sel = tb_order_sel;
        reset = 1;
        repeat (30) @(posedge clk);
        reset = 0;

        repeat (IMPULSE_LEN * tb_enable_div + TOTAL_LAT + N + 20) @(posedge clk);

        $display("=== Done ===");
        $finish;
    end

endmodule
