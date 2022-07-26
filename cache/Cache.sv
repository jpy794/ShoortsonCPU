`timescale  1ns / 1ps
`include "cache.svh"

module Cache(
    input logic clk,
    input logic rstn,

    //icache
    input logic [`VA_WIDTH]ins_va,
    input logic [`PA_WIDTH]ins_pa,
    input logic [`ICACHE_OP_WIDTH]ins_op,
    input logic ins_stall,
    input logic ins_cached,
    output logic [`DATA_WIDTH]ins,
    output logic icache_ready,

    //dcache
    input logic [`VA_WIDTH]data_va,
    input logic [`PA_WIDTH]data_pa,
    input logic [`DCACHE_OP_WIDTH]data_op,
    input logic data_stall,
    input logic data_cached,
    input logic [`DATA_WIDTH]store_data,
    output logic [`DATA_WIDTH]load_data,
    output logic dcache_ready,

    //pipline axi
     output logic [`AXI_REQ_WIDTH]req_to_axi,
    output logic [`BLOCK_WIDTH]wblock_to_axi,
    output logic [`DATA_WIDTH]wword_to_axi,
    output logic [`AXI_STRB_WIDTH]wword_en_to_axi,
    output logic [`AXI_STRB_WIDTH]rword_en_to_axi,
    output logic [`ADDRESS_WIDTH]ad_to_axi,
    output logic cached_to_axi,

    input logic [`BLOCK_WIDTH]rblock_from_axi,
    input logic [`DATA_WIDTH]rword_from_axi,
    input logic ready_from_axi,
    input logic task_finish_from_axi   
   
);
logic [`DATA_WIDTH]rword_from_pipline;

//icache control
logic [`ADDRESS_WIDTH]pa_to_icache;
logic [`ADDRESS_WIDTH]ad_to_icache;

logic [`ICACHE_STATE_WIDTH]ins_control_en;
logic wlru_en_to_icache;
logic select_way_to_icache;
logic rlru_from_icache;
logic [`BLOCK_WIDTH]rdata_to_icache;
logic [`DATA_WIDTH]ins_from_icache;
logic hit_from_icache;


logic [`ICACHE_STATE_WIDTH]icache_next_state;
logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]icache_req_to_pipline;

logic [`ICACHE_OP_WIDTH]reg_ins_op;
logic reg_ins_stall;
logic reg_ins_cached;
logic [`VA_WIDTH]reg_ins_va;
logic [`PA_WIDTH]reg_ins_pa;
logic reg_rlru_from_icache;
logic [`RESPONSE_FROM_PIPLINE]response_from_pipline;



