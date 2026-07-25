module adder8(
    input logic signed [7:0] a_i,
    input logic signed [7:0] b_i,
    input logic c_i,
    output logic signed [7:0] s_o,
    output logic c_o
    );
    
    logic [7:0] g0, p0; // Этап 0: Одиночные биты
    logic [7:0] g1, p1; // Этап 1: Сдвиг на 1 позицию
    logic [7:0] g2, p2; // Этап 2: Сдвиг на 2 позиции
    logic [7:0] g3, p3; // Этап 3: Сдвиг на 4 позиции
    logic [8:0] c;      // Полные переносы для каждого разряда


    assign g0 = a_i & b_i;
    assign p0 = a_i ^ b_i;


    always_comb begin
        g1[0] = g0[0];
        p1[0] = p0[0];
        
        for (int i = 1; i < 8; i++) begin
            g1[i] = g0[i] | (p0[i] & g0[i-1]);
            p1[i] = p0[i] & p0[i-1];
        end
    end

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            g2[i] = g1[i];
            p2[i] = p1[i];
        end        
        for (int i = 2; i < 8; i++) begin
            g2[i] = g1[i] | (p1[i] & g1[i-2]);
            p2[i] = p1[i] & p1[i-2];
        end
    end

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            g3[i] = g2[i];
            p3[i] = p2[i];
        end      
        for (int i = 4; i < 8; i++) begin
            g3[i] = g2[i] | (p2[i] & g2[i-4]);
            p3[i] = p2[i] & p2[i-4];
        end
    end


    always_comb begin
        c[0] = c_i;
        for (int i = 0; i < 8; i++) begin
            c[i+1] = g3[i] | (p3[i] & c[0]);
        end
        for (int i = 0; i < 8; i++) begin
            s_o[i] = p0[i] ^ c[i];
        end
        c_o = c[8];
    end

endmodule