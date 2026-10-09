

module valid_fsm
#(
    parameter int P = 2,
    parameter int TAPS_PER_PHASE = 2
)(
    input logic clk_i,
    input logic reset_i,
    input logic enable_i,
    input logic clk_P,
    input logic clk_2P,
    input logic pre_clk_P,
    input logic order_sel_i,
    output logic valid_o
    );
    localparam int DELAY = poly_filter_pkg::delay(TAPS_PER_PHASE,P);
    localparam int DELAY_HALF_N = poly_filter_pkg::delay_halfN(TAPS_PER_PHASE,P);
    localparam int DELAY_BW = poly_filter_pkg::delay_bw(TAPS_PER_PHASE,P);
    localparam int DELAY_AFTER = poly_filter_pkg::delay_after(TAPS_PER_PHASE,P);
    localparam int DELAY_AFTER_AFTER = poly_filter_pkg::delay_after_after(TAPS_PER_PHASE,P);
    localparam int DELAY_AFTER_AFTER_HALF_N = poly_filter_pkg::delay_after_after_halfN(TAPS_PER_PHASE,P);
    
    logic signed [DELAY_BW-1:0] valid_counter; // main counter (true, when == 0)
    logic signed [DELAY_BW-1:0] valid_counter_two; // second counter (thue, when <0)
    logic signed [DELAY_BW-1:0] debug_counter_two;
    logic prevalid;
    logic prevalid2;
    logic prevalid3;
    logic prevalid_two;
    logic flag;
    logic flag_two;
    
    logic diff_o;
    logic sign_o;
    
    logic debug;
    logic reconf;
    logic bad_reconf;
    logic reset_after;
    
    assign debug = valid_counter_two==0 && diff_o && (~sign_o);
    
    
    assign flag = valid_counter==0;
    assign flag_two = valid_counter_two<0 | (P==1 ? diff_o : 0);
    
    
     always_ff @(posedge clk_i) begin // main valid_counter
        if(reset_i) begin
            valid_counter<=1;
        end else if(clk_P) begin 
            if(valid_counter==1) begin
                valid_counter<=(order_sel_i ? -DELAY_HALF_N+1 : -DELAY+1);
            end else if(valid_counter<0) begin
                if(diff_o) begin 
                    valid_counter<=(P==1 ? 1 : 0)+(order_sel_i ? -DELAY_AFTER_AFTER_HALF_N : -DELAY_AFTER_AFTER)-DELAY_AFTER-(clk_2P == 1 ? 1 : 0)-1;
                end else begin
                    valid_counter<=valid_counter+1;
                end
            end else if(flag_two) begin
                    valid_counter<=2;
            end else if(valid_counter==2) begin
                valid_counter<=(order_sel_i ? -DELAY_AFTER_AFTER_HALF_N : -DELAY_AFTER_AFTER);
            end
        end
    end
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
             reset_after<=1;
        end else if(prevalid) begin
            reset_after<=0;
        end
    end

     always_ff @(posedge clk_i) begin // second valid_counter
        if(reset_i) begin
            valid_counter_two<=0;
        end else if(clk_P) begin 
            if(valid_counter_two==0 && diff_o) begin
                if(sign_o) begin
                    valid_counter_two<=-DELAY_AFTER - (clk_2P == 1 ? 1 : 0) + (P == 1 ? 1 : 0);
                end else begin
                    valid_counter_two<=-DELAY_AFTER - (clk_2P == 1 ? 1 : 0) + (P == 1 ? 1 : 0);
                end
            end else if(valid_counter_two<0) begin
             valid_counter_two<=valid_counter_two+1;
            end
        end
    end
    
    
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            reconf<='0;
        end else if(clk_P) begin
            //if(valid_counter_two<0 && P!=1) begin
            if(valid_counter_two==0 && diff_o) begin
                reconf<='1;
            end else if(valid_counter==0 && valid_counter_two==0 && valid_o) begin
                reconf<='0;
            end
        end
    end
    
    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            bad_reconf<='0;
        end else if (clk_P) begin
            if(reconf & diff_o) bad_reconf<='1;
            else if(valid_counter==-1) bad_reconf<='0;
        end
    end
    
    diff_detect diff_detector(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .enable_i(pre_clk_P), 
        .signal_i(order_sel_i),
        .diff_o(diff_o),
        .sign_o(sign_o) // = 0 => signal _|-, = 1 => signal -|_
    );
    
    delay #(
    .D(P == 1 ? 0 : 1),
    .W(1)
    )u_delay(
          .reset_i(reset_i),
          .clk_i(clk_i),
          .enable_i(clk_P),
          .signal_i(flag),
          .signal_o(prevalid)
    );
    
    delay #(
    .D(2),
    .W(1)
    )u2_delay(
          .reset_i(reset_i|(prevalid_two)),
          .clk_i(clk_i),
          .enable_i(enable_i),
          .signal_i(prevalid),
          .signal_o(prevalid2)
    );

    delay #(
    .D(P == 1 ? 1 : 1),
    .W(1)
    )u3_delay(
          .reset_i(reset_i),
          .clk_i(clk_i),
          .enable_i(enable_i),
          .signal_i(flag_two),
          .signal_o(prevalid_two)
    );

        delay #(
    .D(1+(P==1)),
    .W(1)
    )u4_delay(
          .reset_i(reset_i|(prevalid_two)),
          .clk_i(clk_i),
          .enable_i(enable_i),
          .signal_i(prevalid&(reconf | P==1)),
          .signal_o(prevalid3)
    );

    assign valid_o = enable_i & (prevalid2 | prevalid_two | prevalid3) & ~reset_after & ~bad_reconf;
endmodule