// assign rdata_to_icache = rblock_from_pipline;
assign pa_to_icache = {reg_ins_pa, reg_ins_va};
assign ad_to_icache = (reg_ins_stall)? {reg_ins_pa, reg_ins_pa} : {{20{1'b0}}, ins_va};
assign select_way_to_icache = reg_rlru_from_icache;
// assign wlru_en_to_icache = (reg_ins_op == `ICACHE_REQ_LOAD_INS && ~reg_ins_stall && reg_ins_cached && hit_from_icache) ? `ENABLE : `UNABLE;
// assign ins = (reg_ins_cached)? ins_from_icache : rword_from_pipline;
always_comb begin
    if((reg_ins_op == `ICACHE_REQ_LOAD_INS) && (~reg_ins_stall) && (reg_ins_cached) && (hit_from_icache))begin
        wlru_en_to_icache = `ENABLE;
    end
    else begin
        wlru_en_to_icache = `UNABLE;
    end
end

always_ff @(posedge clk)begin
    reg_ins_va <= ins_va;
end

always_ff @(posedge clk)begin
    reg_ins_pa <= ins_pa;
end

always_ff @(posedge clk)begin
    reg_ins_op <= ins_op;
end

always_ff @(posedge clk)begin
    reg_ins_stall <= ins_stall;
end

always_ff @(posedge clk)begin
    reg_rlru_from_icache <= rlru_from_icache;
end

always_comb begin
    if(~ins_stall)begin
        unique case(ins_op)
            `ICACHE_REQ_LOAD_INS: ins_control_en = `I_LOAD;
            `ICACHE_REQ_INITIALIZE: ins_control_en = `I_WRITE_TAG;
            `ICACHE_REQ_INDEX_INVALIDATA: ins_control_en = `I_WRITE_V;
            `ICACHE_REQ_HIT_INVALIDATA: ins_control_en = `I_LOAD;
            default: ins_control_en = icache_next_state;
        endcase
    end
    else begin
        ins_control_en = icache_next_state;
    end
end

always_ff @(posedge clk)begin
    if(!rstn)begin
        icache_next_state <= `I_NONE;
    end
    else begin
        if(~reg_ins_stall)begin
            unique case(reg_ins_op)
                `ICACHE_REQ_LOAD_INS: begin
                    if(reg_ins_cached)begin
                        if(hit_from_icache)begin
                            icache_next_state <= `I_NONE;
                        end
                        else begin
                            icache_next_state <= `I_REQ_BLOCK;
                        end
                    end
                    else begin
                        icache_next_state <= `I_REQ_WORD;
                    end
                end
                `ICACHE_REQ_HIT_INVALIDATA: begin
                    if((hit_from_icache) && (reg_ins_cached))begin
                        icache_next_state <= `I_WRITE_V;
                    end
                    else begin
                        icache_next_state <= `I_NONE;
                    end
                end
                default: begin
                    icache_next_state <= `I_NONE;   
                end
            endcase
        end
        else begin
            if((response_from_pipline == `FINISH_ICACHE_REQ) && (icache_next_state == `I_REQ_BLOCK))begin
                icache_next_state <= `I_WRITE;
            end
            else begin
                if(icache_next_state == `I_WRITE)begin
                    icache_next_state <= `I_LOAD;
                end
                else begin
                    icache_next_state <= `I_NONE;
                end
            end
        end
    end
end

always_ff @(posedge clk)begin
    unique case(icache_next_state)
        `I_REQ_BLOCK: begin
            icache_req_to_pipline <= `ICACHE_REQ_TO_PIPLINE_BLOCK;
        end
        `I_REQ_WORD: begin
            icache_req_to_pipline <= `ICACHE_REQ_TO_PIPLINE_WORD;
        end
        default: begin
            icache_req_to_pipline <= `ICACHE_REQ_TO_PIPLINE_NONE;
        end
    endcase
end

always_comb begin
    if(~reg_ins_stall)begin
        unique case(reg_ins_op)
            `ICACHE_REQ_LOAD_INS: begin
                if(reg_ins_cached)begin
                    if(hit_from_icache)begin
                        icache_ready = `READY;
                    end
                    else begin
                        icache_ready = `UNREADY;
                    end
                end
                else begin
                    icache_ready = `UNREADY;
                end
            end
            `ICACHE_REQ_HIT_INVALIDATA: begin
                if(hit_from_icache)begin
                    icache_ready = `UNREADY;
                end
                else begin
                    icache_ready = `READY;
                end
            end
            default: begin
                icache_ready = `READY;
            end
        endcase
    end
    else begin
        if(icache_next_state == `I_NONE)begin
            icache_ready = `READY;
        end
        else begin
            icache_ready = `UNREADY;
        end
    end
end


ICache icache(.clk(clk), .rstn(rstn), .pa(pa_to_icache), .ad(ad_to_icache),
                .control_en(ins_control_en), .wlru_en_from_cache(wlru_en_to_icache),
                .select_way(select_way_to_icache), .rlru_to_cache(rlru_from_icache),
                .r_data(rdata_to_icache), .ins(ins_from_icache), .hit(hit_from_icache));






//dcache control
logic [`ADDRESS_WIDTH]pa_to_dcache;
logic [`ADDRESS_WIDTH]ad_to_dcache;
logic [`DCACHE_STATE_WIDTH]dcache_control_en;
logic [`DATA_WIDTH]store_data_to_dcache;
logic [`BLOCK_WIDTH]rdata_to_dcache;
logic [`BLOCK_WIDTH]dirty_data_from_dcache;
logic [`DATA_WIDTH]load_data_from_dcache;
logic [`BLOCK_EN]wen_to_dcache;
logic select_way_to_dcache;
logic wlru_en_to_dcache;
logic [`LLIT_WIDTH]rllit_from_dcache;
logic rlru_from_dcache;
logic [`BLOCK]rdirty_from_dcache;
logic hit_from_dcache;

logic [`DCACHE_STATE_WIDTH]dcache_next_state;
logic [`DCACHE_REQ_TO_PIPLINE_WIDTH]dcache_req_to_pipline;
logic [`DCACHE_CNT_WIDTH]cnt;

logic reg_data_stall;
logic [`DCACHE_OP_WIDTH]reg_data_op;
logic reg_data_cached;
logic [`DCACHE_STATE_WIDTH]reg_dcache_next_state;
logic [`VA_WIDTH]reg_data_va;
logic [`PA_WIDTH]reg_data_pa;
logic reg_rlru_from_dcache;
logic [`DCACHE_STATE_WIDTH]reg_last_dcache_next_state;

always_ff @(posedge clk)begin
    reg_data_stall <= data_stall;
end

always_ff @(posedge clk)begin
    reg_data_op <= data_op;
end

always_ff @(posedge clk)begin
    reg_data_cached <= data_cached;
end

always_ff @(posedge clk)begin
    reg_data_va <= data_va;
end

always_ff @(posedge clk)begin
    reg_data_pa <= data_pa;
end

always_ff @(posedge clk)begin
    reg_rlru_from_dcache <= rlru_from_dcache;
end

always_ff @(posedge clk)begin
    reg_last_dcache_next_state <= dcache_next_state;
end

assign pa_to_dcache = {reg_data_pa , reg_data_va};
//assign ad_to_dcache = (reg_data_stall)? {reg_data_pa, reg_data_va} : {{20{1'b0}}, data_va};
always_comb begin
    if(dcache_control_en == `D_CLEAR_LLIT)begin
        ad_to_dcache = {{20{1'b0}}, cnt, {5{1'b0}}};
    end
    else begin
        if(reg_data_stall)begin
            ad_to_dcache = {reg_data_pa, reg_data_va};
        end
        else begin
            ad_to_dcache = {{20{1'b0}}, data_va};
        end
    end
end
// assign store_data_to_dcache = store_data;
// assign rdata_to_dcache = rblock_from_pipline;
// assign wblock_to_pipline = dirty_data_from_dcache;
assign select_way_to_dcache = reg_rlru_from_dcache;
//assign wlru_en_to_dcache = ()

always_ff @(posedge clk)begin
    store_data_to_dcache <= store_data;
end
always_comb begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_ATOM: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_LOAD_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_STORE_ATOM: begin
                if(reg_data_cached && hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wlru_en_to_dcache = `ENABLE;
                end
                else begin
                    wlru_en_to_dcache = `UNABLE;
                end
            end 
            default: begin
                wlru_en_to_dcache = `UNABLE;
            end
        endcase
    end
    else begin
        if(((dcache_next_state == `D_NONE) && (reg_last_dcache_next_state == `D_LOAD)) || 
            ((dcache_next_state == `D_STORE) && (reg_last_dcache_next_state == `D_LOAD)) ||
            ((dcache_next_state == `D_SET_LLIT) && (reg_last_dcache_next_state == `D_LOAD)))begin
                wlru_en_to_dcache = `ENABLE;
        end
        else begin
            wlru_en_to_dcache = `UNABLE;
        end
    end
end

always_comb begin
    if(dcache_next_state == `D_WAIT_UNCACHED_LOAD)begin
        load_data = rword_from_pipline;
    end
    else begin
        if(~reg_data_stall)begin
            // if((reg_data_op == `DCACHE_REQ_STORE_ATOM) && hit_from_dcache && reg_data_cached && rllit_from_dcache[pa_to_icache[4:2]])begin
            //     load_data = `DCACHE_REQ_STORE_ATOM_SUCCESS;
            // end
            // else begin
            //     load_data = `DCACHE_REQ_STORE_ATOM_FAIL;
            // end
            if(reg_data_op == `DCACHE_REQ_STORE_ATOM)begin
                if(reg_data_cached && hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    load_data = `DCACHE_REQ_STORE_ATOM_SUCCESS;
                end 
                else begin
                    load_data = `DCACHE_REQ_STORE_ATOM_FAIL;
                end
            end
            else begin
                load_data = load_data_from_dcache;
            end
        end
        else begin
            load_data = load_data_from_dcache;
        end
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_dcache_next_state <= `D_NONE;
    end
    // if((dcache_next_state == `D_WAIT_LOAD) || (dcache_next_state == `D_WAIT_LOAD_ATOM) || (dcache_next_state == `D_WAIT_STORE)) begin
    //     reg_dcache_next_state <= dcache_next_state;
    // end
    else begin
        if(dcache_next_state > `D_WAIT_UNCACHED_WRITE)begin
            reg_dcache_next_state <= dcache_next_state;
        end
    end
end

always_comb begin
    if(~data_stall)begin
        unique case(data_op)
            `DCACHE_REQ_LOAD_ATOM: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_LOAD_WORD: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_LOAD_HALF_WORD: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_LOAD_BYTE: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_STORE_ATOM: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_STORE_WORD: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_STORE_HALF_WORD: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_STORE_BYTE: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_INITIALIZE: dcache_control_en = `D_WRITE_TAG;
            `DCACHE_REQ_INDEX_INVALIDATA: dcache_control_en = `D_WRITE_V;
            `DCACHE_REQ_HIT_INVALIDATA: dcache_control_en = `D_LOAD;
            `DCACHE_REQ_CLEAR_LLIT: dcache_control_en = `D_CLEAR_LLIT;
            default: dcache_control_en = dcache_next_state;
        endcase
    end
    else begin
        dcache_control_en = dcache_next_state;
    end
end

always_ff @(posedge clk)begin
    if(!rstn)begin
        dcache_next_state <= `D_NONE;
    end
    else begin
        if(~reg_data_stall)begin
            unique case(reg_data_op)
                `DCACHE_REQ_LOAD_ATOM: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_SET_LLIT;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_LOAD_ATOM;
                            end
                            else begin
                                dcache_next_state <= `D_WAIT_LOAD_ATOM;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_NONE;
                    end
                end
                `DCACHE_REQ_LOAD_WORD: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_NONE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_LOAD;
                            end
                            else begin
                                dcache_next_state <= `D_WAIT_LOAD;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_LOAD;
                    end
                end
                `DCACHE_REQ_LOAD_HALF_WORD: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_NONE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_LOAD;
                            end
                            else begin
                                dcache_next_state <= `D_WAIT_LOAD;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_LOAD;
                    end
                end
                `DCACHE_REQ_LOAD_BYTE: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_NONE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_LOAD;
                            end
                            else begin
                                dcache_next_state <= `D_WAIT_LOAD;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_LOAD;
                    end
                end
                `DCACHE_REQ_STORE_ATOM: begin
                    if((reg_data_cached) && (hit_from_dcache) && (rllit_from_dcache[pa_to_dcache[4:2]]))begin
                        dcache_next_state <= `D_STORE;
                    end
                    else begin 
                        dcache_next_state <= `D_NONE;
                    end
                end
                `DCACHE_REQ_STORE_WORD: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_STORE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_STORE;
                            end
                            else begin
                                dcache_next_state <= `D_WAIT_STORE;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_WRITE;
                    end
                end
                `DCACHE_REQ_STORE_HALF_WORD: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state = `D_STORE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_STORE;
                            end 
                            else begin
                                dcache_next_state = `D_WAIT_STORE;
                            end
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_WRITE;
                    end
                end
                `DCACHE_REQ_STORE_BYTE: begin
                    if(reg_data_cached)begin
                        if(hit_from_dcache)begin
                            dcache_next_state <= `D_STORE;
                        end
                        else begin
                            if(rdirty_from_dcache)begin
                                dcache_next_state <= `D_WAIT_STORE_STORE;
                            end
                            dcache_next_state <= `D_WAIT_STORE;
                        end
                    end
                    else begin
                        dcache_next_state <= `D_WAIT_UNCACHED_WRITE;
                    end
                end
                `DCACHE_REQ_HIT_INVALIDATA: begin
                    if((hit_from_icache) && (reg_data_cached))begin
                        dcache_next_state <= `D_WRITE_V;
                    end
                    else begin
                        dcache_next_state <= `D_NONE;
                    end
                end
                `DCACHE_REQ_CLEAR_LLIT: begin
                    dcache_next_state <= `D_CLEAR_LLIT;
                    cnt <= `DCACHE_CNT_START;
                end
                default: begin
                    dcache_next_state <= `D_NONE;
                end
            endcase
        end
        else begin
            // if((response_from_pipline == `FINISH_DCACHE_REQ) && ((dcache_next_state == `D_WAIT_LOAD) || (dcache_next_state == `D_WAIT_STORE) || 
            // (dcache_next_state == `D_WAIT_STORE_STORE) || (dcache_next_state == `D_WAIT_STORE_LOAD) || (dcache_next_state == `D_WAIT_LOAD_ATOM) ||
            // (dcache_next_state == `D_WAIT_STORE_LOAD_ATOM)))begin
            if((response_from_pipline == `FINISH_DCACHE_REQ) && (dcache_next_state > `D_WAIT_UNCACHED_WRITE))begin
                dcache_next_state <= `D_WRITE;
            end
            else begin
                if(dcache_next_state == `D_WRITE)begin
                    dcache_next_state <= `D_LOAD;
                end
                else if(dcache_next_state == `D_LOAD)begin
                    unique case(reg_dcache_next_state)
                        `D_WAIT_LOAD_ATOM: dcache_next_state <= `D_SET_LLIT;
                       // `D_WAIT_LOAD: dcache_next_state <= `D_NONE;
                        `D_WAIT_STORE: dcache_next_state <= `D_STORE;
                       // `D_WAIT_STORE_LOAD: dcache_next_state <= `D_NONE;
                        `D_WAIT_STORE_LOAD_ATOM: dcache_next_state <= `D_SET_LLIT;
                        `D_WAIT_STORE_STORE: dcache_next_state <= `D_STORE;
                        default: dcache_next_state <= `D_NONE;
                    endcase
                end
                else if((dcache_next_state == `D_STORE) || (dcache_next_state == `D_SET_LLIT))begin
                    dcache_next_state <= `D_NONE;
                end
                else if(dcache_next_state == `D_CLEAR_LLIT)begin
                    if(cnt == `DCACHE_CNT_FINISH) begin
                        dcache_next_state <= `D_NONE;
                    end
                    else begin
                        cnt <= cnt + 1;
                    end
                end
                else begin
                    dcache_next_state <= `D_NONE;
                end
            end
        end
    end
end

always_ff @(posedge clk)begin
    unique case(dcache_next_state)
        `D_WAIT_LOAD: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK;
        end
        `D_WAIT_LOAD_ATOM: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK;
        end
        `D_WAIT_STORE: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK;
        end
        `D_WAIT_STORE_LOAD: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_STORE_BLOCK;
        end
        `D_WAIT_STORE_STORE: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_STORE_BLOCK;
        end
        `D_WAIT_STORE_LOAD_ATOM: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_STORE_BLOCK;
        end
        `D_WAIT_UNCACHED_LOAD: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_LOAD_WORD;
        end
        `D_WAIT_UNCACHED_WRITE: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_STORE_WORD;
        end
        default: begin
            dcache_req_to_pipline <= `DCACHE_REQ_TO_PIPLINE_NONE;
        end
    endcase
end

always_comb begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_ATOM: begin
                if(reg_data_cached)begin
                    dcache_ready = `UNREADY;
                end
                else begin
                    dcache_ready = `READY;
                end
            end
            `DCACHE_REQ_LOAD_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    dcache_ready = `READY;
                end
                else begin
                    dcache_ready = `UNREADY;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    dcache_ready = `READY;
                end
                else begin
                    dcache_ready = `UNREADY;
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(reg_data_cached && hit_from_dcache)begin
                    dcache_ready = `READY;
                end
                else begin
                    dcache_ready = `UNREADY;
                end
            end
            `DCACHE_REQ_STORE_ATOM: begin
                if(reg_data_cached && hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    dcache_ready = `UNREADY;
                end
                else begin
                    dcache_ready = `READY;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                dcache_ready = `UNREADY;
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                dcache_ready = `UNREADY;
            end 
            `DCACHE_REQ_STORE_BYTE: begin
                dcache_ready = `UNREADY;
            end
            `DCACHE_REQ_HIT_INVALIDATA: begin
                if(reg_data_cached && hit_from_dcache)begin
                    dcache_ready = `UNREADY;
                end
                else begin
                    dcache_ready = `READY;
                end
            end
            `DCACHE_REQ_CLEAR_LLIT: begin
                if(cnt == `DCACHE_CNT_FINISH)begin
                    dcache_ready = `READY;
                end
                else begin
                    dcache_ready = `UNREADY;
                end
            end
            default: dcache_ready = `READY;
        endcase
    end
    else begin
        if(dcache_next_state == `D_NONE)begin
            dcache_ready = `READY;
        end
        else begin
            dcache_ready = `UNREADY;
        end
    end
end

always_comb begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_STORE_ATOM: begin
                if(reg_data_cached && hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    wen_to_dcache = 4'b1111;
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wen_to_dcache = 4'b1111;
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    if(pa_to_dcache[1])begin
                        wen_to_dcache = 4'b1100;
                    end
                    else begin
                        wen_to_dcache = 4'b0011;
                    end
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached && hit_from_dcache)begin
                    unique case(pa_to_dcache[1:0])
                        2'b00: wen_to_dcache = 4'b0001;
                        2'b01: wen_to_dcache = 4'b0010;
                        2'b10: wen_to_dcache = 4'b0100;
                        2'b11: wen_to_dcache = 4'b1000;
                    endcase
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            default: begin
                wen_to_dcache = 4'b0000;
            end
        endcase
    end
    else begin
        if(dcache_next_state == `D_STORE)begin
            unique case(reg_data_op)
            `DCACHE_REQ_STORE_ATOM: begin
                if(reg_data_cached && hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    wen_to_dcache = 4'b1111;
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    wen_to_dcache = 4'b1111;
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached && hit_from_dcache)begin
                    if(pa_to_dcache[1])begin
                        wen_to_dcache = 4'b1100;
                    end
                    else begin
                        wen_to_dcache = 4'b0011;
                    end
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached && hit_from_dcache)begin
                    unique case(pa_to_dcache[1:0])
                        2'b00: wen_to_dcache = 4'b0001;
                        2'b01: wen_to_dcache = 4'b0010;
                        2'b10: wen_to_dcache = 4'b0100;
                        2'b11: wen_to_dcache = 4'b1000;
                    endcase
                end
                else begin
                    wen_to_dcache = 4'b0000;
                end
            end
            default: begin
                wen_to_dcache = 4'b0000;
            end
        endcase
        end
        else begin
            wen_to_dcache = 4'b0000;
        end
    end 
end


DCache dcache(.clk(clk), .rstn(rstn), .ad(ad_to_dcache), .pa(pa_to_dcache), .control_en(dcache_control_en),
                .store_data(store_data_to_dcache), .r_data(rdata_to_dcache), .dirty_data(dirty_data_from_dcache),
                .load_data(load_data_from_dcache), .wen(wen_to_dcache), .select_way(select_way_to_dcache), 
                .wlru_en_from_cache(wlru_en_to_dcache), .rllit_to_cache(rllit_from_dcache), .rlru_to_cache(rlru_from_dcache),
                .rdirty_to_cache(rdirty_from_dcache), .hit(hit_from_dcache));


//cache pipline
logic [`BLOCK_WIDTH]rblock_from_pipline;
//logic [`DATA_WIDTH]rword_from_pipline;
logic icache_cached_to_pipline;
    
logic [`BLOCK_WIDTH]wblock_to_pipline;
logic [`DATA_WIDTH]wword_to_pipline;
logic [`WRITE_ENABLE]dcache_wen_to_pipline;
logic [`WRITE_ENABLE]dcache_ren_to_pipline;
logic [`ADDRESS_WIDTH]dcache_req_ad_to_pipline;
logic dcache_cached_to_pipline;

logic [`ADDRESS_WIDTH]icache_req_ad_to_pipline;

assign rdata_to_icache = rblock_from_pipline;
assign rdata_to_dcache = rblock_from_pipline;
assign ins = (reg_ins_cached)? ins_from_icache : rword_from_pipline;


always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_ATOM: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_LOAD_WORD: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached && ~hit_from_dcache && rdirty_from_dcache)begin
                    wblock_to_pipline <= rdirty_from_dcache;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_STORE_WORD: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_ATOM: begin
                if(reg_data_cached && ~hit_from_dcache)begin
                    dcache_cached_to_pipline <= `CACHED;
                end
            end
            `DCACHE_REQ_LOAD_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    dcache_cached_to_pipline <= `UNCACHED;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_ins_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_ATOM: begin
                if(reg_data_cached && ~hit_from_dcache)begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_LOAD_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(reg_data_cached)begin
                    if(~hit_from_dcache)begin
                        dcache_req_ad_to_pipline <= pa_to_dcache;
                    end
                end
                else begin
                    dcache_req_ad_to_pipline <= pa_to_dcache;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_STORE_WORD: begin
                if(~reg_data_cached)begin
                    dcache_wen_to_pipline <= 4'b1111;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(~reg_data_cached)begin
                    if(pa_to_dcache[1])begin
                        dcache_wen_to_pipline <= 4'b1100; 
                    end
                    else begin
                        dcache_wen_to_pipline <= 4'b0011;
                    end
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(~reg_data_cached)begin
                    unique case(pa_to_dcache[1:0])
                        2'b00: dcache_wen_to_pipline <= 4'b0001;
                        2'b01: dcache_wen_to_pipline <= 4'b0010;
                        2'b10: dcache_wen_to_pipline <= 4'b0100;
                        2'b11: dcache_wen_to_pipline <= 4'b1000;
                    endcase
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_LOAD_WORD: begin
                if(~reg_data_cached)begin
                    dcache_ren_to_pipline <= 4'b1111;
                end
            end
            `DCACHE_REQ_LOAD_HALF_WORD: begin
                if(~reg_data_cached)begin
                    if(pa_to_dcache[1])begin
                        dcache_ren_to_pipline <= 4'b1100;
                    end
                    else begin
                        dcache_ren_to_pipline <= 4'b0011;
                    end
                end
            end
            `DCACHE_REQ_LOAD_BYTE: begin
                if(~reg_data_cached)begin
                    unique case(pa_to_dcache[1:0])
                        2'b00: dcache_ren_to_pipline <= 4'b0001;
                        2'b01: dcache_ren_to_pipline <= 4'b0010;
                        2'b10: dcache_ren_to_pipline <= 4'b0100;
                        2'b11: dcache_ren_to_pipline <= 4'b1000;
                    endcase
                end
            end
        endcase
    end
end
always_ff @(posedge clk)begin
    if(~reg_data_stall)begin
        unique case(reg_data_op)
            `DCACHE_REQ_STORE_WORD: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_HALF_WORD: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
            `DCACHE_REQ_STORE_BYTE: begin
                if(~reg_data_cached)begin
                    wword_to_pipline <= store_data_to_dcache;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_ins_stall)begin
        unique case(reg_ins_op)
            `ICACHE_REQ_LOAD_INS: begin
                if(reg_ins_cached)begin
                    if(~hit_from_icache)begin
                        icache_cached_to_pipline <= `CACHED;
                    end
                end
                else begin
                    icache_cached_to_pipline <= `UNCACHED;
                end
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~reg_ins_stall)begin
        if(reg_ins_op == `ICACHE_REQ_LOAD_INS)begin
            if((reg_ins_cached && ~hit_from_icache) || (~reg_ins_cached))begin
                icache_req_ad_to_pipline <= pa_to_icache;
            end
        end
    end
end

// logic [`AXI_REQ_WIDTH]req_to_axi;
// logic [`BLOCK_WIDTH]wblock_to_axi;
// logic [`DATA_WIDTH]wword_to_axi;
// logic [`AXI_STRB_WIDTH]wword_en_to_axi;
// logic [`AXI_STRB_WIDTH]rword_en_to_axi;
// logic [`ADDRESS_WIDTH]ad_to_axi;
// logic cached_to_axi;

