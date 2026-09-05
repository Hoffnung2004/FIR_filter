`timescale 1ns / 1ps

module coeff_storage_core #(
    parameter int COEFF_WIDTH = 16,
    parameter int PHASE_NUM = 3,
    parameter int TAPS_PER_PHASE = 8,

    localparam int TOTAL_COEFF_NUM = PHASE_NUM * TAPS_PER_PHASE,
    localparam int COEFF_ADDR_WIDTH = (TOTAL_COEFF_NUM <= 1) ? 1 : $clog2(TOTAL_COEFF_NUM)
)(
    input logic reset_i,
    input logic clk_i,
    input logic enable_i,
    input logic apply_i,
    input logic apply_all_i,

    input logic wr_ena_i,
    input logic [COEFF_ADDR_WIDTH-1:0] wr_addr_i,
    input logic signed [COEFF_WIDTH-1:0] wr_data_i,

    output logic signed [COEFF_WIDTH-1:0] coeff_o [0:PHASE_NUM-1][0:TAPS_PER_PHASE-1],

    output logic busy_o,
    output logic done_o
);

    localparam int TAP_CNT_WIDTH = (TAPS_PER_PHASE <= 1) ? 1 : $clog2(TAPS_PER_PHASE);

    initial begin : p_parameter_check
        if (PHASE_NUM < 1) begin
            $fatal(1, "coeff_storage_core: PHASE_NUM must be >= 1");
        end

        if (TAPS_PER_PHASE < 1) begin
            $fatal(1, "coeff_storage_core: TAPS_PER_PHASE must be >= 1");
        end
    end : p_parameter_check

    // Новая ИХ загружается в теневой банк.
    logic signed [COEFF_WIDTH-1:0] shadow_bank_ff [0:PHASE_NUM*TAPS_PER_PHASE-1];
    logic signed [COEFF_WIDTH-1:0] shadow_bank [0:PHASE_NUM-1][0:TAPS_PER_PHASE-1];

    // Из активного банка коэффициенты получает фильтр.
    logic signed [COEFF_WIDTH-1:0] active_bank_ff [0:PHASE_NUM-1][0:TAPS_PER_PHASE-1];

    // Tap, который обновится при следующем enable_i.
    logic [TAP_CNT_WIDTH-1:0] tap_cnt_ff;

    logic busy_ff;
    logic done_ff;

    int unsigned wr_phase_id;
    int unsigned wr_tap_id;
    int unsigned wr_addr_value;

    logic wr_addr_valid;

    /*
     * phase = address % PHASE_NUM
     * tap = address / PHASE_NUM
     * address = tap * PHASE_NUM + phase
     */
    always_comb begin : c_write_address_decode
        wr_addr_value = int'(wr_addr_i);
        wr_phase_id = wr_addr_value % PHASE_NUM;
        wr_tap_id = wr_addr_value / PHASE_NUM;
        wr_addr_valid = wr_addr_value < TOTAL_COEFF_NUM;
    end : c_write_address_decode

    // Запись новой ИХ в shadow bank.
    always_ff @(posedge clk_i) begin : p_shadow_bank
        if(reset_i) begin
            for(int i=0; i<PHASE_NUM*TAPS_PER_PHASE; i++) begin
                shadow_bank_ff[i]<=16'b1; // only to debug
            end
        end else if (wr_ena_i && wr_addr_valid && !busy_ff) begin
            shadow_bank_ff[wr_addr_value] <= wr_data_i;
        end
    end : p_shadow_bank
    
    for(genvar addr=0; addr<TOTAL_COEFF_NUM; addr++) begin
        assign shadow_bank[addr%PHASE_NUM][addr/PHASE_NUM]=shadow_bank_ff[addr];
    end

    // Управление последовательным переносом коэффициентов.
    always_ff @(posedge clk_i) begin : p_update_controller
        if (reset_i) begin
            tap_cnt_ff <= '0;
            busy_ff <= 1'b0;
            done_ff <= 1'b0;
        end
        else begin
            done_ff <= 1'b0;

            if (!busy_ff) begin
                if (apply_i && !apply_all_i) begin
                    tap_cnt_ff <= '0;
                    busy_ff <= 1'b1;
                end
            end
            else if (enable_i) begin
                if (int'(tap_cnt_ff) == TAPS_PER_PHASE - 1) begin
                    tap_cnt_ff <= '0;
                    busy_ff <= 1'b0;
                    done_ff <= 1'b1;
                end
                else begin
                    tap_cnt_ff <= tap_cnt_ff + 1'b1;
                end
            end
        end
    end : p_update_controller

    // За один enable_i обновляется один tap сразу для всех фаз.
    always_ff @(posedge clk_i) begin : p_active_bank
        if(reset_i) begin
            for(int i=0; i<PHASE_NUM; i++) begin
                for(int j=0; j<TAPS_PER_PHASE; j++) begin
                    active_bank_ff[i][j]<=16'b0; // only to debug
                end
            end

        end else if (apply_all_i && !busy_ff && !apply_i && !wr_ena_i) begin
            for (int phase_id = 0; phase_id < PHASE_NUM; phase_id++) begin
                for (int tap_id = 0; tap_id < TAPS_PER_PHASE; tap_id++) begin
                    active_bank_ff[phase_id][tap_id]
                        <= shadow_bank[phase_id][tap_id];
                end
            end

        end else if (busy_ff && enable_i) begin
            for (int phase_id = 0; phase_id < PHASE_NUM; phase_id++) begin
                active_bank_ff[phase_id][tap_cnt_ff] <= shadow_bank[phase_id][tap_cnt_ff];
            end
        end
    end : p_active_bank

    assign coeff_o = active_bank_ff;
    assign busy_o = busy_ff;
    assign done_o = done_ff;

endmodule