module tb_params;

    import fir_filter_math_pkg::*;
    import fir_filter_params_pkg::*;

    initial begin
        $display("SIGNAL_WIDTH = %0d", SIGNAL_WIDTH);
        $display("COEFF_WIDTH  = %0d", COEFF_WIDTH);
        $display("COEFF_NUM    = %0d", COEFF_NUM);
        $display("TREE_STEP    = %0d", TREE_STEP);
        $display("TREE_LEN     = %0d", TREE_LEN);

        $display("");
        $display("TREE_WIDTH:");
        for (int i = 0; i < TREE_LEN; i++) begin
            $display("TREE_WIDTH[%0d] = %0d", i, TREE_WIDTH[i]);
        end

        $display("");
        $display("TREE_BIT_WIDTH:");
        for (int i = 0; i < TREE_LEN; i++) begin
            for (int j = 0; j < TREE_WIDTH[i]; j++) begin
                $write("%0d ", TREE_BIT_WIDTH[i][j]);
            end
            $write("\n");
        end

        $display("");
        $display("==== Function checks ====");

        $display("");
        $display("bit_width_value:");
        $display("bit_width_value(0)   = %0d", bit_width_value(0));
        $display("bit_width_value(1)   = %0d", bit_width_value(1));
        $display("bit_width_value(2)   = %0d", bit_width_value(2));
        $display("bit_width_value(3)   = %0d", bit_width_value(3));
        $display("bit_width_value(4)   = %0d", bit_width_value(4));
        $display("bit_width_value(7)   = %0d", bit_width_value(7));
        $display("bit_width_value(8)   = %0d", bit_width_value(8));
        $display("bit_width_value(15)  = %0d", bit_width_value(15));
        $display("bit_width_value(16)  = %0d", bit_width_value(16));
        $display("bit_width_value(-1)  = %0d", bit_width_value(-1));
        $display("bit_width_value(-2)  = %0d", bit_width_value(-2));
        $display("bit_width_value(-3)  = %0d", bit_width_value(-3));
        $display("bit_width_value(-4)  = %0d", bit_width_value(-4));
        $display("bit_width_value(-8)  = %0d", bit_width_value(-8));
        $display("bit_width_value(-9)  = %0d", bit_width_value(-9));
        $display("bit_width_value(-16) = %0d", bit_width_value(-16));
        $display("bit_width_value(-17) = %0d", bit_width_value(-17));

        $display("");
        $display("bit_width range:");
        $display("bit_width(-1, 0)    = %0d", bit_width(-1, 0));
        $display("bit_width(-2, 1)    = %0d", bit_width(-2, 1));
        $display("bit_width(-4, 3)    = %0d", bit_width(-4, 3));
        $display("bit_width(-8, 7)    = %0d", bit_width(-8, 7));
        $display("bit_width(-9, 7)    = %0d", bit_width(-9, 7));
        $display("bit_width(-100, 80) = %0d", bit_width(-100, 80));

        $display("");
        $display("min_long / max_long:");
        $display("min_long(10, -3) = %0d", min_long(10, -3));
        $display("max_long(10, -3) = %0d", max_long(10, -3));
        $display("min_long(-5, -9) = %0d", min_long(-5, -9));
        $display("max_long(-5, -9) = %0d", max_long(-5, -9));

        $display("");
        $display("tree_len:");
        $display("tree_len(32, 2) = %0d", tree_len(32, 2));
        $display("tree_len(31, 2) = %0d", tree_len(31, 2));
        $display("tree_len(16, 2) = %0d", tree_len(16, 2));
        $display("tree_len(10, 2) = %0d", tree_len(10, 2));
        $display("tree_len(32, 4) = %0d", tree_len(32, 4));


        $display("");
        $display("==== Automatic checks ====");

        if (bit_width_value(0)  != 1) $error("bit_width_value(0) failed");
        if (bit_width_value(1)  != 2) $error("bit_width_value(1) failed");
        if (bit_width_value(2)  != 3) $error("bit_width_value(2) failed");
        if (bit_width_value(3)  != 3) $error("bit_width_value(3) failed");
        if (bit_width_value(7)  != 4) $error("bit_width_value(7) failed");
        if (bit_width_value(8)  != 5) $error("bit_width_value(8) failed");

        if (bit_width_value(-1) != 1) $error("bit_width_value(-1) failed");
        if (bit_width_value(-2) != 2) $error("bit_width_value(-2) failed");
        if (bit_width_value(-8) != 4) $error("bit_width_value(-8) failed");
        if (bit_width_value(-9) != 5) $error("bit_width_value(-9) failed");

        if (bit_width(-8, 7) != 4) $error("bit_width(-8, 7) failed");
        if (bit_width(-9, 7) != 5) $error("bit_width(-9, 7) failed");

        if (tree_len(32, 2) != 6) $error("tree_len(32, 2) failed");
        if (tree_len(31, 2) != 6) $error("tree_len(31, 2) failed");
        if (tree_len(16, 2) != 5) $error("tree_len(16, 2) failed");


        $display("");
        $display("Package/function test finished");

        $display("");
        $display("MUL_WIDTH:");
        for (int i = 0; i < COEFF_NUM; i++) begin
            $write("%0d ", MUL_WIDTH[i]);
        end
        $write("\n");

        $display("");
        $display("TRAN_WIDTH:");
        for (int i = 0; i < COEFF_NUM; i++) begin
            $write("%0d ", TRAN_WIDTH[i]);
        end
        $write("\n");

        $display("");
        $display("==== Transposed checks ====");

        // Проверяем, что битность одного произведения после reverse совпала
        // MUL_WIDTH[0] должен соответствовать TREE_BIT_WIDTH[0][COEFF_NUM-1]
        if (MUL_WIDTH[0] != TREE_BIT_WIDTH[0][COEFF_NUM-1]) begin
            $error("MUL_WIDTH[0] mismatch: got %0d, expected %0d",
                MUL_WIDTH[0], TREE_BIT_WIDTH[0][COEFF_NUM-1]);
        end

        if (MUL_WIDTH[COEFF_NUM-1] != TREE_BIT_WIDTH[0][0]) begin
            $error("MUL_WIDTH[%0d] mismatch: got %0d, expected %0d",
                COEFF_NUM-1, MUL_WIDTH[COEFF_NUM-1], TREE_BIT_WIDTH[0][0]);
        end

        // Проверяем, что финальная битность транспонированной структуры
        // совпадает с финальной битностью дерева сумматоров
        if (TRAN_WIDTH[COEFF_NUM-1] != TREE_BIT_WIDTH[TREE_LEN-1][0]) begin
            $error("Final TRAN_WIDTH mismatch: got %0d, expected %0d",
                TRAN_WIDTH[COEFF_NUM-1], TREE_BIT_WIDTH[TREE_LEN-1][0]);
        end

        $display("Transposed structure checks finished");

        $finish;
    end

endmodule