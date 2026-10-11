package poly_filter_pkg;

    localparam int mult_latancy = 21;
    localparam int P = 3; 
    localparam int TAPS_PER_PHASE = 16; 
    
    function automatic int bits_phase(input int taps_per_phase);
        return ((32 + $clog2(taps_per_phase) + 7) / 8) * 8;
    endfunction

    function automatic int bits_sum(input int taps_per_phase, input int p);
        return ((32 + $clog2(taps_per_phase*p) + 7) / 8) * 8;
    endfunction
    
    function automatic int delay_adder(input int bw);
        return (bw/8+2);
    endfunction
    
    function automatic int delay_adder_three(input int num_inputs, input int bw);
        // $clog2(num_inputs)*delay_adder(bw);
        return $clog2((num_inputs+3)/4)/2+(num_inputs==1 ? 2 : poly_filter_pkg::delay_adder(bw)+1); 
    endfunction
    
    // reset -> order_sel = 0 
    function automatic int delay(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        
        int serdes_in = 1;
        int phase = mult_latancy + delay_adder_three(taps_per_phase,bw)+1;
        int poly_phase = delay_adder_three(p,bw);
        
        return serdes_in+phase+poly_phase+1;
    endfunction
    
    
    // reset -> order_sel = 1 
    function automatic int delay_halfN(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        
        int serdes_in = 1;
        int phase = (mult_latancy + delay_adder_three(taps_per_phase,bw)+2)*2;
        int poly_phase = delay_adder_three(p,bw);
        
        return serdes_in+phase+poly_phase;
    endfunction
    
    // order_sel = 0  -> order_sel = 1
    function automatic int delay_after(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        int phase = (mult_latancy + delay_adder_three(taps_per_phase,bw));
        int poly_phase = delay_adder_three(p,bw);
        return poly_phase+(P==1 ? 1 : 0);
    endfunction
    // order_sel = 1  -> order_sel = 0 
    function automatic int delay_after_after(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        int phase = (mult_latancy + delay_adder_three(taps_per_phase,bw));
        int poly_phase = delay_adder_three(p,bw);
        return phase+taps_per_phase-2;
    endfunction
    // order_sel = 0  -> order_sel = 1 
    function automatic int delay_after_after_halfN(input int taps_per_phase, input int p);
        int bw = bits_sum(taps_per_phase,p);
        int phase = (mult_latancy + delay_adder_three(taps_per_phase,bw));
        int poly_phase = delay_adder_three(p,bw);
        return 2*(phase)+taps_per_phase/2;
    endfunction


  
    function automatic int delay_bw(input int taps_per_phase, input int p);
        return $clog2(delay_after_after_halfN(taps_per_phase,p))+2; // Чтобы счётчик при реконфигаруации фильтра не переполнился прибвавил +2 а не +1
    endfunction
endpackage