`timescale 1ns / 1ps
import fir_filter_params_pkg::*;

module fir_filter_top_tb;
    localparam string FILE_DIR = "../../../../fir_filter_project.ip_user_files/mem_init_files/";
    // Параметры теста
    localparam int TEST_NUM = 9;          // <-- МЕНЯТЬ ЭТОТ НОМЕР ДЛЯ РАЗНЫХ ТЕСТОВ
    localparam int DELAY    = 1;         // <-- ЗАДЕРЖКА ФИЛЬТРА В ТАКТАХ 

    // Сигналы
    logic clk_i;
    logic reset_i;
    logic signed [SIGNAL_WIDTH-1:0] signal_i;
    logic signed [TREE_BIT_WIDTH[TREE_LEN-1][0]-1:0] signal_o;

    // Внутренние переменные тестбенча
    integer fd_in, fd_out;
    logic signed [TREE_BIT_WIDTH[TREE_LEN-1][0]-1:0] data_out_ref;
    logic signed [SIGNAL_WIDTH-1:0] data_in;
    integer sample_cnt;
    integer eof_in;

    // Доп. вейформы
    logic signed [TREE_BIT_WIDTH[TREE_LEN-1][0]-1:0] curr_error;
    logic signed [2*TREE_BIT_WIDTH[TREE_LEN-1][0]-1:0] sum_error = 0;
    logic [31:0] mismatch_cnt = 0;

    // DUT
    fir_filter_top dut (
        .clk_i   (clk_i),
        .reset_i (reset_i),
        .signal_i(signal_i),
        .signal_o(signal_o)
    );

    // Clock generation
    always #5 clk_i = ~clk_i; // 100 MHz
    
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

        // Reset
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
            // Чтение входного отсчёта
            if (!$feof(fd_in)) begin
                if ($fscanf(fd_in, "%d", data_in) == 1) begin
                    signal_i = data_in;
                end else begin
                    break;
                end
            end
            
            // Обработка выхода с учётом задержки
            if (sample_cnt >= DELAY) begin
                // Читаем эталонный выход 
                $fscanf(fd_out, "%d", data_out_ref);
                                
                #1;
                // Вычисляем ошибку
                curr_error = signal_o - data_out_ref;

                // Накопление
                sum_error = sum_error + curr_error;

                // Счётчик несовпадений
                if (signal_o !== data_out_ref) begin
                    mismatch_cnt = mismatch_cnt + 1;
                end
            end else begin
                curr_error = 0;
                // До истечения DELAY - не сравниваем
            end

            


        end

        $fclose(fd_in);
        $fclose(fd_out);
        $display("Test %0d finished. Mismatches: %0d", TEST_NUM, mismatch_cnt);
        $finish;
    end
    initial begin
        
    end

endmodule