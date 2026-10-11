module poly_valid_fsm #(
    parameter int P              = 3,
    parameter int TAPS_PER_PHASE = 12,
    parameter int BITS_W         = 40
)(
    input  logic clk_i,
    input  logic reset_i,
    input  logic enable_i,
    input  logic clk_P_i,  
    input  logic order_sel_i,  
    output logic valid_o
);

    // Тут всё в макротактах clk_P (каждый P тактов подаётся импульс)
    localparam int ADDER_LAT       = BITS_W / 8 + 2;
    localparam int NUM_PAIRS       = TAPS_PER_PHASE;
    localparam int TREE_LVLS       = (NUM_PAIRS <= 1) ? 0 : $clog2(NUM_PAIRS);
    localparam int TREE_LAT        = TREE_LVLS * ADDER_LAT;
    localparam int MULT_LAT        = 21;
    localparam int TOTAL_ADDER_LAT = ADDER_LAT * 2 + 2; 
    
    // Задержка ядра в тактах clk_P
    localparam int CORE_LAT_N   = MULT_LAT + TREE_LAT + TOTAL_ADDER_LAT;
    localparam int CORE_LAT_N2  = (MULT_LAT + TREE_LAT + TOTAL_ADDER_LAT) * 2;

    localparam int BLOCKS_N     = CORE_LAT_N  + 2;
    localparam int BLOCKS_N2    = CORE_LAT_N2 + 2;

    typedef enum logic [2:0] {
        ST_RESET,
        ST_FILL_N,
        ST_VALID_N,
        ST_FILL_N2,
        ST_VALID_N2,
        ST_DRAIN_SWITCH
    } state_t;

    state_t state_ff, state_next;

    logic [15:0] cnt_ff, cnt_next;
    logic order_reg_ff;
    logic order_changed;

    assign order_changed = (order_sel_i != order_reg_ff);

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state_ff     <= ST_RESET;
            cnt_ff       <= '0;
            order_reg_ff <= 1'b0;
        end else if (enable_i) begin
            if (clk_P_i) begin
                state_ff     <= state_next;
                cnt_ff       <= cnt_next;
                order_reg_ff <= order_sel_i;
            end
        end
    end

    always_comb begin
        state_next = state_ff;
        cnt_next   = cnt_ff;

        case (state_ff)
            ST_RESET: begin
                cnt_next = '0;
                if (order_sel_i == 1'b0)
                    state_next = ST_FILL_N;
                else
                    state_next = ST_FILL_N2;
            end

            // Заполнение конвейера при старте или переключении на режим N
            ST_FILL_N: begin
                if (cnt_ff >= BLOCKS_N - 1) begin
                    cnt_next   = '0;
                    state_next = ST_VALID_N;
                end else begin
                    cnt_next = cnt_ff + 1'b1;
                end
            end

            ST_VALID_N: begin
                if (order_changed) begin
                    cnt_next   = '0;
                    state_next = ST_FILL_N2;
                end
            end

            // Заполнение конвейера при старте или переключении на режим N/2
            ST_FILL_N2: begin
                if (cnt_ff >= BLOCKS_N2 - 1) begin
                    cnt_next   = '0;
                    state_next = ST_VALID_N2;
                end else begin
                    cnt_next = cnt_ff + 1'b1;
                end
            end

            ST_VALID_N2: begin
                if (order_changed) begin
                    cnt_next   = '0;
                    state_next = ST_FILL_N;
                end
            end

            default: state_next = ST_RESET;
        endcase
    end

    logic fsm_valid;
    assign fsm_valid = (state_ff == ST_VALID_N) || (state_ff == ST_VALID_N2);

    // Тут добиваем фрагменты макротактов
    // serdeser_in обладает переменной задержкой в зависимости от P. Поэтому тут условие
    delay #(
        .D(P == 1 ? 1 : 2),
        .W(1)
    ) u_valid_align (
        .reset_i (reset_i),
        .clk_i   (clk_i),
        .enable_i(enable_i),
        .signal_i(fsm_valid),
        .signal_o(valid_o)
    );

endmodule