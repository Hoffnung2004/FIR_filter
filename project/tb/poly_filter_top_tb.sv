`timescale 1ns / 1ps

module poly_filter_top_tb;

    // Параметры (при необходимости подгони под свой top-модуль)
    
    parameter int P = 2; 
    parameter int TAPS_PER_PHASE = 4; // кратно 4
    parameter int BITS_W = fir_pkg::bits_sum(TAPS_PER_PHASE, P);
    
    // Сигналы интерфейса
    logic                 clk_i;
    logic                 reset_i;
    logic                 enable_i;
    logic signed [15:0]   data_i;
    logic                 valid_i;
    logic                 ready_i;
    logic signed [BITS_W-1:0] data_o;
    logic signed [BITS_W-1:0] data_old;
    logic signed [BITS_W-1:0] data_d;
    logic                 valid_o;
    logic                 ready_o;
    logic                 order_sel_i;

    // Инстанцирование тестируемого модуля
    poly_filter_top #(
        .P              (P),
        .TAPS_PER_PHASE (TAPS_PER_PHASE),
        .BITS_W         (BITS_W)
    ) dut (
        .clk_i   (clk_i),
        .reset_i (reset_i),
        .enable_i(enable_i),
        .order_sel_i(order_sel_i),
        .data_i  (data_i),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .data_o  (data_o),
        .valid_o (valid_o),
        .ready_o (ready_o)
    );

    // Генерация тактового сигнала (100 МГц -> период 10 нс)
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end
    always_ff @(posedge clk_i) data_old<=data_o;
    // Блок входных воздействий
    initial begin
        // 1. Инициализация
        order_sel_i = 0;
        reset_i  = 1;
        enable_i = 0;
        valid_i  = 0;
        ready_o  = 1;   // Downstream всегда готов принимать
        data_i   = 0;
        assign data_d = data_o - data_old;
        // 2. Сброс (держим 5 тактов)
        #50;
        reset_i  = 0;
        enable_i = 1;
        #10;
        // 3. Отправляем линейно нарастающий сигнал: 1, 2, 3, ... 2^15 - 1
        for (int i = 1; i <= 1200; i++) begin
            data_i  = 16'(i); //16'(i);
            valid_i = 1;
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = 1;
        
        for (int i = 1; i <= 2000; i++) begin
            data_i  = 16'(i); 
            valid_i = 1;
            #1;
            @(negedge clk_i);
        end
        
        // 4. Сбрасываем valid и даем время конвейеру опустошиться
        valid_i = 0;
        
        #300;
        
        ready_o=1;
        
        #300;

        $finish;
    end

endmodule