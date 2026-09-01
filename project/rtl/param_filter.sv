module param_filter
#(
    parameter int N = 16, // обязательно кратное 4
    parameter int BITS_W = 40,
    parameter int MULT_LATENCY = 21  // Задержка умножителя в тактах
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic strob_i,
    input logic signed [15:0] signal_i,
    input logic signed [15:0] taps_i [0:N-1],
    input logic order_sel_i, // 0 -> N, 1 -> N/2
    output logic signed [BITS_W-1:0] signal_o   
);
    logic enable;
    assign enable=(enable_i&(!order_sel_i))|(enable_i&order_sel_i&strob_i);

    localparam int HALF = N / 2;
    localparam int NUM_PAIRS = HALF / 2;
    
    localparam int ADDER_TREE_LATENCY = (NUM_PAIRS <= 1) ? 0 : $clog2(NUM_PAIRS);
    localparam int TOTAL_LATENCY = MULT_LATENCY + ADDER_TREE_LATENCY + 2;
    
    logic signed [BITS_W-1:0] upper_ff  [0:HALF-1];
    logic signed [BITS_W-1:0] upper_next [0:HALF-1];
    logic signed [BITS_W-1:0] lower_ff  [0:HALF-1];
    logic signed [BITS_W-1:0] lower_next [0:HALF-1];
    logic signed [BITS_W-1:0] saved_prev; 
     
    always_comb begin: c_shift_logic     //логика сдвига с мультиплексорами в линиях задержки
        //Формирует входы регистров upper_next и lower_next в зависимости
        //от режима, реализуя последовательное соединение регистров или
        //обход каждого второго регистра
        upper_next[0] = signal_i;
    
        for (int i = 1; i < HALF; i++) begin
            if ((i % 2) == 0) begin   // чётные
                // mux перед регистром
                if (order_sel_i == '0)
                    upper_next[i] = upper_ff[i-1];
                else
                    upper_next[i] = upper_ff[i-2];
            end else begin
                upper_next[i] = upper_ff[i-1];
            end
        end
    
        if (order_sel_i == '0)
            lower_next[0] = upper_ff[HALF-1];
        else
            lower_next[0] = saved_prev;
    
        for (int i = 1; i < HALF; i++) begin
            if ((i % 2) == 1) begin   // нечётные
                // mux перед регистром
                if (order_sel_i == '0)
                    lower_next[i] = lower_ff[i-1];
                else begin
                    if (i == 1)
                        lower_next[i] = saved_prev;//'0;
                    else
                        lower_next[i] = lower_ff[i-2];
                end
            end else begin
                lower_next[i] = lower_ff[i-1];
            end
        end
    end: c_shift_logic
    
    always_ff @(posedge clk_i) begin: p_upper //регистровый слой верхней линии задержки(смотрите схему в статье)
    //Тактируется по clk_i, обновляется при enable_i = 1
    //Содержит регистры upper_ff[0..HALF-1]
        if (reset_i) begin
            for (int i = 0; i < HALF; i++) upper_ff[i] <= '0;
        end else if (enable) begin
            upper_ff <= upper_next;
        end
    end: p_upper
    
    always_ff @(posedge clk_i) begin: p_lower //регистровый слой нижней линии задержки
        if (reset_i) begin
            for (int i = 0; i < HALF; i++) lower_ff[i] <= '0;
        end else if (enable) begin
            lower_ff <= lower_next;
        end
    end: p_lower
    
    always_ff @(posedge clk_i) begin : p_saved_prev //регистр, сохраняющий входной сигнал в моменты, когда enable = 0(так как enable во всех режимах имеет частоту в 2 раза меньшк clk)
    //Сохранённое значение saved_prev используется в режиме N/2 для левого нижнего мультиплексора
        if (reset_i) begin
            saved_prev <= '0;
        end else if (enable_i&order_sel_i&(!strob_i)) begin  
            saved_prev <= signal_i;
        end
    end
    
    logic signed [BITS_W-1:0] samp_upper [0:HALF-1];
    logic signed [BITS_W-1:0] samp_lower [0:HALF-1];
    logic signed [15:0]       coef_upper [0:HALF-1];
    logic signed [15:0]       coef_lower [0:HALF-1];
    
    logic signed [BITS_W-1:0] tree_in_ue [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] tree_in_uo [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] tree_in_le [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] tree_in_lo [0:NUM_PAIRS-1];
    
    logic signed [15:0] coef_ue [0:NUM_PAIRS-1];
    logic signed [15:0] coef_uo [0:NUM_PAIRS-1];
    logic signed [15:0] coef_le [0:NUM_PAIRS-1];
    logic signed [15:0] coef_lo [0:NUM_PAIRS-1];
    
    always_comb begin: c_mux //логика подготовки сэмплов и коэффициентов для умножителей
    //подключает выходы мультиплексоров линий задержки к входам умножителей
    //выбирает коэффициенты в соответствии с режимом
    //раскладывает сэмплы и коэффициенты для четырёх деревьев сумматоров
        //Верхняя линия
       // samp_upper[0] = signal_i;
        for (int k = 0; k < HALF; k++) begin
            samp_upper[k] = upper_ff[k];
        end
    
        //Нижняя линия
        //samp_lower[0] = lower_next[0];
        for (int k = 0; k < HALF-1; k++) begin
            samp_lower[k] = lower_ff[k];
        end
    
        //На последний умножитель
        if (order_sel_i == '0)
            samp_lower[HALF-1] = lower_ff[HALF-1];
        else
            samp_lower[HALF-1] = lower_ff[HALF-2];
    
        for (int k = 0; k < HALF; k++) begin
            if (order_sel_i == '0) begin
                coef_upper[k] = taps_i[k];
                coef_lower[k] = taps_i[k + HALF];
            end else begin
                coef_upper[k] = taps_i[k];
                coef_lower[k] = taps_i[k];
            end
        end
    
        for (int k = 0; k < NUM_PAIRS; k++) begin
            tree_in_ue[k] = samp_upper[2*k];
            tree_in_uo[k] = samp_upper[2*k + 1];
            tree_in_le[k] = samp_lower[2*k];
            tree_in_lo[k] = samp_lower[2*k + 1];
    
            coef_ue[k] = coef_upper[2*k];
            coef_uo[k] = coef_upper[2*k + 1];
            coef_le[k] = coef_lower[2*k];
            coef_lo[k] = coef_lower[2*k + 1];
        end
    end: c_mux
    
    logic signed [31:0] prod_raw_ue [0:NUM_PAIRS-1];
    logic signed [31:0] prod_raw_uo [0:NUM_PAIRS-1];
    logic signed [31:0] prod_raw_le [0:NUM_PAIRS-1];
    logic signed [31:0] prod_raw_lo [0:NUM_PAIRS-1];
    
    logic signed [BITS_W-1:0] prod_ue [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] prod_uo [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] prod_le [0:NUM_PAIRS-1];
    logic signed [BITS_W-1:0] prod_lo [0:NUM_PAIRS-1];
    
    generate
        for (genvar k = 0; k < NUM_PAIRS; k++) begin : g_mult_ue //умножители для верхней ветви, чётные сэмплы
            multiplier16 u_mult (
                .clk_i   (clk_i),
                .enable_i(enable),
                .reset_i (reset_i),
                .a_i     (tree_in_ue[k][15:0]),
                .b_i     (coef_ue[k]),
                .m_o     (prod_raw_ue[k])
            );
        end
        for (genvar k = 0; k < NUM_PAIRS; k++) begin : g_mult_uo //умножители для верхней ветви, нечётные сэмплы
            multiplier16 u_mult (
                .clk_i   (clk_i),
                .enable_i(enable),
                .reset_i (reset_i),
                .a_i     (tree_in_uo[k][15:0]),
                .b_i     (coef_uo[k]),
                .m_o     (prod_raw_uo[k])
            );
        end
        for (genvar k = 0; k < NUM_PAIRS; k++) begin : g_mult_le //умножители для нижней ветви, чётные сэмплы
            multiplier16 u_mult (
                .clk_i   (clk_i),
                .enable_i(enable),
                .reset_i (reset_i),
                .a_i     (tree_in_le[k][15:0]),
                .b_i     (coef_le[k]),
                .m_o     (prod_raw_le[k])
            );
        end
        for (genvar k = 0; k < NUM_PAIRS; k++) begin : g_mult_lo //умножители для нижней ветви, нечётные сэмплы
            multiplier16 u_mult (
                .clk_i   (clk_i),
                .enable_i(enable),
                .reset_i (reset_i),
                .a_i     (tree_in_lo[k][15:0]),
                .b_i     (coef_lo[k]),
                .m_o     (prod_raw_lo[k])
            );
        end
    endgenerate
    
    //Расширение знака с 32 бит до BITS_W для adder_tree
    always_comb begin: c_mult_extend
        for (int k = 0; k < NUM_PAIRS; k++) begin
            prod_ue[k] = BITS_W'($signed(prod_raw_ue[k]));
            prod_uo[k] = BITS_W'($signed(prod_raw_uo[k]));
            prod_le[k] = BITS_W'($signed(prod_raw_le[k]));
            prod_lo[k] = BITS_W'($signed(prod_raw_lo[k]));
        end
    end: c_mult_extend
    
    logic signed [BITS_W-1:0] sum_ue;
    logic signed [BITS_W-1:0] sum_uo;
    logic signed [BITS_W-1:0] sum_le;
    logic signed [BITS_W-1:0] sum_lo;

    //Деревья сумматоров
    generate
        adder_tree #(
            .NUM_INPUTS(NUM_PAIRS),
            .BITS_W(BITS_W),
            .LEVEL(0)
        ) u_tree_ue (
            .clk_i    (clk_i),
            .enable_i (enable),
            .reset_i  (reset_i),
            .inputs_i (prod_ue),
            .summ_o   (sum_ue)
        );

        adder_tree #(
            .NUM_INPUTS(NUM_PAIRS),
            .BITS_W(BITS_W),
            .LEVEL(0)
        ) u_tree_uo (
            .clk_i    (clk_i),
            .enable_i (enable),
            .reset_i  (reset_i),
            .inputs_i (prod_uo),
            .summ_o   (sum_uo)
        );

        adder_tree #(
            .NUM_INPUTS(NUM_PAIRS),
            .BITS_W(BITS_W),
            .LEVEL(0)
        ) u_tree_le (
            .clk_i    (clk_i),
            .enable_i (enable),
            .reset_i  (reset_i),
            .inputs_i (prod_le),
            .summ_o   (sum_le)
        );

        adder_tree #(
            .NUM_INPUTS(NUM_PAIRS),
            .BITS_W(BITS_W),
            .LEVEL(0)
        ) u_tree_lo (
            .clk_i    (clk_i),
            .enable_i (enable),
            .reset_i  (reset_i),
            .inputs_i (prod_lo),
            .summ_o   (sum_lo)
        );
    endgenerate


    logic order_sel_delayed;

    delay #(
        .D (TOTAL_LATENCY),
        .W (1)
    ) u_delay_order (
        .reset_i  (reset_i),
        .clk_i    (clk_i),
        .enable_i (enable),
        .signal_i (order_sel_i),
        .signal_o (order_sel_delayed)
    );

    logic signed [BITS_W-1:0] zero;
    assign zero = '0;
    
    logic signed [BITS_W-1:0] pair_a_b;
    logic signed [BITS_W-1:0] pair_b_b;
    
    always_comb begin
        if (order_sel_delayed == '0) begin
            pair_a_b = sum_uo;
            pair_b_b = sum_lo;
        end else begin
            pair_a_b = sum_lo;
            pair_b_b = sum_uo;
        end
    end
    
    logic signed [BITS_W-1:0] stage1_a;
    logic signed [BITS_W-1:0] stage1_b;
    
    adder #(.N(BITS_W)) u_add_stage1_a (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (sum_ue),
        .b_i     (pair_a_b),
        .summ    (stage1_a)
    );
    
    adder #(.N(BITS_W)) u_add_stage1_b (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (sum_le),
        .b_i     (pair_b_b),
        .summ    (stage1_b)
    );
    
    logic signed [BITS_W-1:0] order_sel_stage1;
    logic signed [BITS_W-1:0] order_sel_ext;
    assign order_sel_ext = $signed({{(BITS_W-1){1'b0}}, order_sel_delayed});
    
    adder #(.N(BITS_W)) u_delay_order_stage1 (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (order_sel_ext),
        .b_i     (zero),
        .summ    (order_sel_stage1)
    );
    
    logic signed [BITS_W-1:0] stage2_b_current;
    always_comb begin
        if (order_sel_stage1[0] == 1'b0)
            stage2_b_current = stage1_b;
        else
            stage2_b_current = zero;
    end
    
    logic signed [BITS_W-1:0] y_current_raw;
    logic signed [BITS_W-1:0] y_prev_raw;
    
    adder #(.N(BITS_W)) u_add_current (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (stage1_a),
        .b_i     (stage2_b_current),
        .summ    (y_current_raw)
    );
    
    adder #(.N(BITS_W)) u_add_prev (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (stage1_b),
        .b_i     (zero),
        .summ    (y_prev_raw)
    );
    
    logic signed [BITS_W-1:0] order_sel_final;
    
    adder #(.N(BITS_W)) u_delay_order_final (
        .clk_i   (clk_i),
        .enable_i(enable),
        .reset_i (reset_i),
        .a_i     (order_sel_stage1),
        .b_i     (zero),
        .summ    (order_sel_final)
    );
    
    logic signed [BITS_W-1:0] y_current_next;
    logic signed [BITS_W-1:0] y_prev_next;
    
    always_comb begin
        if (order_sel_final[0] == 1'b0) begin
            y_current_next = y_current_raw;
            y_prev_next    = '0;
        end else begin
            y_current_next = y_current_raw;
            y_prev_next    = y_prev_raw;
        end
    end
    
    logic signed [BITS_W-1:0] y_current_ff;
    logic signed [BITS_W-1:0] y_prev_ff;
    
    always_ff @(posedge clk_i) begin: p_final_regs
        if (reset_i) begin
            y_current_ff <= '0;
            y_prev_ff    <= '0;
        end else if (enable) begin
            y_current_ff <= y_current_next;
            y_prev_ff    <= y_prev_next;
        end
    end: p_final_regs

    logic psc_phase_ff;
    
    always_ff @(posedge clk_i) begin: p_psc_phase //фазовый триггер, переключается на каждом такте clk_i
        if (reset_i) begin
            psc_phase_ff <= '0;
        end else if (enable_i) begin
            psc_phase_ff <= ~psc_phase_ff;
        end
    end: p_psc_phase

    logic signed [BITS_W-1:0] psc_out;
    assign psc_out = (psc_phase_ff == '0) ? y_prev_ff : y_current_ff;

    logic signed [BITS_W-1:0] signal_o_n_ff;
    logic signed [BITS_W-1:0] signal_o_n2_ff;

    always_ff @(posedge clk_i) begin: p_out_n
        if (reset_i) begin
            signal_o_n_ff <= '0;
        end else if (enable) begin
            signal_o_n_ff <= y_current_ff;
        end
    end: p_out_n

    always_ff @(posedge clk_i) begin: p_out_n2
        if (reset_i) begin
            signal_o_n2_ff <= '0;
        end else begin
            signal_o_n2_ff <= psc_out;
        end
    end: p_out_n2

    assign signal_o = order_sel_delayed ? signal_o_n2_ff : signal_o_n_ff; //финальный мультиплексор, выбирающий выход в зависимости от order_sel_delayed
    
endmodule 