`timescale 1ns / 1ps

module tb_param_filter;

    localparam string FILE_DIR = "../../../../fir_filter_project.ip_user_files/mem_init_files/";
    localparam int TEST_NUM = 6;           // номер теста
    localparam int DELAY    = 60;          //надо подобрать задержку

    // Параметры фильтра
    localparam int N = 32;
    localparam int BITS_W = 40;
    localparam int SIGNAL_WIDTH = 16;
    localparam int MULT_LATENCY = 21;

    // Сигналы
    logic clk_i;
    logic reset_i;
    logic enable_i;
    logic strob_i;
    logic order_sel_i;
    logic signed [SIGNAL_WIDTH-1:0] signal_i;
    logic signed [SIGNAL_WIDTH-1:0] taps_i [0:N-1];
    logic signed [BITS_W-1:0] signal_o;

    // Внутренние переменные
    integer fd_in, fd_out;
    logic signed [BITS_W-1:0] data_out_ref;
    logic signed [SIGNAL_WIDTH-1:0] data_in;
    integer sample_cnt;
    integer eof_in;

    logic signed [BITS_W-1:0] curr_error;
    logic signed [2*BITS_W-1:0] sum_error = 0;
    logic [31:0] mismatch_cnt = 0;

    localparam logic signed [SIGNAL_WIDTH-1:0] COEFFS [0:N-1] = '{
        183,    280,   56,   -481,
       -946,   -572,   801,   2279,
        2107,  -632,  -4584, -6059,
       -1439,   9753,  23395, 32767,
        32767,  23395, 9753, -1439,
       -6059,  -4584, -632,   2107,
        2279,   801,  -572,  -946,
       -481,    56,    280,   183
    };

    param_filter #(
        .N            (N),
        .BITS_W       (BITS_W),
        .MULT_LATENCY (MULT_LATENCY)
    ) dut (
        .reset_i      (reset_i),
        .clk_i        (clk_i),
        .enable_i     (enable_i),
        .strob_i      (strob_i),
        .signal_i     (signal_i),
        .taps_i       (taps_i),
        .order_sel_i  (order_sel_i),
        .signal_o     (signal_o)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        string file_in, file_out;
        $sformat(file_in,  "%stest%0d_in.txt",  FILE_DIR, TEST_NUM);
        $sformat(file_out, "%stest%0d_out.txt", FILE_DIR, TEST_NUM);

        fd_in  = $fopen(file_in,  "r");
        fd_out = $fopen(file_out, "r");

        if (!fd_in || !fd_out) begin
            $display("ERROR: Cannot open test files for test %0d", TEST_NUM);
            $finish;
        end

        enable_i    = 1'b1;
        order_sel_i = 1'b0;
        strob_i     = 1'b0;

        foreach (taps_i[i]) begin
            taps_i[i] = COEFFS[i];
        end

        reset_i = 1'b1;
        clk_i = 1'b0;
        signal_i = 0;
        #20;
        reset_i = 1'b0;

        sample_cnt = -1;
        eof_in = 0;

        forever begin
            @(posedge clk_i);
            sample_cnt = sample_cnt + 1;

            if (!$feof(fd_in)) begin
                if ($fscanf(fd_in, "%d", data_in) == 1) begin
                    signal_i = data_in;
                end else begin
                    break;
                end
            end

            if (sample_cnt >= DELAY-1) begin
                if ($fscanf(fd_out, "%d", data_out_ref) == 1) begin
                    #1;
                    curr_error = signal_o - data_out_ref;

                    if (sample_cnt >= DELAY + N - 4) begin
                        sum_error = sum_error + curr_error;
                        if (signal_o !== data_out_ref)
                            mismatch_cnt = mismatch_cnt + 1;
                    end
                end
            end else begin
                curr_error = 0;
            end
        end

        $fclose(fd_in);
        $fclose(fd_out);
        $display("Test %0d finished. Mismatches: %0d", TEST_NUM, mismatch_cnt);
        $finish;
    end

endmodule
