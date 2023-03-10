`include "cache.svh"

module DCache (
    input logic clk,
    input logic rstn,
    input logic [`ADDRESS_WIDTH]ad,
    input logic [`ADDRESS_WIDTH]pa,
    input dcache_state_t control_en,
    input logic [`DATA_WIDTH]store_data,

    input logic [`BLOCK_WIDTH]r_data,
    output logic [`BLOCK_WIDTH]re_dirty_data,
    output logic [`BLOCK_WIDTH]wb_dirty_data,
    output logic [`BLOCK_WIDTH]hit_wb_dirty_data,

    output logic [`DATA_WIDTH]load_data,
    
    input logic [`BLOCK_EN]wen,
    input logic select_way,
    input logic wlru_en_from_cache,
    output logic [`LLIT_WIDTH]rllit_to_cache,
    output logic rlru_to_cache,
    output logic re_rdirty_to_cache,
    output logic wb_rdirty_to_cache,
    output logic hit_wb_rdirty_to_cache,
    output logic hit,
    output logic [`TAG_WIDTH]wb_rtag_to_cache,
    output logic [`TAG_WIDTH]re_rtag_to_cache,
    input dcache_state_t dcache_cs,

    output logic re_rv_to_cache,
    output logic hit_wb_rv_to_cache,
    output logic wb_rv_to_cache
);
    logic [`INDEX_WIDTH]way_rad;
    logic [`INDEX_WIDTH]way_wad;
    logic [`INDEX_WIDTH]lru_rad;
    logic [`INDEX_WIDTH]lru_wad;

    logic [`DATA_WIDTH]way_rdata[`BLOCK][`WAY];
    logic [`DATA_WIDTH]way_wdata[`BLOCK][`WAY];
    logic [`TAG_WIDTH]way_rtag[`WAY];
    logic [`TAG_WIDTH]way_wtag[`WAY];
    logic way_rv[`WAY];
    logic way_wv[`WAY];
    logic way_rdirty[`WAY];
    logic way_wdirty[`WAY];
    logic [`LLIT_WIDTH]way_rllit[`WAY];
    logic [`LLIT_WIDTH]way_wllit[`WAY];
    logic rlru;
    logic wlru;
    logic real_rlru;

    logic [`BLOCK_EN]way_wen[`BLOCK][`WAY];
    logic way_wtag_en[`WAY];
    logic way_wv_en[`WAY];
    logic way_wdirty_en[`WAY];
    logic way_wllit_en[`WAY];
    logic wlru_en;

    logic [`WAY]way_hit;

    logic [`ADDRESS_WIDTH]reg_ad;
    logic reg_wlru;
    logic [`INDEX_WIDTH]reg_lru_rad;
    logic [`INDEX_WIDTH]reg_lru_wad;
    logic reg_wlru_en;
    integer i ;
    integer k ;
    genvar j ;

    always_ff @(posedge clk)begin
        reg_ad <= ad;
    end
    assign hit = |way_hit;
    assign hit_wb_dirty_data = (way_hit[1])? {{way_rdata[7][1]}, {way_rdata[6][1]}, {way_rdata[5][1]},
        {way_rdata[4][1]}, {way_rdata[3][1]}, {way_rdata[2][1]}, {way_rdata[1][1]}, {way_rdata[0][1]}} :
            {{way_rdata[7][0]}, {way_rdata[6][0]}, {way_rdata[5][0]}, {way_rdata[4][0]},
            {way_rdata[3][0]}, {way_rdata[2][0]}, {way_rdata[1][0]}, {way_rdata[0][0]}};
    assign wb_dirty_data = (reg_ad[0])? {{way_rdata[7][1]}, {way_rdata[6][1]}, {way_rdata[5][1]},
        {way_rdata[4][1]}, {way_rdata[3][1]}, {way_rdata[2][1]}, {way_rdata[1][1]}, {way_rdata[0][1]}} :
        {{way_rdata[7][0]}, {way_rdata[6][0]}, {way_rdata[5][0]}, {way_rdata[4][0]},
            {way_rdata[3][0]}, {way_rdata[2][0]}, {way_rdata[1][0]}, {way_rdata[0][0]}};
    assign re_dirty_data = (real_rlru)?{{way_rdata[7][0]}, {way_rdata[6][0]}, {way_rdata[5][0]},
        {way_rdata[4][0]}, {way_rdata[3][0]}, {way_rdata[2][0]}, {way_rdata[1][0]}, {way_rdata[0][0]}} :
        {{way_rdata[7][1]}, {way_rdata[6][1]}, {way_rdata[5][1]}, {way_rdata[4][1]},
            {way_rdata[3][1]}, {way_rdata[2][1]}, {way_rdata[1][1]}, {way_rdata[0][1]}};

    assign wb_rtag_to_cache = (dcache_cs == D_HIT_WRITE_V_DIRTY)? way_rtag[way_hit[1]] :  way_rtag[reg_ad[0]]; 
    assign re_rtag_to_cache = way_rtag[(~real_rlru)];

    assign way_rad = ad[`INDEX_PART];
    assign way_wad = ad[`INDEX_PART];
    assign lru_rad = ad[`INDEX_PART];
    assign lru_wad = pa[`INDEX_PART];
    
    assign wlru_en = wlru_en_from_cache; 
    assign rlru_to_cache = rlru;
    assign wlru = way_hit[1];
    generate
        for(j = 0; j < `WAY_NUM; j = j + 1)begin
            assign {{way_wdata[7][j]}, {way_wdata[6][j]}, {way_wdata[5][j]}, {way_wdata[4][j]}, 
                    {way_wdata[3][j]}, {way_wdata[2][j]}, {way_wdata[1][j]}, {way_wdata[0][j]}} = (control_en == D_WRITE)? r_data : {{8{store_data}}};
        end
    endgenerate

    generate
        for(j = 0; j < `WAY_NUM; j = j + 1)begin
            assign way_wtag[j] = (control_en == D_WRITE)? ad[`TAG_PART] : `CLEAR_TAG;
        end
    endgenerate

    generate
        for(j = 0; j < `WAY_NUM; j = j + 1)begin
           assign way_wv[j] = (control_en == D_WRITE || control_en == D_REQ_STORE_LOAD_BLOCK)? `SET_V : `CLEAR_V;
        end
    endgenerate

    generate 
        for(j = 0; j < `WAY_NUM; j = j + 1)begin
           assign way_wdirty[j] = (control_en == D_WRITE)? `CLEAR_DIRTY : `SET_DIRTY;
        end
    endgenerate

    generate
        for(j = 0; j < `WAY_NUM; j = j + 1)begin
            always_comb begin
                unique case(ad[4:2])
                    3'b000: way_wllit[j] = 8'b0000_0001;
                    3'b001: way_wllit[j] = 8'b0000_0010;
                    3'b010: way_wllit[j] = 8'b0000_0100;
                    3'b011: way_wllit[j] = 8'b0000_1000;
                    3'b100: way_wllit[j] = 8'b0001_0000;
                    3'b101: way_wllit[j] = 8'b0010_0000;
                    3'b110: way_wllit[j] = 8'b0100_0000;
                    3'b111: way_wllit[j] = 8'b1000_0000; 
                endcase  
            end
        end
    endgenerate 

    
    always_comb begin
        if((reg_lru_rad == reg_lru_wad) && (reg_wlru_en))begin
            real_rlru = reg_wlru;
        end
        else begin
            real_rlru = rlru;
        end
    end

    always_ff @(posedge clk)begin
        reg_wlru_en <= wlru_en;
    end

    always_ff @(posedge clk)begin
        reg_lru_wad <= lru_wad;
    end

    always_ff @(posedge clk)begin
        reg_lru_rad <= lru_rad;
    end

    always_ff @(posedge clk)begin
        reg_wlru <= wlru;
    end
    always_comb begin
        unique case(control_en)
            D_LOAD: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wv_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                end
            end
            D_WRITE_TAG: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wllit_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                end
                if(ad[0])begin
                    way_wtag_en[0] = `UNABLE;
                    way_wtag_en[1] = `ENABLE;
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                end
                else begin
                    way_wtag_en[0] = `ENABLE;
                    way_wtag_en[1] = `UNABLE;
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                end
            end
            D_INDEX_WRITE_V: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                end
                if(ad[0])begin
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                end
                else begin
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                end
            end
            D_HIT_WRITE_V: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                end
                if(way_hit[1])begin
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                end
                else begin
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                end
            end
            D_HIT_WRITE_V_DIRTY: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                end
                if(way_hit[1])begin
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                end
                else begin
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                end
            end
            D_CLEAR_LLIT: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wv_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `ENABLE;
                end
            end
            D_SET_LLIT: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wv_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                end
                if(way_hit[1])begin
                    way_wllit_en[0] = `UNABLE;
                    way_wllit_en[1] = `ENABLE; 
                end
                else begin
                    way_wllit_en[0] = `ENABLE;
                    way_wllit_en[1] = `UNABLE;
                end
            end
            D_STORE: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    way_wtag_en[i] = `UNABLE;
                    way_wv_en[i] = `UNABLE;
                end
                if(way_hit[1])begin
                    way_wdirty_en[0] = `UNABLE;
                    way_wdirty_en[1] = `ENABLE;
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][0] = `DATA_WRITE_UNABLE;
                    end
                    unique case(ad[4:2])
                        3'b000: begin 
                            way_wen[0][1] = wen;
                            for(k = 1; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b001: begin
                            way_wen[0][1] = `DATA_WRITE_UNABLE;
                            way_wen[1][1] = wen;
                            for(k = 2; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b010: begin
                            way_wen[0][1] = `DATA_WRITE_UNABLE;
                            way_wen[1][1] = `DATA_WRITE_UNABLE;
                            way_wen[2][1] = wen;
                            for(k = 3; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE; 
                            end
                        end
                        3'b011: begin
                            for(k = 0; k < 3; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[3][1] = wen;
                            for(k = 4; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b100: begin
                            for(k = 0; k < 4; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[4][1] = wen;
                            for(k = 5; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b101: begin
                            for(k = 0; k < 5; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[5][1] = wen;
                            way_wen[6][1] = `DATA_WRITE_UNABLE;
                            way_wen[7][1] = `DATA_WRITE_UNABLE;
                        end
                        3'b110:begin
                            for(k = 0; k < 6; k = k + 1)begin
                               way_wen[k][1] = `DATA_WRITE_UNABLE; 
                            end
                            way_wen[6][1] = wen;
                            way_wen[7][1] = `DATA_WRITE_UNABLE;
                        end
                        3'b111: begin
                            for(k = 0; k < 7; k = k + 1)begin
                                way_wen[k][1] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[7][1] = wen;
                        end
                    endcase
                    if(wen == `DATA_WRITE_ENABLE)begin
                        way_wllit_en[1] = `ENABLE;
                    end
                    else begin
                        way_wllit_en[1] = `UNABLE;
                    end
                    way_wllit_en[0] = `ENABLE;
                end
                else begin
                    way_wdirty_en[0] = `ENABLE;
                    way_wdirty_en[1] = `UNABLE;
                    //way_wen[0] = wen;
                    unique case(ad[4:2])
                        3'b000: begin 
                            way_wen[0][0] = wen;
                            for(k = 1; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b001: begin
                            way_wen[0][0] = `DATA_WRITE_UNABLE;
                            way_wen[1][0] = wen;
                            for(k = 2; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b010: begin
                            way_wen[0][0] = `DATA_WRITE_UNABLE;
                            way_wen[1][0] = `DATA_WRITE_UNABLE;
                            way_wen[2][0] = wen;
                            for(k = 3; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE; 
                            end
                        end
                        3'b011: begin
                            for(k = 0; k < 3; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[3][0] = wen;
                            for(k = 4; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b100: begin
                            for(k = 0; k < 4; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[4][0] = wen;
                            for(k = 5; k < `BLOCK_NUM; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                        end
                        3'b101: begin
                            for(k = 0; k < 5; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[5][0] = wen;
                            way_wen[6][0] = `DATA_WRITE_UNABLE;
                            way_wen[7][0] = `DATA_WRITE_UNABLE;
                        end
                        3'b110:begin
                            for(k = 0; k < 6; k = k + 1)begin
                               way_wen[k][0] = `DATA_WRITE_UNABLE; 
                            end
                            way_wen[6][0] = wen;
                            way_wen[7][0] = `DATA_WRITE_UNABLE;
                        end
                        3'b111: begin
                            for(k = 0; k < 7; k = k + 1)begin
                                way_wen[k][0] = `DATA_WRITE_UNABLE;
                            end
                            way_wen[7][0] = wen;
                        end
                    endcase
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][1] = `DATA_WRITE_UNABLE;
                    end
                    if(wen == `DATA_WRITE_ENABLE)begin
                        way_wllit_en[0] = `ENABLE;
                    end
                    else begin
                        way_wllit_en[0] = `UNABLE;
                    end
                    way_wllit_en[1] = `UNABLE; 
                end
            end
            D_WRITE: begin
                if(select_way)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][0] = `DATA_WRITE_UNABLE;
                    end
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][1] = `DATA_WRITE_ENABLE;
                    end
                    way_wtag_en[0] = `UNABLE;
                    way_wtag_en[1] = `ENABLE;
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                    way_wdirty_en[0] = `UNABLE;
                    way_wdirty_en[1] = `ENABLE;
                    way_wllit_en[0] = `UNABLE;
                    way_wllit_en[1] = `ENABLE;
                end
                else begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][0] = `DATA_WRITE_ENABLE;
                    end
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][1] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[0] = `ENABLE;
                    way_wtag_en[1] = `UNABLE;
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                    way_wdirty_en[0] = `ENABLE;
                    way_wdirty_en[1] = `UNABLE;
                    way_wllit_en[0] = `ENABLE;
                    way_wllit_en[1] = `UNABLE;
                end
            end
            D_REQ_STORE_LOAD_BLOCK: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                end
                if(real_rlru)begin
                    way_wv_en[0] = `ENABLE;
                    way_wv_en[1] = `UNABLE;
                end
                else begin
                    way_wv_en[0] = `UNABLE;
                    way_wv_en[1] = `ENABLE;
                end
            end
            default: begin
                for(i = 0; i < `WAY_NUM; i = i + 1)begin
                    for(k = 0; k < `BLOCK_NUM; k = k + 1)begin
                        way_wen[k][i] = `DATA_WRITE_UNABLE;
                    end
                    way_wtag_en[i] = `UNABLE;
                    way_wv_en[i] = `UNABLE;
                    way_wdirty_en[i] = `UNABLE;
                    way_wllit_en[i] = `UNABLE;
                end
            end
        endcase
    end

    integer l;
    always_comb begin
        for(l = 0; l < `WAY_NUM; l = l + 1)begin
            if((way_rtag[l] == pa[`TAG_PART]) && (way_rv[l]))begin
                way_hit[l] = `HIT;
            end
            else begin
                way_hit[l] = `MISS;
            end
        end
    end

    // always_comb begin
    //     if(way_hit[0])begin
    //         rdirty_to_cache = way_rdirty[0];
    //     end
    //     else begin
    //         rdirty_to_cache = way_rdirty[1];
    //     end
    // end
    assign re_rdirty_to_cache = way_rdirty[~real_rlru];
    assign wb_rdirty_to_cache = way_rdirty[reg_ad[0]];
    assign hit_wb_rdirty_to_cache = way_rdirty[way_hit[1]];

    assign re_rv_to_cache = way_rv[~real_rlru];
    assign wb_rv_to_cache = way_rv[reg_ad[0]];
    assign hit_wb_rv_to_cache = way_rdirty[way_hit[1]];


    always_comb begin
        if(way_hit[0])begin
            rllit_to_cache = way_rllit[0];
        end
        else begin
            rllit_to_cache = way_rllit[1];
        end
    end

    always_comb begin
        unique case(way_hit)
            2'b01: begin
                load_data = way_rdata[pa[`OFFSET_PART]][0];
            end 
            2'b10: begin
                load_data = way_rdata[pa[`OFFSET_PART]][1];
            end
            default: begin
                load_data = way_rdata[0][0];
            end
        endcase
    end

generate
    for(j = 0; j < `BLOCK_NUM; j = j + 1)begin: bram_data_0
        data way0_data(.addra(way_wad), .clka(clk), .dina(way_wdata[j][0]), .ena(|way_wen[j][0]), .wea(way_wen[j][0]), 
                        .addrb(way_rad), .clkb(clk), .doutb(way_rdata[j][0]));
    end
endgenerate

generate
    for(j = 0; j < `BLOCK_NUM; j = j + 1)begin: bram_data_1
        data way0_data(.addra(way_wad), .clka(clk), .dina(way_wdata[j][1]), .ena(|way_wen[j][1]), .wea(way_wen[j][1]), 
                        .addrb(way_rad), .clkb(clk), .doutb(way_rdata[j][1]));
    end
endgenerate

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin: bram_v
        vl way_vl(.addra(way_wad), .clka(clk), .dina(way_wv[j]), .ena(way_wv_en[j]), .wea(way_wv_en[j]), 
                        .addrb(way_rad), .clkb(clk), .doutb(way_rv[j]));
    end
endgenerate

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin: bram_dirty
        vl way_dirty(.addra(way_wad), .clka(clk), .dina(way_wdirty[j]), .ena(way_wdirty_en[j]), .wea(way_wdirty_en[j]), 
                        .addrb(way_rad), .clkb(clk), .doutb(way_rdirty[j]));
    end
endgenerate

vl lru(.addra(lru_wad), .clka(clk), .dina(wlru), .ena(wlru_en), .wea(wlru_en), 
                        .addrb(lru_rad), .clkb(clk), .doutb(rlru));


generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin: bram_llit
        llit way_llit(.addra(way_wad), .clka(clk), .dina(way_wllit[j]), .ena(way_wllit_en[j]), .wea(way_wllit_en[j]), 
                        .addrb(way_rad), .clkb(clk), .doutb(way_rllit[j]));
    end
endgenerate

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin: tag 
        tag way_tag(.addra(way_wad), .clka(clk), .dina(way_wtag[j]), .ena(way_wtag_en[j]), .wea(way_wtag_en[j]),
                        .addrb(way_rad), .clkb(clk), .doutb(way_rtag[j]));
    end
endgenerate


endmodule