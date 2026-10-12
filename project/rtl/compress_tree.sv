module compress_tree #(
    parameter int NUM_INPUTS = 64,
    parameter int BITS_W     = 48,
    parameter int LEVEL      = 0,
    localparam int OUT_COUNT = (NUM_INPUTS == 1) ? 1 : 2
)(
    input  logic                     clk_i,
    input  logic                     enable_i,
    input  logic                     reset_i,
    input  logic signed [BITS_W-1:0] inputs_i [0:NUM_INPUTS-1],
    output logic signed [BITS_W-1:0] outputs_o [0:OUT_COUNT-1]
);

    if (NUM_INPUTS == 1) begin : gen_base_1
        assign outputs_o[0] = inputs_i[0];

    end else if (NUM_INPUTS == 2) begin : gen_base_2
        assign outputs_o[0] = inputs_i[0];
        assign outputs_o[1] = inputs_i[1];

    end else begin : gen_compress_stage

        localparam int L0_QUADS  = NUM_INPUTS / 4;
        localparam int L0_REM    = NUM_INPUTS % 4;
        localparam int L0_HAS_3  = (L0_REM == 3) ? 1 : 0;
        localparam int L0_BYPASS = (L0_REM == 3) ? 0 : L0_REM;
        localparam int L1_COUNT  = (L0_QUADS * 2) + (L0_HAS_3 * 2) + L0_BYPASS;

        logic signed [BITS_W-1:0] l1_wires [0:L1_COUNT-1];

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

        if (L0_HAS_3) begin : gen_l0_3to2
            adder3to2 #(.N(BITS_W)) u_3to2 (
                .a_i(inputs_i[4*L0_QUADS]),
                .b_i(inputs_i[4*L0_QUADS+1]),
                .c_i(inputs_i[4*L0_QUADS+2]),
                .a_o(l1_wires[2*L0_QUADS]),
                .b_o(l1_wires[2*L0_QUADS+1])
            );
        end

        for (genvar i = 0; i < L0_BYPASS; i++) begin : gen_l0_bypass
            assign l1_wires[2*L0_QUADS + i] = inputs_i[4*L0_QUADS + i];
        end

        if (L1_COUNT <= 2) begin : gen_l1_done
            // Если после 1 слоя уже осталось <= 2 проводов, фиксируем их в регистре
            logic signed [BITS_W-1:0] stage_regs_ff [0:L1_COUNT-1];

            always_ff @(posedge clk_i) begin
                if (reset_i) begin
                    for (int i = 0; i < L1_COUNT; i++) stage_regs_ff[i] <= '0;
                end else if (enable_i) begin
                    for (int i = 0; i < L1_COUNT; i++) stage_regs_ff[i] <= l1_wires[i];
                end
            end

            compress_tree #(
                .NUM_INPUTS(L1_COUNT),
                .BITS_W    (BITS_W),
                .LEVEL     (LEVEL + 1)
            ) u_next_tree_stage (
                .clk_i    (clk_i),
                .enable_i (enable_i),
                .reset_i  (reset_i),
                .inputs_i (stage_regs_ff),
                .outputs_o(outputs_o)
            );

        end else begin : gen_l1_compress
            localparam int L1_QUADS  = L1_COUNT / 4;
            localparam int L1_REM    = L1_COUNT % 4;
            localparam int L1_HAS_3  = (L1_REM == 3) ? 1 : 0;
            localparam int L1_BYPASS = (L1_REM == 3) ? 0 : L1_REM;
            localparam int L2_COUNT  = (L1_QUADS * 2) + (L1_HAS_3 * 2) + L1_BYPASS;

            logic signed [BITS_W-1:0] l2_wires [0:L2_COUNT-1];

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

            if (L1_HAS_3) begin : gen_l1_3to2
                adder3to2 #(.N(BITS_W)) u_3to2 (
                    .a_i(l1_wires[4*L1_QUADS]),
                    .b_i(l1_wires[4*L1_QUADS+1]),
                    .c_i(l1_wires[4*L1_QUADS+2]),
                    .a_o(l2_wires[2*L1_QUADS]),
                    .b_o(l2_wires[2*L1_QUADS+1])
                );
            end

            for (genvar i = 0; i < L1_BYPASS; i++) begin : gen_l1_bypass
                assign l2_wires[2*L1_QUADS + i] = l1_wires[4*L1_QUADS + i];
            end

            logic signed [BITS_W-1:0] stage_regs_ff [0:L2_COUNT-1];

            always_ff @(posedge clk_i) begin
                if (reset_i) begin
                    for (int i = 0; i < L2_COUNT; i++) stage_regs_ff[i] <= '0;
                end else if (enable_i) begin
                    for (int i = 0; i < L2_COUNT; i++) stage_regs_ff[i] <= l2_wires[i];
                end
            end

            compress_tree #(
                .NUM_INPUTS(L2_COUNT),
                .BITS_W    (BITS_W),
                .LEVEL     (LEVEL + 1)
            ) u_next_tree_stage (
                .clk_i    (clk_i),
                .enable_i (enable_i),
                .reset_i  (reset_i),
                .inputs_i (stage_regs_ff),
                .outputs_o(outputs_o)
            );
        end
    end

endmodule