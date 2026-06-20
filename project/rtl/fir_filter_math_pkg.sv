package fir_filter_math_pkg;
// Это нужно, чтобы использовать переменные из файла fir_filter_params_pkg.sv



    function automatic longint min_long(input longint a, input longint b);
        begin
            if (a < b)
                return a;
            else
                return b;
        end
    endfunction

    function automatic longint max_long(input longint a, input longint b);
        begin
            if (a > b)
                return a;
            else
                return b;
        end
    endfunction

    function automatic int bit_width_value(input longint val); 
    // Вариант оформления. Тут возвращаем через return как в С++
    // Тут мы вычисляем битность числа
        int result = 1;
        if(val == 0) return 1; 
    
        if(val < 0) return bit_width_value(-val-1);
    
        while (val > 0) begin
            result = result + 1;
            val = val/2;
        end
        return result; 
    endfunction

    function automatic int bit_width(input longint min_val, input longint max_val);
    // Тут мы вычисляем битность диапазона
        int w_min;
        int w_max;
        int w;
        begin
            w_min = bit_width_value(min_val);
            w_max = bit_width_value(max_val);

            if (w_min > w_max)
                w = w_min;
            else
                w = w_max;
        end
        return w;
    endfunction

    function automatic int tree_len(input int COEFF_NUM, input int TREE_STEP);
        int a = COEFF_NUM; 
        int len = 1;
        while(a > 1) begin
            len = len + 1;
            a = (a + TREE_STEP - 1) / TREE_STEP;
        end
        return len;
    endfunction




    

endpackage