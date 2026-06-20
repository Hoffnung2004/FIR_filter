

package fir_filter_params_pkg;

    import fir_filter_math_pkg::*;

    localparam int SIGNAL_WIDTH = 16;
    localparam int COEFF_WIDTH  = 16;
    localparam int COEFF_NUM    = 32;
    localparam int TREE_STEP    =  2; // По умолчанию
    
        
        localparam logic signed [COEFF_WIDTH-1:0] COEFFS [0:COEFF_NUM-1] = '{
     // сюда коэффициенты
     183,    280,   56,   -481,
    -946,   -572,   801,   2279,
     2107,  -632,  -4584, -6059,
    -1439,   9753,  23395, 32767,
     32767,  23395, 9753, -1439,
    -6059,  -4584, -632,   2107,
     2279,   801,  -572,  -946,
    -481,    56,    280,   183
    };

    
    localparam int TREE_LEN = tree_len(COEFF_NUM,TREE_STEP);
    typedef int tree_width_array_t [0:TREE_LEN-1]; // Временный тип данных
    typedef int tran_width_array_t [0:COEFF_NUM-1]; // Временный тип данных
    typedef int tree_width_bit_array_t [0:TREE_LEN-1][0:COEFF_NUM-1]; // Временный тип данных
    
    
    
    function automatic tree_width_array_t tree_width();
        int len_tmp=TREE_LEN;
        tree_width_array_t width;
        width[0]=COEFF_NUM;
    
        for(int i=1; i<TREE_LEN; i++) begin
            width[i] = (width[i-1]+TREE_STEP-1)/TREE_STEP;
        end
        return width;
    endfunction
    
    localparam int TREE_WIDTH [0:TREE_LEN-1] = tree_width();
    
    function automatic tree_width_bit_array_t bit_width_tree();
        int tree [0:TREE_LEN-1][0:COEFF_NUM-1];
        longint minn [0:TREE_LEN-1][0:COEFF_NUM-1]; // Возможно стоит взять больщую битность для общего случая
        longint maxx [0:TREE_LEN-1][0:COEFF_NUM-1]; // Возможно стоит взять больщую битность для общего случая
    
        longint maxch =  (64'sd1 <<< (SIGNAL_WIDTH-1)) - 1;
        longint minch = -(64'sd1 <<< (SIGNAL_WIDTH-1));
    
        for(int j=0; j<TREE_WIDTH[0]; j++) begin
            minn[0][j]=min_long(minch*COEFFS[j],maxch*COEFFS[j]);
            maxx[0][j]=max_long(minch*COEFFS[j],maxch*COEFFS[j]);
            tree[0][j]=bit_width(minn[0][j],maxx[0][j]);
        end
    
        for(int i = 1; i < TREE_LEN; i++) begin
            for(int j = 0; j<TREE_WIDTH[i]; j++) begin
                minn[i][j]=0;
                maxx[i][j]=0;
                for(int k = 0; k < TREE_STEP && j*TREE_STEP+k<TREE_WIDTH[i-1]; k++) begin
                    minn[i][j]=minn[i][j]+minn[i-1][j*TREE_STEP+k];
                    maxx[i][j]=maxx[i][j]+maxx[i-1][j*TREE_STEP+k];
                end
                tree[i][j]=bit_width(minn[i][j],maxx[i][j]);
            end
        end
        return tree;
    endfunction

    localparam int TREE_BIT_WIDTH [0:TREE_LEN-1][0:COEFF_NUM-1] = bit_width_tree();
    
    
    //===================================
    // теперь транспоинрованная структура
    //===================================
    
    
    function automatic tran_width_array_t bit_width_tran();
        int tree [0:COEFF_NUM-1];
        longint minn; // Возможно стоит взять больщую битность для общего случая
        longint maxx; // Возможно стоит взять больщую битность для общего случая
        longint minn_prev; // Возможно стоит взять больщую битность для общего случая
        longint maxx_prev; // Возможно стоит взять больщую битность для общего случая
    
        longint maxch =  (64'sd1 <<< (SIGNAL_WIDTH-1)) - 1;
        longint minch = -(64'sd1 <<< (SIGNAL_WIDTH-1));
    
        minn=min_long(minch*COEFFS[COEFF_NUM-1],maxch*COEFFS[COEFF_NUM-1]);
        maxx=max_long(minch*COEFFS[COEFF_NUM-1],maxch*COEFFS[COEFF_NUM-1]);
        tree[0]=bit_width(minn,maxx);
        
        for(int j=1; j<COEFF_NUM; j++) begin
            minn_prev = minn;
            maxx_prev = maxx;
            
            minn=min_long(minch*COEFFS[COEFF_NUM-1-j],maxch*COEFFS[COEFF_NUM-1-j])+minn_prev;
            maxx=max_long(minch*COEFFS[COEFF_NUM-1-j],maxch*COEFFS[COEFF_NUM-1-j])+maxx_prev;
            tree[j]=bit_width(minn,maxx);
        end
    

        return tree;
    endfunction
    
    function automatic tran_width_array_t reverse_taps_array();
        tran_width_array_t array_out;
        for(int i=0; i<COEFF_NUM; i++)
            array_out[COEFF_NUM-1-i]=TREE_BIT_WIDTH[0][i];
        return array_out;
    endfunction
    
    localparam int MUL_WIDTH [0:COEFF_NUM-1] = reverse_taps_array();
    localparam int TRAN_WIDTH [0:COEFF_NUM-1] = bit_width_tran();
    
    
     
endpackage