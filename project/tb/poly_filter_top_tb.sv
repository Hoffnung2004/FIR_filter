`timescale 1ns / 1ps

module poly_filter_top_tb;

    parameter logic ORDER = 0;
    parameter int P = poly_filter_pkg::P; 
    parameter int TAPS_PER_PHASE = poly_filter_pkg::TAPS_PER_PHASE; 
    parameter int BITS_W = poly_filter_pkg::bits_sum(TAPS_PER_PHASE, P);
    parameter int DELAY1=poly_filter_pkg::delay(TAPS_PER_PHASE,P)*P+4-(P==1 ? 1 : 0); 
    parameter int DELAY2=poly_filter_pkg::delay_halfN(TAPS_PER_PHASE,P)*P+4-(P==1 ? 1 : 0);  
    parameter int DELAY_AFTER=poly_filter_pkg::delay_after(TAPS_PER_PHASE,P)*P+poly_filter_pkg::delay_after_after_halfN(TAPS_PER_PHASE,P)*P;  // approximately
    
    typedef logic signed [15:0] tap_t;
    typedef tap_t h_array_t [0:P-1][0:TAPS_PER_PHASE-1];
    function automatic h_array_t gen_random_h(input int seed);
        h_array_t result;
        int state = seed;
        for (int i = 0; i < P; i++) begin
            for (int j = 0; j < TAPS_PER_PHASE; j++) begin
            state = state * 1103515245 + 12345;
            result[i][j] = 16'(state[15:0]);
            end
        end
        return result;
        endfunction
    
    
    parameter logic signed [15:0] H [0:P-1][0:TAPS_PER_PHASE-1] =  gen_random_h(123);

    logic signed [15:0] H_flat [0 : P*TAPS_PER_PHASE - 1];
   
   

   
    genvar i, j;
    generate
    for (j = 0; j < TAPS_PER_PHASE; j++) begin : gen_col
        for (i = 0; i < P; i++) begin : gen_row
        assign H_flat[j * P + i] = H[i][j];
        end
    end
    endgenerate
    
    // Сигналы интерфейса
    logic                 clk_i;
    logic                 reset_i;
    logic                 enable_i;
    logic signed [15:0]   data_i;
    logic                 valid_i;
    logic                 ready_i;
    logic signed [BITS_W-1:0] data_o;
    logic signed [BITS_W-1:0] data2_o;
    logic signed [BITS_W-1:0] data_old;
    logic signed [BITS_W-1:0] data_d;
    logic signed [BITS_W-1:0] gold1_o;
    logic signed errors1;
    logic signed [BITS_W-1:0] gold2_o;
    logic signed errors2;
    logic        [31:0]   delay1;
    logic        [31:0]   delay2;
    logic                 valid_o;
    logic                 ready_o;
    logic                 order_sel_i;
    logic                 valid_b;



    // Инстанцирование тестируемого модуля
    poly_filter_top #(
        .P              (P),
        .TAPS_PER_PHASE (TAPS_PER_PHASE),
        .BITS_W         (BITS_W),
        .H(H)
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
    
    poly_filter_top #(
        .P              (P),
        .TAPS_PER_PHASE (TAPS_PER_PHASE),
        .BITS_W         (BITS_W),
        .H(H)
    ) nodut (
        .clk_i   (clk_i),
        .reset_i (reset_i),
        .enable_i(enable_i),
        .order_sel_i(!order_sel_i),
        .data_i  (data_i),
        .valid_i (valid_i),
        .ready_i (),
        .data_o  (data2_o),
        .valid_o (),
        .ready_o (ready_o)
    );
    
   GOLD_filter #(
    .TAPS(TAPS_PER_PHASE*P),
    .BITS_W(BITS_W),
    .DELAY(DELAY1)
   ) gold_filter1
   (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .signal_i(data_i),
        .h_i(H_flat),
        .signal_o(gold1_o)
    );

   GOLD_filter #(
    .TAPS(TAPS_PER_PHASE*P/2),
    .BITS_W(BITS_W),
    .DELAY(DELAY2)
   ) gold_filter2
   (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .signal_i(data_i),
        .h_i(H_flat[0:TAPS_PER_PHASE*P/2-1]),
        .signal_o(gold2_o)
    );
    
    recordDELAY #(
        .BITS_W(BITS_W)
    ) record1
    (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(1'b1),
        .signal1_i(gold1_o),
        .signal2_i((ORDER ? data2_o : data_o)),
        .delay_o(delay1)
    );
    
    recordDELAY #(
        .BITS_W(BITS_W)
    ) record2
    (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(1'b1),
        .signal1_i(gold2_o),
        .signal2_i((ORDER ? data_o : data2_o)),
        .delay_o(delay2)
    );
    
    // ===== Ловец рассинхрона valid (верификация valid_fsm) =====
    logic        vc_match, vc_false_valid, vc_missed_valid;
    logic [31:0] vc_false_cnt, vc_missed_cnt, vc_since_switch;

    valid_check #(
        .BITS_W(BITS_W)
    ) vcheck (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .valid_i(valid_o),
        .order_sel_i(order_sel_i),
        .data_i(data_o),
        .gold_n_i(gold1_o),
        .gold_half_i(gold2_o),
        .match_o(vc_match),
        .false_valid_o(vc_false_valid),
        .missed_valid_o(vc_missed_valid),
        .false_cnt_o(vc_false_cnt),
        .missed_cnt_o(vc_missed_cnt),
        .since_switch_o(vc_since_switch)
    );

    assign errors1 = |{gold1_o - data_o};
    assign errors2 = |{gold2_o - data_o};
    assign valid_b = (!(errors1 & errors2))&(data_o!=0);
    
    // Генерация тактового сигнала (100 МГц -> период 10 нс)
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end
    

    always_ff @(posedge clk_i) data_old<=data_o;
    // Блок входных воздействий
    initial begin
        // 1. Инициализация
        order_sel_i = ORDER;
        reset_i  = 1;
        enable_i = 0;
        valid_i  = 0;
        ready_o  = 1; 
        data_i   = 0;
        assign data_d = data_o - data_old;

        #50;
        reset_i  = 0;
        enable_i = 1;
        #10;
        valid_i = 1;
        for (int i = 1; i <= DELAY2*4/3; i++) begin 
                                                    
            data_i  = 16'($signed($urandom())  ); 
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ~ORDER;
        

        
        for (int i = 1; i <= DELAY_AFTER/3 ; i++) begin 
                                                                           
            data_i  = 16'( $signed($urandom()));
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ORDER;
        
        for (int i = 1; i <= 5 ; i++) begin 
                                                                          
            data_i  = 16'( $signed($urandom()));
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ~ORDER;
        
        for (int i = 1; i <= 5 ; i++) begin 
                                                                                   
            data_i  = 16'( $signed($urandom()));
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ORDER;
        
        for (int i = 1; i <= 5 ; i++) begin 
                                                                                
            data_i  = 16'( $signed($urandom()));
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ~ORDER;
        
        for (int i = 1; i <= DELAY_AFTER*4/3 ; i++) begin 
                                                
            data_i  = 16'( $signed($urandom()));
            valid_i = 1;
            #1;
            @(negedge clk_i);
        end
        
        order_sel_i = ORDER;
        
        for (int i = 1; i <= DELAY_AFTER*4/3 ; i++) begin 
                                                
            data_i  = 16'( $signed($urandom()));
            valid_i = 1;
            #1;
            @(negedge clk_i);
        end

        $finish;
    end

endmodule