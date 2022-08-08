`include "cache.svh"
`include "../common_defs.svh"

module Cache(
    input logic clk,
    input logic rstn,

    input logic [`VA_WIDTH]icache_va,
    input logic [`PA_WIDTH]icache_pa,
    cache_op_t icache_op,
    input logic icache_req,
    input logic icache_taken,
    output logic cacop_ready,
    input logic [`VA_WIDTH]cacop_idx,
    input logic [`PA_WIDTH]cacop_pa,
    
    input logic icache_cached,
    output logic [`DATA_WIDTH]ins,
    output logic icache_ready,
  //  output logic icache_busy,
    output logic icache_data_valid,

    //dcache
    input logic [`VA_WIDTH]dcache_va,
    input logic [`PA_WIDTH]dcache_pa,
    input cache_dcache_op_t dcache_op,
    input logic dcache_taken,
    input logic dcache_cached,
    input logic [`DATA_WIDTH]store_data,
    output logic [`DATA_WIDTH]load_data,
    output logic dcache_ready,
    output logic dcache_data_valid,

    output logic [`AXI_REQ_WIDTH]req_to_axi,
    output logic [`BLOCK_WIDTH]wblock_to_axi,
    output logic [`DATA_WIDTH]wword_to_axi,
    output logic [`AXI_STRB_WIDTH]wword_en_to_axi,
    output logic [2:0]rword_en_to_axi,
    output logic [`ADDRESS_WIDTH]ad_to_axi,

    input logic [`BLOCK_WIDTH]rblock_from_axi,
    input logic [`DATA_WIDTH]rword_from_axi,
    input logic ready_from_axi,
    input logic task_finish_from_axi  

);
//logic dcache_cached = 1'b1;
//pipline
logic [`RESPONSE_FROM_PIPLINE_WIDTH]response_from_pipline;
logic [`DATA_WIDTH]wword_to_pipline;
logic [`BLOCK_EN]dcache_wen_to_pipline;
logic [`BLOCK_WIDTH]wblock_to_pipline;
logic [2:0]dcache_ren_to_pipline;
logic [`BLOCK_WIDTH]rblock_from_pipline_to_icache;
logic [`DATA_WIDTH]rword_from_pipline_to_icache;
logic [`BLOCK_WIDTH]rblock_from_pipline_to_dcache;
logic [`DATA_WIDTH]rword_from_pipline_to_dcache;

logic dcache_busy;
assign dcache_ready = ~dcache_busy;
//icache
icache_state_t icache_cs, icache_ns, icache_nobusy_ns;

logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]icache_req_to_pipline;
logic [`ADDRESS_WIDTH]icache_req_ad_to_pipline;

logic [`VA_WIDTH]reg_icache_va;
logic [`PA_WIDTH]reg_icache_pa;
logic reg_rlru_from_icache;
logic reg_icache_req;
logic [`VA_WIDTH]reg_cacop_idx;
logic [`PA_WIDTH]reg_cacop_pa;
cache_op_t reg_icache_op;
logic reg_icache_cached;

logic [`ADDRESS_WIDTH]ad_to_icache;
logic [`ADDRESS_WIDTH]pa_to_icache;
logic [`DATA_WIDTH]ins_from_icache;
logic wlru_en_to_icache;
logic select_way_to_icache;
logic rlru_from_icache;
logic [`BLOCK_WIDTH]rdata_to_icache;
logic hit_from_icache;

//logic icache_cached = 1'b1;
always_ff @(posedge clk)begin
    if (icache_ready)begin
        reg_icache_va <= icache_va;
    end
end

always_ff @(posedge clk)begin
    if (icache_ready)begin
        reg_icache_pa <= icache_pa;
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_icache_req <= 1'b0;
    end
    else begin
        if (icache_ready)begin
            reg_icache_req <= icache_req;
        end
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_icache_op <= CAC_NOP;
    end
    else begin
        if(cacop_ready)begin
            reg_icache_op <= icache_op;
        end
    end
end
always_ff @(posedge clk)begin
    if(cacop_ready)begin
        reg_cacop_idx <= cacop_idx;
    end
end

always_ff @(posedge clk)begin
    if(cacop_ready)begin
        reg_cacop_pa <= cacop_pa;
    end
end

always_ff @(posedge clk)begin
    reg_rlru_from_icache <= rlru_from_icache;
end

always_ff @(posedge clk)begin
    if(icache_ready)begin
        reg_icache_cached <= icache_cached;
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        icache_cs <= ICACHE_WAIT;
    end
    else begin
        icache_cs <= icache_ns;
    end
end


// always_comb begin
//     unique case(icache_op)
//         `ICACHE_REQ_LOAD_INS: begin
//             if(icache_cached)begin
//                 icache_nobusy_ns = `ICACHE_LOOKUP;
//             end
//             else begin
//                 icache_nobusy_ns = `ICACHE_REQ_LOAD_WORD;
//             end
//         end
//         `ICACHE_REQ_INITIALIZE: begin
//             icache_nobusy_ns = `ICACHE_WRITE_TAG;
//         end
//         `ICACHE_REQ_HIT_INVALIDATA: begin
//             if(icache_cached)begin
//                 icache_nobusy_ns = `ICACHE_LOOKUP;
//             end
//             else begin
//                 icache_nobusy_ns = `ICACHE_WAIT;
//             end
//         end
//         `ICACHE_REQ_INDEX_INVALIDATA: begin
//             icache_nobusy_ns = `ICACHE_INDEX_WRITE_V;
//         end
//         default: begin
//             if(icache_load)begin
//                 if(icache_cached)begin
//                     icache_nobusy_ns = `ICACHE_LOOKUP;
//                 end
//                 else begin
//                     icache_nobusy_ns = `ICACHE_REQ_LOAD_WORD;
//                 end
//             end
//             else begin
//                 icache_nobusy_ns = `ICACHE_LOOKUP;
//             end
//         end
//     endcase
// end

always_comb begin
    unique case(icache_op)
        CAC_INIT: begin
            icache_nobusy_ns = ICACHE_WRITE_TAG;
        end
        CAC_SRCH_INV: begin
            icache_nobusy_ns = ICACHE_LOAD;
        end
        CAC_IDX_INV: begin
            icache_nobusy_ns = ICACHE_INDEX_WRITE_V;
        end
        default: begin
            if(icache_req)begin
                if(icache_cached)begin
                    icache_nobusy_ns = ICACHE_LOOKUP;
                end
                else begin
                    icache_nobusy_ns = ICACHE_REQ_LOAD_WORD;
                end
            end
            else begin
                icache_nobusy_ns = ICACHE_LOOKUP;
            end
        end
    endcase
end

always_comb begin
    icache_ready = 1'b0;
    cacop_ready = 1'b0;
    icache_data_valid = 1'b0;
    unique case(icache_cs)
        ICACHE_WAIT: begin
            icache_ready = 1'b1;
            icache_ns = icache_nobusy_ns;
        end
        ICACHE_LOOKUP: begin
            if(hit_from_icache)begin
                cacop_ready = 1'b1;
                if(icache_op == CAC_NOP)begin
                    if(reg_icache_req)begin
                        icache_data_valid = 1'b1;
                        if(icache_taken)begin
                            icache_ready = 1'b1;
                            icache_ns = icache_nobusy_ns;
                        end
                        else begin
                            icache_ready = 1'b0;
                            icache_ns = ICACHE_LOOKUP;
                        end
                    end
                    else begin
                        icache_ready = 1'b1;
                        icache_ns = ICACHE_LOOKUP;
                    end
                end
                else begin
                    icache_ns = icache_nobusy_ns;
                    icache_ready = 1'b0;
                end
            end
            else begin
                if(reg_icache_req)begin
                    icache_ns = ICACHE_REQ_LOAD_BLOCK;
                end
                else begin
                    cacop_ready = 1'b1;
                    if(icache_op == CAC_NOP)begin
                        icache_ready = 1'b1;
                    end
                    icache_ns = icache_nobusy_ns;
                end
            end
        end
        ICACHE_REQ_LOAD_WORD: begin
            icache_ns = ICACHE_LOAD_WORD_WAIT;
        end
        ICACHE_REQ_LOAD_BLOCK: begin
            icache_ns = ICACHE_LOAD_BLOCK_WAIT;
        end
        ICACHE_LOAD_WORD_WAIT: begin
            if(response_from_pipline == `FINISH_ICACHE_REQ)begin
                icache_ns = ICACHE_LOAD_WORD_DONE;
            end
            else begin
                icache_ns = ICACHE_LOAD_WORD_WAIT;
            end
        end
        ICACHE_LOAD_WORD_DONE: begin
            cacop_ready = 1'b1;
            if(icache_op == CAC_NOP)begin
                icache_data_valid = 1'b1;
                if(icache_taken)begin
                    icache_ready = 1'b1;
                    icache_ns = icache_nobusy_ns;
                end
                else begin
                    icache_ready = 1'b0;
                    icache_ns = ICACHE_LOAD_WORD_DONE;
                end
            end
            else begin
                icache_ns = icache_nobusy_ns;
                icache_ready = 1'b0;
            end
        end
        ICACHE_LOAD_BLOCK_WAIT: begin
            if(response_from_pipline == `FINISH_ICACHE_REQ)begin
                icache_ns = ICACHE_WRITE;
            end
            else begin
                icache_ns = ICACHE_LOAD_BLOCK_WAIT;
            end
        end
        ICACHE_WRITE: begin
            icache_ns = ICACHE_LOOKUP;
        end
        ICACHE_WRITE_TAG: begin
            cacop_ready = 1'b1;
            if(icache_op == CAC_NOP)begin
                if(reg_icache_req)begin
                    if(reg_icache_cached)begin
                        icache_ns = ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = ICACHE_LOAD_WORD_DONE;
                    end
                end
                else begin
                    icache_ready = 1'b1;
                    icache_ns = icache_nobusy_ns;
                end
            end
            else begin
                icache_ns = icache_nobusy_ns;
            end
        end 
        ICACHE_INDEX_WRITE_V: begin
            cacop_ready = 1'b1;
            if(icache_op == CAC_NOP)begin
                if(reg_icache_req)begin
                    if(reg_icache_cached)begin
                        icache_ns = ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = ICACHE_LOAD_WORD_DONE;
                    end
                end
                else begin
                    icache_ready = 1'b1;
                    icache_ns = icache_nobusy_ns;
                end
            end
            else begin
                icache_ns = icache_nobusy_ns;
            end
        end
        ICACHE_HIT_WRITE_V: begin
            cacop_ready = 1'b1;
            if(icache_op == CAC_NOP)begin
                if(reg_icache_req)begin
                    if(reg_icache_cached)begin
                        icache_ns = ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = ICACHE_LOAD_WORD_DONE;
                    end
                end
                else begin
                    icache_ready = 1'b1;
                    icache_ns = icache_nobusy_ns;
                end
            end
            else begin
                icache_ns = icache_nobusy_ns;
            end
        end
        ICACHE_LOAD: begin
            if(hit_from_icache)begin
                icache_ns = ICACHE_HIT_WRITE_V;
            end
            else begin
                cacop_ready = 1'b1;
                if(icache_op == CAC_NOP)begin
                    if(reg_icache_req)begin
                        if(reg_icache_cached)begin
                            icache_ns = ICACHE_LOOKUP;
                        end
                        else begin
                            icache_ns = ICACHE_LOAD_WORD_DONE;
                        end
                    end
                    else begin
                        icache_ready = 1'b1;
                        icache_ns = icache_nobusy_ns;
                    end
                end
                else begin
                    icache_ns = icache_nobusy_ns;
                end
            end 
        end
        default: begin
            icache_ns = ICACHE_WAIT;
        end
    endcase
end

always_comb begin
    if(icache_cs == ICACHE_LOAD_WORD_DONE)begin
        ins = rword_from_pipline_to_icache;
    end
    else begin
        ins = ins_from_icache;
    end
end

//contract with icache

assign rdata_to_icache = rblock_from_pipline_to_icache;
assign select_way_to_icache = ~reg_rlru_from_icache;
assign wlru_en_to_icache = (icache_cs == ICACHE_LOOKUP && hit_from_icache)? `ENABLE : `UNABLE;

always_comb begin
    unique case(icache_ns)
        ICACHE_HIT_WRITE_V: begin
            ad_to_icache = {reg_cacop_pa, reg_cacop_idx};
        end
        ICACHE_WRITE: begin
            ad_to_icache = {reg_icache_pa, reg_icache_va};
        end
        ICACHE_LOAD: begin
            ad_to_icache = {cacop_pa, cacop_idx};
        end
        ICACHE_INDEX_WRITE_V: begin
            ad_to_icache = {cacop_pa, cacop_idx};
        end
        ICACHE_WRITE_TAG: begin
            ad_to_icache = {cacop_pa, cacop_idx};
        end
        default: begin
            if(~icache_ready)begin
                ad_to_icache = {reg_icache_pa, reg_icache_va};
            end
            else begin
                ad_to_icache = {{20{1'b0}}, icache_va};
            end
        end
    endcase
end

assign pa_to_icache = (icache_cs == ICACHE_LOAD)?{reg_cacop_pa, reg_cacop_idx} : {reg_icache_pa, reg_icache_va};

//contract with pipline
always_comb begin
    unique case(icache_ns)
        ICACHE_REQ_LOAD_WORD: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_WORD;
        end
        ICACHE_REQ_LOAD_BLOCK: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_BLOCK;
        end
        default: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_NONE;
        end
    endcase
end

assign icache_req_ad_to_pipline = (icache_ns == ICACHE_REQ_LOAD_WORD)? {icache_pa, icache_va} : {reg_icache_pa, reg_icache_va};

ICache icache(.clk(clk), .rstn(rstn), .pa(pa_to_icache), .ad(ad_to_icache),
                .control_en(icache_ns), .wlru_en_from_cache(wlru_en_to_icache),
                .select_way(select_way_to_icache), .rlru_to_cache(rlru_from_icache),
                .r_data(rdata_to_icache), .ins(ins_from_icache), .hit(hit_from_icache));



//dcache control
dcache_state_t dcache_cs, dcache_ns, dcache_nobusy_ns;
dcache_req_to_pipline_t dcache_req_to_pipline;
logic [`ADDRESS_WIDTH]dcache_req_ad_to_pipline;


cache_dcache_op_t reg_dcache_op;
logic [`PA_WIDTH]reg_dcache_pa;
logic [`VA_WIDTH]reg_dcache_va;
logic reg_rlru_from_dcache;
logic [`DATA_WIDTH]reg_store_data;

logic [`DCACHE_CNT_WIDTH]dcache_clear_llit_cnt;

logic [`ADDRESS_WIDTH]pa_to_dcache;
logic [`ADDRESS_WIDTH]ad_to_dcache;
logic [`BLOCK_WIDTH]rdata_to_dcache;
logic [`BLOCK_WIDTH]re_dirty_data_from_dcache;
logic [`BLOCK_WIDTH]wb_dirty_data_from_dcache;
logic [`BLOCK_WIDTH]hit_wb_dirty_data_from_dcache;
logic [`DATA_WIDTH]load_data_from_dcache;
logic [`BLOCK_EN]wen_to_dcache;
logic select_way_to_dcache;
logic wlru_en_to_dcache;
logic [`LLIT_WIDTH]rllit_from_dcache;
logic rlru_from_dcache;
logic re_rdirty_from_dcache;
logic wb_rdirty_from_dcache;
logic hit_wb_rdirty_from_dcache;
logic hit_from_dcache;
logic [`TAG_WIDTH]re_rtag_from_dcache;
logic [`TAG_WIDTH]wb_rtag_from_dcache;

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_dcache_op <= DCACHE_REQ_NONE;
    end
    else begin
        if(~dcache_busy)begin
            reg_dcache_op <= dcache_op;
        end
    end
end

always_ff @(posedge clk)begin
    if(~dcache_busy)begin
        reg_dcache_pa <= dcache_pa;
    end
end

always_ff @(posedge clk)begin
    if(~dcache_busy)begin
        reg_dcache_va <= dcache_va;
    end
end

always_ff @(posedge clk)begin
    if(~dcache_busy)begin
        reg_store_data <= store_data;
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        dcache_cs <= D_WAIT;
    end
    else begin
        dcache_cs <= dcache_ns;
    end
end

always_comb begin
    unique case(dcache_op)
        DCACHE_REQ_LOAD_ATOM: begin
            dcache_nobusy_ns = D_LOAD;
        end
        DCACHE_REQ_LOAD_WORD: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_LOAD_WORD;
            end
        end
        DCACHE_REQ_LOAD_HALF_WORD: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_LOAD_WORD;
            end
        end
        DCACHE_REQ_LOAD_BYTE: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_LOAD_WORD;
            end
        end
        DCACHE_REQ_STORE_ATOM: begin
            dcache_nobusy_ns = D_LOAD;
        end
        DCACHE_REQ_STORE_WORD: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_STORE_WORD;
            end
        end
        DCACHE_REQ_STORE_HALF_WORD: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_STORE_WORD; 
            end
        end
        DCACHE_REQ_STORE_BYTE: begin
            if(dcache_cached)begin
                dcache_nobusy_ns = D_LOAD;
            end
            else begin
                dcache_nobusy_ns = D_REQ_STORE_WORD;
            end
        end
        DCACHE_REQ_INITIALIZE: begin
            dcache_nobusy_ns = D_WRITE_TAG;
        end
        DCACHE_REQ_INDEX_INVALIDATA: begin
            dcache_nobusy_ns = D_INDEX_WRITE_V;
        end
        DCACHE_REQ_HIT_INVALIDATA: begin
            dcache_nobusy_ns = D_LOAD;
        end
        DCACHE_REQ_CLEAR_LLIT: begin
            dcache_nobusy_ns = D_CLEAR_LLIT;
        end
        default: begin
            dcache_nobusy_ns = D_LOAD;
        end
    endcase
end

always_comb begin
    dcache_busy = 1'b1;
    dcache_data_valid = 1'b0;
    dcache_ns = dcache_cs;
    unique case(dcache_cs)
        D_WAIT: begin
            dcache_busy = 1'b0;
            dcache_ns = dcache_nobusy_ns;
        end
        D_LOAD: begin
            if(~hit_from_dcache)begin
                unique case(reg_dcache_op)
                    DCACHE_REQ_LOAD_ATOM: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_LOAD_WORD: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_LOAD_HALF_WORD: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_LOAD_BYTE: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_STORE_ATOM: begin
                        if(dcache_taken)begin
                            dcache_busy = 1'b0;
                            dcache_ns = dcache_nobusy_ns;
                        end
                    end
                    DCACHE_REQ_STORE_WORD: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end 
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_STORE_HALF_WORD: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end 
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    DCACHE_REQ_STORE_BYTE: begin
                        if(re_rdirty_from_dcache)begin
                            dcache_ns = D_REQ_STORE_LOAD_BLOCK;
                        end 
                        else begin
                            dcache_ns = D_REQ_LOAD_BLOCK;
                        end
                    end
                    default: begin
                        dcache_busy = 1'b0;
                        dcache_ns = dcache_nobusy_ns;
                    end
                endcase
            end
            else begin
                unique case(reg_dcache_op)
                    DCACHE_REQ_LOAD_ATOM: begin
                        dcache_data_valid = 1'b1;
                        if(dcache_taken)begin
                            dcache_ns = D_SET_LLIT;
                        end
                    end
                    DCACHE_REQ_STORE_ATOM: begin
                        dcache_data_valid = 1'b1;
                        if(rllit_from_dcache[pa_to_dcache[4:2]])begin
                            if(dcache_taken)begin
                                dcache_ns = D_STORE;
                            end
                        end
                        else begin
                            if(dcache_taken)begin
                                dcache_busy = 1'b0;
                                dcache_ns = dcache_nobusy_ns;
                            end
                        end
                    end
                    DCACHE_REQ_STORE_WORD: begin
                        dcache_ns = D_STORE;
                    end
                    DCACHE_REQ_STORE_HALF_WORD: begin
                        dcache_ns = D_STORE;
                    end
                    DCACHE_REQ_STORE_BYTE: begin
                        dcache_ns = D_STORE;
                    end
                    DCACHE_REQ_HIT_INVALIDATA: begin
                        if(hit_wb_rdirty_from_dcache)begin
                            dcache_ns = D_HIT_WRITE_V_DIRTY;
                        end
                        else begin
                            dcache_ns = D_HIT_WRITE_V;
                        end
                    end
                    DCACHE_REQ_LOAD_WORD: begin
                        dcache_data_valid = 1'b1;
                        if(dcache_taken)begin
                            dcache_busy = 1'b0;
                            dcache_ns = dcache_nobusy_ns;
                        end
                    end
                    DCACHE_REQ_LOAD_BYTE: begin
                        dcache_data_valid = 1'b1;
                        if(dcache_taken)begin
                            dcache_busy = 1'b0;
                            dcache_ns = dcache_nobusy_ns;
                        end
                    end
                    DCACHE_REQ_LOAD_HALF_WORD: begin
                        dcache_data_valid = 1'b1;
                        if(dcache_taken)begin
                            dcache_busy = 1'b0;
                            dcache_ns = dcache_nobusy_ns;
                        end
                    end
                    default: begin
                        dcache_ns = dcache_nobusy_ns;
                        dcache_busy = 1'b0;
                    end 
                endcase
            end
        end
        D_WRITE_TAG: begin
            dcache_busy = 1'b0;
            dcache_ns = dcache_nobusy_ns;
        end
        D_INDEX_WRITE_V: begin
            if(wb_rdirty_from_dcache)begin
                dcache_ns = D_REQ_STORE_BLOCK;
            end
            else begin
                dcache_busy = 1'b0;
                dcache_ns = dcache_nobusy_ns;
            end
        end
        D_HIT_WRITE_V: begin
            dcache_busy = 1'b0;
            dcache_ns = dcache_nobusy_ns;
        end
        D_HIT_WRITE_V_DIRTY: begin
            dcache_ns = D_REQ_STORE_BLOCK;
        end 
        D_CLEAR_LLIT: begin
            if(dcache_clear_llit_cnt == `DCACHE_CNT_FINISH)begin
                dcache_busy = 1'b0;
                dcache_ns = dcache_nobusy_ns;
            end
        end
        D_SET_LLIT: begin
            dcache_busy = 1'b0;
            dcache_ns = dcache_nobusy_ns;
        end
        D_STORE: begin
            dcache_busy = 1'b0;
            dcache_ns = dcache_nobusy_ns;  
        end
        D_REQ_STORE_BLOCK: begin
            dcache_ns = D_WAIT_STORE_BLOCK;
        end
        D_WAIT_STORE_BLOCK: begin
            if(response_from_pipline == `FINISH_DCACHE_REQ)begin
                dcache_ns = D_WAIT;
            end
        end
        D_REQ_STORE_WORD: begin
            dcache_ns = D_WAIT_STORE_WORD;
        end
        D_WAIT_STORE_WORD: begin
            if(response_from_pipline == `FINISH_DCACHE_REQ)begin
                dcache_ns = D_WAIT;
            end
        end
        D_REQ_LOAD_WORD: begin
            dcache_ns = D_WAIT_LOAD_WORD;
        end
        D_WAIT_LOAD_WORD: begin
            if(response_from_pipline == `FINISH_DCACHE_REQ)begin
                dcache_ns = D_LOAD_WORD_DONE;
            end
        end
        D_LOAD_WORD_DONE: begin
            dcache_data_valid = 1'b1;
            if(dcache_taken)begin
                dcache_ns = dcache_nobusy_ns;
                dcache_busy = 1'b0;
            end
        end
        D_REQ_STORE_LOAD_BLOCK: begin
            dcache_ns = D_WAIT_STORE_LOAD_BLOCK;
        end
        D_WAIT_STORE_LOAD_BLOCK: begin
            if(response_from_pipline == `FINISH_DCACHE_REQ)begin
                dcache_ns = D_REQ_LOAD_BLOCK;
            end
        end
        D_REQ_LOAD_BLOCK: begin
            dcache_ns = D_WAIT_LOAD_BLOCK;
        end
        D_WAIT_LOAD_BLOCK: begin
            if(response_from_pipline == `FINISH_DCACHE_REQ)begin
                dcache_ns = D_WRITE;
            end
        end
        D_WRITE: begin
            dcache_ns = D_LOAD;
        end
        default: ;
    endcase
end

always_ff @(posedge clk)begin
    if(dcache_ns == D_CLEAR_LLIT)begin
        dcache_clear_llit_cnt <= dcache_clear_llit_cnt + 1;
    end
    else begin
        dcache_clear_llit_cnt <= `DCACHE_CNT_START;
    end
end

//contract with cpu
always_comb begin
    load_data = load_data_from_dcache;
    unique case(dcache_cs)
        D_LOAD_WORD_DONE:begin
            load_data = rword_from_pipline_to_dcache;
        end
        D_LOAD: begin
            if(reg_dcache_op == DCACHE_REQ_STORE_ATOM)begin
                if(hit_from_dcache && rllit_from_dcache[pa_to_dcache[4:2]])begin
                    load_data = {{31{1'b0}}, 1'b1};
                end
                else begin
                    load_data = 32'h0;
                end
            end
        end
        default: ;
    endcase
end

//contract with dcache
assign rdata_to_dcache = rblock_from_pipline_to_dcache;
assign pa_to_dcache = {reg_dcache_pa, reg_dcache_va};

always_comb begin
    ad_to_dcache = pa_to_dcache;
    unique case(dcache_ns)
        D_CLEAR_LLIT: begin
            ad_to_dcache = {{20{1'b0}}, dcache_clear_llit_cnt, {5{1'b0}}};
        end
        D_LOAD: begin
            if(~dcache_busy)begin           //TODO
                ad_to_dcache = {{20{1'b0}}, dcache_va};
            end
        end
        D_INDEX_WRITE_V: begin
            ad_to_dcache = {{20{1'b0}}, dcache_va};
        end
        D_WRITE_TAG: begin
            ad_to_dcache = {{20{1'b0}}, dcache_va};
        end
        default: ;
    endcase
end

always_comb begin
    wen_to_dcache = 4'b0000;
    unique case(dcache_ns)
        D_STORE: begin
            unique case(reg_dcache_op)
                DCACHE_REQ_STORE_ATOM: begin
                    wen_to_dcache = 4'b1111;
                end
                DCACHE_REQ_STORE_WORD: begin
                    wen_to_dcache = 4'b1111;
                end
                DCACHE_REQ_STORE_HALF_WORD: begin
                    if(reg_dcache_va[1])begin
                        wen_to_dcache = 4'b1100;
                    end
                    else begin
                        wen_to_dcache = 4'b0011;
                    end
                end
                DCACHE_REQ_STORE_BYTE: begin
                    unique case(reg_dcache_va[1:0])
                        2'b00: wen_to_dcache = 4'b0001;
                        2'b01: wen_to_dcache = 4'b0010;
                        2'b10: wen_to_dcache = 4'b0100;
                        2'b11: wen_to_dcache = 4'b1000;
                    endcase
                end    
            endcase
        end
        D_WRITE: begin
            wen_to_dcache = 4'b1111;
        end
        default: ;
    endcase
end

always_ff @(posedge clk)begin
    reg_rlru_from_dcache <= rlru_from_dcache;
end

assign select_way_to_dcache = ~reg_rlru_from_dcache;

assign wlru_en_to_dcache = (dcache_cs == D_LOAD && hit_from_dcache)? 1'b1 : 1'b0;


//contract with pipline

always_comb begin
    unique case(dcache_ns)
        D_REQ_STORE_BLOCK: begin
            dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_STORE_BLOCK;
        end
        D_REQ_STORE_WORD: begin
            dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_STORE_WORD;
        end
        D_REQ_LOAD_BLOCK: begin
            dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK;
        end
        D_REQ_LOAD_WORD: begin
            dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_LOAD_WORD;
        end
        D_REQ_STORE_LOAD_BLOCK: begin
            dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_STORE_BLOCK;
        end
        default: dcache_req_to_pipline = DCACHE_REQ_TO_PIPLINE_NONE;
    endcase
end

always_comb begin
    dcache_wen_to_pipline = 4'b0000;
    if(dcache_ns == D_REQ_STORE_WORD)begin
        unique case(dcache_op)
            DCACHE_REQ_STORE_WORD: begin
                dcache_wen_to_pipline = 4'b1111;
            end
            DCACHE_REQ_STORE_HALF_WORD: begin
                if(dcache_va[1])begin
                    dcache_wen_to_pipline = 4'b1100;
                end
                else begin
                    dcache_wen_to_pipline = 4'b0011;
                end
            end
            DCACHE_REQ_STORE_BYTE: begin
                unique case(dcache_va[1:0])
                    2'b00: dcache_wen_to_pipline = 4'b0001;
                    2'b01: dcache_wen_to_pipline = 4'b0010;
                    2'b10: dcache_wen_to_pipline = 4'b0100;
                    2'b11: dcache_wen_to_pipline = 4'b1000;
                endcase
            end
            default: ;
        endcase
    end
end

always_comb begin
    dcache_ren_to_pipline = 3'h2;
    if(dcache_ns == D_REQ_LOAD_WORD)begin
        unique case(dcache_op)
            DCACHE_REQ_LOAD_WORD: begin
                dcache_ren_to_pipline = 3'h2;
            end 
            DCACHE_REQ_LOAD_HALF_WORD: begin
                dcache_ren_to_pipline = 3'h1;
            end
            DCACHE_REQ_LOAD_BYTE: begin
                dcache_ren_to_pipline = 3'h0;
            end
            default: ;
        endcase
    end
end

always_comb begin
    dcache_req_ad_to_pipline = {dcache_pa, dcache_va};
    unique case(dcache_ns)
        D_REQ_STORE_BLOCK: begin
            dcache_req_ad_to_pipline = {wb_rtag_from_dcache, reg_dcache_va[11:5], {5{1'b0}}};
        end
        D_REQ_STORE_LOAD_BLOCK: begin
            dcache_req_ad_to_pipline = {re_rtag_from_dcache, reg_dcache_va[11:5], {5{1'b0}}};
        end
        D_REQ_LOAD_BLOCK: begin
            dcache_req_ad_to_pipline = pa_to_dcache;
        end
        default: ;
    endcase
end

assign wword_to_pipline = store_data;

//assign wblock_to_pipline = dirty_data_from_dcache;
always_comb begin
    wblock_to_pipline = re_dirty_data_from_dcache;
    unique case(dcache_cs)
        D_HIT_WRITE_V_DIRTY: wblock_to_pipline = hit_wb_dirty_data_from_dcache;
        D_INDEX_WRITE_V: wblock_to_pipline = wb_dirty_data_from_dcache;
        default: ;
    endcase
end

DCache dcache(.clk(clk), 
                .rstn(rstn), 
                .ad(ad_to_dcache), 
                .pa(pa_to_dcache),
                .control_en(dcache_ns),
                .store_data(reg_store_data),
                
                .r_data(rdata_to_dcache),
                .re_dirty_data(re_dirty_data_from_dcache),
                .wb_dirty_data(wb_dirty_data_from_dcache),
                .hit_wb_dirty_data(hit_wb_dirty_data_from_dcache),
                .load_data(load_data_from_dcache),
                
                .wen(wen_to_dcache),
                .select_way(select_way_to_dcache),
                .wlru_en_from_cache(wlru_en_to_dcache),
                .rllit_to_cache(rllit_from_dcache),
                .rlru_to_cache(rlru_from_dcache),
                .re_rdirty_to_cache(re_rdirty_from_dcache),
                .wb_rdirty_to_cache(wb_rdirty_from_dcache),
                .hit_wb_rdirty_to_cache(hit_wb_rdirty_from_dcache),
                .re_rtag_to_cache(re_rtag_from_dcache),
                .wb_rtag_to_cache(wb_rtag_from_dcache),
                .hit(hit_from_dcache),
                .dcache_cs(dcache_cs)
);

Cache_pipline U_Cache_pipline (.clk(clk), .rstn(rstn), 
                .req_from_icache(icache_req_to_pipline), 
                .req_ad_from_icache(icache_req_ad_to_pipline), 
                .req_from_dcache(dcache_req_to_pipline), 
                .req_ad_from_dcache(dcache_req_ad_to_pipline),
                .wword_from_dcache(wword_to_pipline), 
                .wword_en_from_dcache(dcache_wen_to_pipline), 
                .wblock_from_dcache(wblock_to_pipline),
                .rword_en_from_dcache(dcache_ren_to_pipline), 

                .rblock_to_dcache(rblock_from_pipline_to_dcache), 
                .rword_to_dcache(rword_from_pipline_to_dcache),
                .rblock_to_icache(rblock_from_pipline_to_icache),
                .rword_to_icache(rword_from_pipline_to_icache), 

                .response(response_from_pipline),
                .req_to_axi(req_to_axi), 
                .wblock_to_axi(wblock_to_axi), 
                .wword_to_axi(wword_to_axi), 
                .wword_en_to_axi(wword_en_to_axi),
                .rword_en_to_axi(rword_en_to_axi), 
                .ad_to_axi(ad_to_axi), 
                .rblock_from_axi(rblock_from_axi), 
                .rword_from_axi(rword_from_axi), 
                .ready_from_axi(ready_from_axi), 
                .task_finish_from_axi(task_finish_from_axi)
);


endmodule