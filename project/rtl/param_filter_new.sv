module param_filter_new #(
    parameter int N            = 16, // обязательно кратно 4
    parameter int BITS_W       = 40, // минимум 32
    parameter int MULT_LATENCY = 6
)(
    input  logic                     reset_i,
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     strob_i,
    input  logic signed [15:0]       signal_i,
    input  logic signed [15:0]       taps_i [0:N-1],
    input  logic                     order_sel_i,
    output logic signed [BITS_W-1:0] a_o,
    output logic signed [BITS_W-1:0] b_o
);

    logic enable;
    assign enable = (enable_i & (!order_sel_i)) | (enable_i & order_sel_i & strob_i);

    localparam int HALF        = N / 2;
    localparam int NUM_PAIRS   = HALF / 2;
    localparam int TREE_INPUTS = NUM_PAIRS * 8;

    logic signed [BITS_W-1:0] upper_ff  [0:HALF-1];
    logic signed [BITS_W-1:0] upper_next[0:HALF-1];
    logic signed [BITS_W-1:0] lower_ff  [0:HALF-1];
    logic signed [BITS_W-1:0] lower_next[0:HALF-1];
    logic signed [BITS_W-1:0] saved_prev;

    always_comb begin : c_shift_logic
        upper_next[0] = signal_i;
        for (int i = 1; i < HALF; i++) begin
            if ((i % 2) == 0)
                upper_next[i] = order_sel_i ? upper_ff[i-2] : upper_ff[i-1];
            else
                upper_next[i] = upper_ff[i-1];
        end
        lower_next[0] = order_sel_i ? saved_prev : upper_ff[HALF-1];
        for (int i = 1; i < HALF; i++) begin
            if ((i % 2) == 1) begin
                if (order_sel_i)
                    lower_next[i] = (i == 1) ? saved_prev : lower_ff[i-2];
                else
                    lower_next[i] = lower_ff[i-1];
            end else
                lower_next[i] = lower_ff[i-1];
        end
    end

    always_ff @(posedge clk_i) begin : p_upper
        if (reset_i)      for (int i = 0; i < HALF; i++) upper_ff[i] <= '0;
        else if (enable)  upper_ff <= upper_next;
    end

    always_ff @(posedge clk_i) begin : p_lower
        if (reset_i)      for (int i = 0; i < HALF; i++) lower_ff[i] <= '0;
        else if (enable)  lower_ff <= lower_next;
    end

    always_ff @(posedge clk_i) begin : p_saved_prev
        if (reset_i)                                saved_prev <= '0;
        else if (enable_i & order_sel_i & !strob_i) saved_prev <= signal_i;
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

    always_comb begin : c_mux
        for (int k = 0; k < HALF; k++) samp_upper[k] = upper_ff[k];
        for (int k = 0; k < HALF-1; k++) samp_lower[k] = lower_ff[k];
        samp_lower[HALF-1] = order_sel_i ? lower_ff[HALF-2] : lower_ff[HALF-1];

        for (int k = 0; k < HALF; k++) begin
            if (order_sel_i == 1'b0) begin
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
    end

    logic signed [31:0] part_raw_ue [0:NUM_PAIRS-1][7:0];
    logic signed [31:0] part_raw_uo [0:NUM_PAIRS-1][7:0];
    logic signed [31:0] part_raw_le [0:NUM_PAIRS-1][7:0];
    logic signed [31:0] part_raw_lo [0:NUM_PAIRS-1][7:0];

    generate
        for (genvar k = 0; k < NUM_PAIRS; k++) begin : g_mults
            multiplier16_noSum u_mult_ue (
                .clk_i(clk_i),
                .enable_i(enable),
                .reset_i(reset_i),
                .a_i(tree_in_ue[k][15:0]),
                .b_i(coef_ue[k]),
                .part_prod_o(part_raw_ue[k])
                );

            multiplier16_noSum u_mult_uo (
                .clk_i(clk_i),
                .enable_i(enable),
                .reset_i(reset_i),
                .a_i(tree_in_uo[k][15:0]),
                .b_i(coef_uo[k]),
                .part_prod_o(part_raw_uo[k])
                );

            multiplier16_noSum u_mult_le (
                .clk_i(clk_i),
                .enable_i(enable),
                .reset_i(reset_i),
                .a_i(tree_in_le[k][15:0]),
                .b_i(coef_le[k]),
                .part_prod_o(part_raw_le[k])
                );

            multiplier16_noSum u_mult_lo (
                .clk_i(clk_i),
                .enable_i(enable),
                .reset_i(reset_i),
                .a_i(tree_in_lo[k][15:0]),
                .b_i(coef_lo[k]),
                .part_prod_o(part_raw_lo[k])
                );
        end
    endgenerate

    logic signed [BITS_W-1:0] tree_ue [0:TREE_INPUTS-1];
    logic signed [BITS_W-1:0] tree_uo [0:TREE_INPUTS-1];
    logic signed [BITS_W-1:0] tree_le [0:TREE_INPUTS-1];
    logic signed [BITS_W-1:0] tree_lo [0:TREE_INPUTS-1];

    always_comb begin : c_tree_in
        for (int k = 0; k < NUM_PAIRS; k++) begin
            for (int j = 0; j < 8; j++) begin
                tree_ue[8*k + j] = part_raw_ue[k][j];
                tree_uo[8*k + j] = part_raw_uo[k][j];
                tree_le[8*k + j] = part_raw_le[k][j];
                tree_lo[8*k + j] = part_raw_lo[k][j];
            end
        end
    end

    //4 дерева чистой компрессии
    logic signed [BITS_W-1:0] comp_ue [0:1];
    logic signed [BITS_W-1:0] comp_uo [0:1];
    logic signed [BITS_W-1:0] comp_le [0:1];
    logic signed [BITS_W-1:0] comp_lo [0:1];

    generate
        compress_tree #(
            .NUM_INPUTS(TREE_INPUTS),
            .BITS_W(BITS_W),
            .LEVEL(0)
         ) u_comp_ue (
            .clk_i(clk_i),
            .enable_i(enable),
            .reset_i(reset_i),
            .inputs_i(tree_ue),
            .outputs_o(comp_ue)
         );

        compress_tree #(
            .NUM_INPUTS(TREE_INPUTS),
            .BITS_W(BITS_W),
            .LEVEL(0)
         ) u_comp_uo (
            .clk_i(clk_i),
            .enable_i(enable),
            .reset_i(reset_i),
            .inputs_i(tree_uo),
            .outputs_o(comp_uo)
         );

        compress_tree #(
            .NUM_INPUTS(TREE_INPUTS),
            .BITS_W(BITS_W),
            .LEVEL(0)
         ) u_comp_le (
            .clk_i(clk_i),
            .enable_i(enable),
            .reset_i(reset_i),
            .inputs_i(tree_le),
            .outputs_o(comp_le)
         );

        compress_tree #(
            .NUM_INPUTS(TREE_INPUTS),
            .BITS_W(BITS_W),
            .LEVEL(0)
         ) u_comp_lo (
            .clk_i(clk_i),
            .enable_i(enable),
            .reset_i(reset_i),
            .inputs_i(tree_lo),
            .outputs_o(comp_lo)
         );
    endgenerate

    // Финальная компрессия 8 - 2
    logic signed [BITS_W-1:0] main_in [0:7];
    always_comb begin : c_main_in
        if (order_sel_i == 1'b0) begin
            main_in[0] = comp_ue[0]; main_in[1] = comp_ue[1];
            main_in[2] = comp_uo[0]; main_in[3] = comp_uo[1];
            main_in[4] = comp_le[0]; main_in[5] = comp_le[1];
            main_in[6] = comp_lo[0]; main_in[7] = comp_lo[1];
        end else begin
            main_in[0] = comp_ue[0]; main_in[1] = comp_ue[1];
            main_in[2] = comp_lo[0]; main_in[3] = comp_lo[1];
            main_in[4] = '0; main_in[5] = '0;
            main_in[6] = '0; main_in[7] = '0;
        end
    end

    logic signed [BITS_W-1:0] main_out [0:1];
    compress_tree #(
        .NUM_INPUTS(8),
        .BITS_W(BITS_W),
        .LEVEL(0)
     ) u_comp_main (
        .clk_i(clk_i),
        .enable_i(enable),
        .reset_i(reset_i),
        .inputs_i(main_in),
        .outputs_o(main_out)
     );

    logic signed [BITS_W-1:0] prev_in [0:3];
    logic signed [BITS_W-1:0] prev_out [0:1];
    always_comb begin : c_prev_in
        prev_in[0] = comp_uo[0];
        prev_in[1] = comp_uo[1];
        prev_in[2] = comp_le[0];
        prev_in[3] = comp_le[1];
    end

    compress_tree #(
        .NUM_INPUTS(4),
        .BITS_W(BITS_W),
        .LEVEL(0)
     ) u_comp_prev (
        .clk_i(clk_i),
        .enable_i(enable),
        .reset_i(reset_i),
        .inputs_i(prev_in),
        .outputs_o(prev_out)
     );

    logic signed [BITS_W-1:0] y_cur_a_ff, y_cur_b_ff;
    logic signed [BITS_W-1:0] y_prv_a_ff, y_prv_b_ff;

    always_ff @(posedge clk_i) begin : p_final_regs
        if (reset_i) begin
            y_cur_a_ff <= '0; y_cur_b_ff <= '0;
            y_prv_a_ff <= '0; y_prv_b_ff <= '0;
        end else if (enable) begin
            y_cur_a_ff <= main_out[0]; y_cur_b_ff <= main_out[1];
            if (order_sel_i) begin
                y_prv_a_ff <= prev_out[0]; y_prv_b_ff <= prev_out[1];
            end else begin
                y_prv_a_ff <= '0;          y_prv_b_ff <= '0;
            end
        end
    end

    logic psc_phase_ff;
    always_ff @(posedge clk_i) begin : p_psc_phase
        if (reset_i)       psc_phase_ff <= 1'b0;
        else if (enable_i) psc_phase_ff <= ~psc_phase_ff;
    end

    assign a_o = (order_sel_i && (psc_phase_ff == 1'b0)) ? y_prv_a_ff : y_cur_a_ff;
    assign b_o = (order_sel_i && (psc_phase_ff == 1'b0)) ? y_prv_b_ff : y_cur_b_ff;

endmodule
