`timescale 1ns / 1ps
`include "cache.svh"

module ICache(
    input logic clk,
    input logic rstn,

    input logic [`ADDRESS_WIDTH]pa,
    input logic [`ADDRESS_WIDTH]ad,
    input logic [`ICACHE_STATE_WIDTH]control_en, 

    input logic wlru_en_from_cache,
    input logic select_way,
    output logic rlru_to_cache,

    input logic [`BLOCK_WIDTH]r_data,
    output logic [`DATA_WIDTH]ins,
    output logic hit
);
logic [`INDEX_WIDTH]way_rad;
logic [`INDEX_WIDTH]way_wad;
logic [`INDEX_WIDTH]lru_rad;
logic [`INDEX_WIDTH]lru_wad;

logic [`DATA_WIDTH]way_rdata[`BLOCK][`WAY];
logic [`DATA_WIDTH]way_wdata[`BLOCK][`WAY];
logic [`TAG_WIDTH]way_rtag[`WAY];
logic [`TAG_WIDTH]way_wtag[`WAY];
logic way_wv[`WAY];
logic way_rv[`WAY];
logic wlru;
logic rlru;

logic [`BLOCK_EN]way_wen[`WAY];
logic way_wtag_en[`WAY];
logic way_wv_en[`WAY];
logic wlru_en;

logic [`WAY]way_hit;

integer i;
genvar j;
assign way_rad = ad[`INDEX_PART];
assign way_wad = ad[`INDEX_PART];

assign hit = |way_hit;

assign lru_wad = pa[`INDEX_PART];
assign lru_rad = ad[`INDEX_PART];
assign wlru_en = wlru_en_from_cache;
assign rlru_to_cache = rlru;
assign wlru = way_hit[1];       //lru部分不适用于拓展，目前的设计只能在way

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin
        assign way_wtag[j] = (control_en == `I_WRITE)? ad[`TAG_PART] : `CLEAR_TAG;
    end
endgenerate

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin
     //  assign way_wv[j] = (control_en == `I_WRITE) ? `SET_V : `CLEAR_V;
        always_comb begin
            if(control_en == `I_WRITE)begin
                way_wv[j] = `SET_V;
            end
            else begin
                way_wv[j] = `CLEAR_V;
            end
        end
    end
endgenerate

generate
    for(j = 0; j < `WAY_NUM; j = j + 1)begin
        assign {{way_wdata[7][j]}, {way_wdata[6][j]}, {way_wdata[5][j]}, {way_wdata[4][j]},
            {way_wdata[3][j]}, {way_wdata[2][j]}, {way_wdata[1][j]}, {way_wdata[0][j]} } = r_data;
    end
endgenerate

always_comb begin                         
    unique case(control_en)
        `I_LOAD: begin
            for(i = 0; i < `WAY_NUM; i = i + 1)begin
                way_wen[i] = `DATA_WRITE_UNABLE; 
                way_wtag_en[i] = `UNABLE;
                way_wv_en[i] = `UNABLE;
            end
        end
        `I_WRITE_TAG: begin
            for(i = 0; i < `WAY_NUM; i = i + 1)begin
                way_wen[i] = `DATA_WRITE_UNABLE;
                way_wv_en[i] = `UNABLE;      
            end
            if(ad[0])begin
                way_wtag_en[0] = `UNABLE;
                way_wtag_en[1] = `ENABLE;
            end
            else begin
                way_wtag_en[0] = `ENABLE;
                way_wtag_en[1] = `UNABLE;
            end 
        end
        `I_WRITE_V: begin
            for(i = 0; i < `WAY_NUM; i = i + 1)begin
                way_wen[i] = `DATA_WRITE_UNABLE;
                way_wtag_en[i] = `UNABLE;
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
        `I_WRITE: begin
            if(select_way)begin
                way_wen[0] = `DATA_WRITE_UNABLE;
                way_wtag_en[0] = `UNABLE;
                way_wv_en[0] = `UNABLE;
                way_wen[1] = `DATA_WRITE_ENABLE;
                way_wtag_en[1] = `ENABLE;
                way_wv_en[1] = `ENABLE;
            end
            else begin
                way_wen[0] = `DATA_WRITE_ENABLE;
                way_wtag_en[0] = `ENABLE;
                way_wv_en[0] = `ENABLE;
                way_wen[1] = `DATA_WRITE_UNABLE;
                way_wtag_en[1] = `UNABLE;
                way_wv_en[1] = `UNABLE;  
            end
        end
        default: begin
            for(i = 0; i < `WAY_NUM; i = i + 1)begin
                way_wen[i] = `DATA_WRITE_UNABLE;
                way_wtag_en[i] = `UNABLE;
                way_wv_en[i] = `ENABLE;
            end
        end
    endcase
end

always_comb begin
    for(i = 0; i < `WAY_NUM; i = i + 1)begin
        if((way_rtag[i] == pa[`TAG_PART]) && (way_rv[i]))begin
            way_hit[i] = `HIT;
        end
        else begin
            way_hit[i] = `MISS;
        end
    end
end 

//未能实现拓展，如要改多路，此处应改
always_comb begin
    unique case(way_hit)
        2'b01: begin
            ins = way_rdata[pa[`OFFSET_PART]][0];
        end
        2'b10: begin
            ins = way_rdata[pa[`OFFSET_PART]][1];
        end
        default: begin
            ins = way_rdata[0][0];
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


vl lru(.addra(lru_wad), .clka(clk), .dina(wlru), .ena(wlru_en), .wea(wlru_en), 
                        .addrb(lru_rad), .clkb(clk), .doutb(rlru));


endmodule