// logic [`BLOCK_WIDTH]rblock_from_axi;
// logic [`DATA_WIDTH]rword_from_axi;
// logic ready_from_axi;
// logic task_finish_from_axi;  

Cache_pipline U_Cache_pipline (.clk(clk), .rstn(rstn), .req_from_icache(icache_req_to_pipline), .req_ad_from_icache(icache_req_ad_to_pipline), .cached_from_icache(icache_cached_to_pipline),
                .req_from_dcache(dcache_req_to_pipline), .req_ad_from_dcache(dcache_req_ad_to_pipline),
                .wword_from_dcache(wword_to_pipline), .wword_en_from_dcache(dcache_wen_to_pipline), .wblock_from_dcache(wblock_to_pipline),
                .rword_en_from_dcache(dcache_ren_to_pipline), .cached_from_dcache(dcache_cached_to_pipline), 
                .rblock_to_cache(rblock_from_pipline), .rword_to_cache(rword_from_pipline), .response(response_from_pipline),
                .req_to_axi(req_to_axi), .wblock_to_axi(wblock_to_axi), .wword_to_axi(wword_to_axi), .wword_en_to_axi(wword_en_to_axi),
                .rword_en_to_axi(rword_en_to_axi), .ad_to_axi(ad_to_axi), .cached_to_axi(cached_to_axi), 
                .rblock_from_axi(rblock_from_axi), .rword_from_axi(rword_from_axi), .ready_from_axi(ready_from_axi), .task_finish_from_axi(task_finish_from_axi));


endmodule