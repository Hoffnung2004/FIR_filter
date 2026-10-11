module adder_tree_new #(
    parameter int NUM_INPUTS = 2, 
    parameter int BITS_W = 48,    
    parameter int LEVEL = 0        
)(
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     reset_i,
    input  logic signed [BITS_W-1:0] inputs_i [0:NUM_INPUTS-1],
    output logic signed [BITS_W-1:0] summ_o
);
    // =========================================================================
    // БАЗОВЫЙ СЛУЧАЙ 1: 1 вход
    // =========================================================================
    if (NUM_INPUTS == 1) begin : gen_base_1
        logic signed [BITS_W-1:0] stage_ff;
        always_ff @(posedge clk_i) begin
            if (reset_i) begin
                summ_o   <= '0;
                stage_ff <= '0;
            end else if (enable_i) begin
                stage_ff <= inputs_i[0];
                summ_o   <= stage_ff;
            end
        end

    // =========================================================================
    // БАЗОВЫЙ СЛУЧАЙ 2: 2 входа (финальный сумматор 2:1)
    // =========================================================================
    end else if (NUM_INPUTS == 2) begin : gen_base_2
        logic signed [BITS_W-1:0] sum;

        adder #(.N(BITS_W))
        final_add(
         .clk_i(clk_i),
         .enable_i(enable_i),
         .reset_i(reset_i),
         .a_i(inputs_i[0]),
         .b_i(inputs_i[1]),
         .summ(sum)
        );
        delay #(
            .D(LEVEL==0 ? 1 : 0),
            .W(BITS_W)
        ) u_delay (
            .clk_i   (clk_i),
            .enable_i(enable_i),
            .reset_i (reset_i),
            .signal_i(sum),
            .signal_o(summ_o)
        );

    // =========================================================================
    // РЕКУРСИЯ: NUM_INPUTS >= 3
    // Выполняем 2 уровня сжатия (комбинационно) -> регистры -> рекурсия
    // =========================================================================
    end else begin : gen_compress_stage

        // ---------------------------------------------------------------------
        // СЛОЙ 1: сжатие NUM_INPUTS -> L1_COUNT
        // ---------------------------------------------------------------------
        localparam int L0_QUADS   = NUM_INPUTS / 4;
        localparam int L0_REM     = NUM_INPUTS % 4;
        localparam int L0_HAS_3   = (L0_REM == 3) ? 1 : 0;
        localparam int L0_BYPASS  = (L0_REM == 3) ? 0 : L0_REM;
        // Четверки дают 2 выхода, тройка дает 2 выхода, байпас идет 1:1
        localparam int L1_COUNT   = (L0_QUADS * 2) + (L0_HAS_3 * 2) + L0_BYPASS;

        logic signed [BITS_W-1:0] l1_wires [0:L1_COUNT-1];

        // 1.1 Сжатие четверок блоками 4:2
        for (genvar i = 0; i < L0_QUADS; i++) begin : gen_l0_4to2
            adder4to2 #(.N(BITS_W)) u_4to2 (
                .a_i(inputs_i[4*i]),
                .b_i(inputs_i[4*i+1]),
                .c_i(inputs_i[4*i+2]),
                .d_i(inputs_i[4*i+3]),
                .a_o(l1_wires[2*i]),
                .b_o(l1_wires[2*i+1])
            );
        end

        // 1.2 Если в остатке 3 операнда -> жмем блоком 3:2
        if (L0_HAS_3) begin : gen_l0_3to2
            adder3to2 #(.N(BITS_W)) u_3to2 (
                .a_i(inputs_i[4*L0_QUADS]),
                .b_i(inputs_i[4*L0_QUADS+1]),
                .c_i(inputs_i[4*L0_QUADS+2]),
                .a_o(l1_wires[2*L0_QUADS]),
                .b_o(l1_wires[2*L0_QUADS+1])
            );
        end

        // 1.3 Если в остатке 1 или 2 операнда -> байпас на следующий слой
        for (genvar i = 0; i < L0_BYPASS; i++) begin : gen_l0_bypass
            assign l1_wires[2*L0_QUADS + i] = inputs_i[4*L0_QUADS + i];
        end

        // ---------------------------------------------------------------------
        // СЛОЙ 2: сжатие L1_COUNT -> L2_COUNT
        // ---------------------------------------------------------------------
        if (L1_COUNT <= 2) begin : gen_l1_done
            // Если уже осталось <= 2 операндов, сразу регистрируем
            logic signed [BITS_W-1:0] stage_regs_ff [0:L1_COUNT-1];

            always_ff @(posedge clk_i) begin
                if (reset_i) begin
                    for (int i = 0; i < L1_COUNT; i++) stage_regs_ff[i] <= '0;
                end else if (enable_i) begin
                    for (int i = 0; i < L1_COUNT; i++) stage_regs_ff[i] <= l1_wires[i];
                end
            end

            adder_tree_new #(
                .NUM_INPUTS(L1_COUNT),
                .BITS_W    (BITS_W),
                .LEVEL (LEVEL+1)
            ) u_next_tree_stage (
                .clk_i   (clk_i),
                .enable_i(enable_i),
                .reset_i (reset_i),
                .inputs_i(stage_regs_ff),
                .summ_o  (summ_o)
            );

        end else begin : gen_l1_compress
            localparam int L1_QUADS  = L1_COUNT / 4;
            localparam int L1_REM    = L1_COUNT % 4;
            localparam int L1_HAS_3  = (L1_REM == 3) ? 1 : 0;
            localparam int L1_BYPASS = (L1_REM == 3) ? 0 : L1_REM;
            localparam int L2_COUNT  = (L1_QUADS * 2) + (L1_HAS_3 * 2) + L1_BYPASS;

            logic signed [BITS_W-1:0] l2_wires [0:L2_COUNT-1];

            // 2.1 Сжатие четверок блоками 4:2
            for (genvar i = 0; i < L1_QUADS; i++) begin : gen_l1_4to2
                adder4to2 #(.N(BITS_W)) u_4to2 (
                    .a_i(l1_wires[4*i]),
                    .b_i(l1_wires[4*i+1]),
                    .c_i(l1_wires[4*i+2]),
                    .d_i(l1_wires[4*i+3]),
                    .a_o(l2_wires[2*i]),
                    .b_o(l2_wires[2*i+1])
                );
            end

            // 2.2 Если в остатке 3 операнда -> жмем блоком 3:2
            if (L1_HAS_3) begin : gen_l1_3to2
                adder3to2 #(.N(BITS_W)) u_3to2 (
                    .a_i(l1_wires[4*L1_QUADS]),
                    .b_i(l1_wires[4*L1_QUADS+1]),
                    .c_i(l1_wires[4*L1_QUADS+2]),
                    .a_o(l2_wires[2*L1_QUADS]),
                    .b_o(l2_wires[2*L1_QUADS+1])
                );
            end

            // 2.3 Если в остатке 1 или 2 операнда -> байпас
            for (genvar i = 0; i < L1_BYPASS; i++) begin : gen_l1_bypass
                assign l2_wires[2*L1_QUADS + i] = l1_wires[4*L1_QUADS + i];
            end

            // -----------------------------------------------------------------
            // РЕГИСТРЫ ПОСЛЕ 2 СЛОЕВ СЖАТИЯ
            // -----------------------------------------------------------------
            logic signed [BITS_W-1:0] stage_regs_ff [0:L2_COUNT-1];

            always_ff @(posedge clk_i) begin
                if (reset_i) begin
                    for (int i = 0; i < L2_COUNT; i++) stage_regs_ff[i] <= '0;
                end else if (enable_i) begin
                    for (int i = 0; i < L2_COUNT; i++) stage_regs_ff[i] <= l2_wires[i];
                end
            end

            // Рекурсивный переход дальше
            adder_tree_new #(
                .NUM_INPUTS(L2_COUNT),
                .BITS_W    (BITS_W),
                .LEVEL (LEVEL+1)
            ) u_next_tree_stage (
                .clk_i   (clk_i),
                .enable_i(enable_i),
                .reset_i (reset_i),
                .inputs_i(stage_regs_ff),
                .summ_o  (summ_o)
            );
        end
    end

endmodule
