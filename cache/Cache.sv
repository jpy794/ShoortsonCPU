`include "cache.svh"

module Cache(
    input logic clk,
    input logic rstn,

    input logic [`VA_WIDTH]icache_va,
    input logic [`PA_WIDTH]icache_pa,
    input logic [`ICACHE_OP_WIDTH]icache_op,
    input logic icache_stall,
    input logic icache_cached,
    output logic [`DATA_WIDTH]ins,
    output logic icache_ready,
    output logic icache_busy,
    output logic icache_data_valid,

    //dcache
    input logic [`VA_WIDTH]data_va,
    input logic [`PA_WIDTH]data_pa,
    input logic [`DCACHE_OP_WIDTH]data_op,
    input logic data_stall,
    input logic data_cached,
    input logic [`DATA_WIDTH]store_data,
    output logic [`DATA_WIDTH]load_data,
    output logic dcache_ready,

    output logic [`AXI_REQ_WIDTH]req_to_axi,
    output logic [`BLOCK_WIDTH]wblock_to_axi,
    output logic [`DATA_WIDTH]wword_to_axi,
    output logic [`AXI_STRB_WIDTH]wword_en_to_axi,
    output logic [`DCACHE_REQ_REN_WIDTH]rword_en_to_axi,
    output logic [`ADDRESS_WIDTH]ad_to_axi,
    output logic cached_to_axi,

    input logic [`BLOCK_WIDTH]rblock_from_axi,
    input logic [`DATA_WIDTH]rword_from_axi,
    input logic ready_from_axi,
    input logic task_finish_from_axi   

);
//pipline
logic [`RESPONSE_FROM_PIPLINE_WIDTH]response_from_pipline;

//icache
logic [`ICACHE_STATE_WIDTH]icache_cs, icache_ns;

logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]icache_req_to_pipline;
logic [`ADDRESS_WIDTH]icache_req_ad_to_pipline;

logic [`VA_WIDTH]reg_icache_va;
logic [`PA_WIDTH]reg_icache_pa;
logic [`ICACHE_OP_WIDTH]reg_icache_op;


logic [`ADDRESS_WIDTH]ad_to_icache;
logic [`ADDRESS_WIDTH]pa_to_icache;
logic [`DATA_WIDTH]ins_from_icache;
logic wlru_en_to_icache;
logic select_way_to_icache;
logic rlru_from_icache;
logic [`BLOCK_WIDTH]rdata_to_icache;
logic hit_from_icache;

//temp
assign wlru_en_to_icache = 1'b0;
assign select_way_to_icache = 1'b0;
assign rdata_to_icache = 256'b0;

always_ff @(posedge clk)begin
    if(~icache_stall)begin
        reg_icache_va <= icache_va;
    end
end

always_ff @(posedge clk)begin
    if(~icache_stall)begin
        reg_icache_pa <= icache_pa;
    end
end

always_ff @(posedge clk)begin
    if(~icache_stall)begin
        reg_icache_op <= icache_op;
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        icache_cs <= `ICACHE_WAIT;
    end
    else begin
        icache_cs <= icache_ns;
    end
end

logic [`ICACHE_STATE_WIDTH] icache_nobusy_ns;
always_comb begin
    unique case(icache_op)
        `ICACHE_REQ_LOAD_INS: begin
            if(icache_cached)begin
                icache_nobusy_ns = `ICACHE_LOOKUP;
            end
            else begin
                icache_nobusy_ns = `ICACHE_REQ_LOAD_WORD;
            end
        end
        `ICACHE_REQ_INITIALIZE: begin
            icache_nobusy_ns = `ICACHE_WRITE_TAG;
        end
        `ICACHE_REQ_HIT_INVALIDATA: begin
            if(icache_cached)begin
                icache_nobusy_ns = `ICACHE_LOOKUP;
            end
            else begin
                icache_nobusy_ns = `ICACHE_WAIT;
            end
        end
        `ICACHE_REQ_INDEX_INVALIDATA: begin
            icache_nobusy_ns = `ICACHE_INDEX_WRITE_V;
        end
        default: begin
            icache_nobusy_ns = `ICACHE_WAIT;
        end
    endcase
end

always_comb begin
    icache_busy = 1'b1;
    icache_data_valid = 1'b0;
    unique case(icache_cs)
        `ICACHE_WAIT: begin
            icache_busy = 1'b0;
            icache_ns = icache_nobusy_ns;
        end
        `ICACHE_LOOKUP: begin
            if(~hit_from_icache && (reg_icache_op == `ICACHE_REQ_LOAD_INS))begin
                icache_ns = `ICACHE_REQ_LOAD_BLOCK;
            end
            if(hit_from_icache && (reg_icache_op == `ICACHE_REQ_HIT_INVALIDATA))begin
                icache_ns = `ICACHE_HIT_WRITE_V;
            end
            else begin
                icache_data_valid = 1'b1;
                if(~icache_stall) begin
                    icache_busy = 1'b0;
                    icache_ns = icache_nobusy_ns;
                end else begin
                    icache_busy = 1'b1;
                    icache_ns = `ICACHE_LOOKUP;
                end
            end
        end
        `ICACHE_REQ_LOAD_WORD: begin
            icache_ns = `ICACHE_LOAD_WORD_WAIT;
        end
        `ICACHE_REQ_LOAD_BLOCK: begin
            icache_ns = `ICACHE_LOAD_BLOCK_WAIT;
        end
        `ICACHE_LOAD_WORD_WAIT: begin
            if(response_from_pipline == `FINISH_ICACHE_REQ)begin
                icache_ns = `ICACHE_LOAD_WORD_DONE;
            end
            else begin
                icache_ns = `ICACHE_LOAD_WORD_WAIT;
            end
        end
        `ICACHE_LOAD_WORD_DONE: begin
            icache_data_valid = 1'b1;
            if(~icache_stall) begin
                icache_busy = 1'b0;
                icache_ns = icache_nobusy_ns;
            end else begin
                icache_busy = 1'b1;
                icache_ns = `ICACHE_LOAD_WORD_DONE;
            end
        end
        `ICACHE_LOAD_BLOCK_WAIT: begin
            if(response_from_pipline == `FINISH_ICACHE_REQ)begin
                icache_ns = `ICACHE_WRITE;
            end
            else begin
                icache_ns = `ICACHE_LOAD_BLOCK_WAIT;
            end
        end
        `ICACHE_WRITE: begin
            icache_ns = `ICACHE_LOOKUP;
        end
        `ICACHE_WRITE_TAG: begin
            icache_busy = 1'b0;
            unique case(icache_op)
                `ICACHE_REQ_LOAD_INS: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_REQ_LOAD_WORD;
                    end
                end
                `ICACHE_REQ_INITIALIZE: begin
                    icache_ns = `ICACHE_WRITE_TAG;
                end
                `ICACHE_REQ_HIT_INVALIDATA: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_WAIT;
                    end
                end
                `ICACHE_REQ_INDEX_INVALIDATA: begin
                    icache_ns = `ICACHE_INDEX_WRITE_V;
                end
                default: begin
                    icache_ns = `ICACHE_WAIT;
                end
            endcase
        end 
        `ICACHE_INDEX_WRITE_V: begin
            icache_busy = 1'b0;
            unique case(icache_op)
                `ICACHE_REQ_LOAD_INS: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_REQ_LOAD_WORD;
                    end
                end
                `ICACHE_REQ_INITIALIZE: begin
                    icache_ns = `ICACHE_WRITE_TAG;
                end
                `ICACHE_REQ_HIT_INVALIDATA: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_WAIT;
                    end
                end
                `ICACHE_REQ_INDEX_INVALIDATA: begin
                    icache_ns = `ICACHE_INDEX_WRITE_V;
                end
                default: begin
                    icache_ns = `ICACHE_WAIT;
                end
            endcase
        end
        `ICACHE_HIT_WRITE_V: begin
            icache_busy = 1'b0;
            unique case(icache_op)
                `ICACHE_REQ_LOAD_INS: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_REQ_LOAD_WORD;
                    end
                end
                `ICACHE_REQ_INITIALIZE: begin
                    icache_ns = `ICACHE_WRITE_TAG;
                end
                `ICACHE_REQ_HIT_INVALIDATA: begin
                    if(icache_cached)begin
                        icache_ns = `ICACHE_LOOKUP;
                    end
                    else begin
                        icache_ns = `ICACHE_WAIT;
                    end
                end
                `ICACHE_REQ_INDEX_INVALIDATA: begin
                    icache_ns = `ICACHE_INDEX_WRITE_V;
                end
                default: begin
                    icache_ns = `ICACHE_WAIT;
                end
            endcase
        end
        default: begin
            icache_ns = `ICACHE_WAIT;
        end
    endcase
end

//contract with cpu
always_comb begin
    unique case(icache_cs)
        `ICACHE_WAIT: begin
            icache_ready = 1'b0;
        end
        `ICACHE_LOOKUP: begin
            icache_ready = 1'b1;
        end
        `ICACHE_WRITE_TAG: begin
            icache_ready = 1'b1;
        end
        `ICACHE_INDEX_WRITE_V: begin
            icache_ready = 1'b1;
        end
        default: begin
            icache_ready = 1'b0;
        end
    endcase
end
logic [`DATA_WIDTH]rword_from_pipline;
always_comb begin
    if(icache_cs == `ICACHE_LOAD_WORD_DONE)begin
        ins = rword_from_pipline;
    end
    else begin
        ins = ins_from_icache;
    end
end

//contract with icache
always_comb begin
    unique case(icache_ns)
        `ICACHE_HIT_WRITE_V: begin
            ad_to_icache = {reg_icache_pa, reg_icache_va};
        end
        `ICACHE_WRITE: begin
            ad_to_icache = {reg_icache_pa, reg_icache_va};
        end
        default: begin
            ad_to_icache = {{20{1'b0}}, icache_va};
        end
    endcase
end

assign pa_to_icache = {reg_icache_pa, reg_icache_va};

//contract with pipline
always_comb begin
    unique case(icache_ns)
        `ICACHE_REQ_LOAD_WORD: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_WORD;
        end
        `ICACHE_REQ_LOAD_BLOCK: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_BLOCK;
        end
        default: begin
            icache_req_to_pipline = `ICACHE_REQ_TO_PIPLINE_NONE;
        end
    endcase
end

assign icache_req_ad_to_pipline = (icache_ns == `ICACHE_REQ_LOAD_WORD)? {icache_pa, icache_va} : pa_to_icache;

ICache icache(.clk(clk), .rstn(rstn), .pa(pa_to_icache), .ad(ad_to_icache),
                .control_en(ins_control_en), .wlru_en_from_cache(wlru_en_to_icache),
                .select_way(select_way_to_icache), .rlru_to_cache(rlru_from_icache),
                .r_data(rdata_to_icache), .ins(ins_from_icache), .hit(hit_from_icache));



//dcache control
logic [`DCACHE_STATE_WIDTH]dcache_cs, dcache_ns;


always_ff @(posedge clk)begin
    if(~rstn)begin
        dcache_cs <= `D_WAIT;
    end
    else begin
        dcache_cs <= dcache_ns;
    end
end

// always_comb begin
//     unique case(dcache_cs)
//         `D_WAIT: begin
//             unique case(dcache_op)
//                 `DCACHE_REQ_LOAD_ATOM: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_WAIT;
//                     end
//                 end
//                 `DCACHE_REQ_LOAD_WORD: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_LOAD_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_LOAD_HALF_WORD: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_LOAD_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_LOAD_BYTE: begin
//                     if(dcache_cached)begin
//                         dcaceh_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_LOAD_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_STORE_ATOM: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_WAIT;
//                     end
//                 end
//                 `DCACHE_REQ_STORE_WORD: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_STORE_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_STORE_HALF_WORD: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_STORE_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_STORE_BYTE: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin
//                         dcache_ns = `D_REQ_TO_PIPLINE_STORE_WORD;
//                     end
//                 end
//                 `DCACHE_REQ_INITIALIZE: begin
//                     dcache_ns = `D_WRITE_TAG;
//                 end
//                 `DCACHE_REQ_INDEX_INVALIDATA: begin
//                     dcache_ns = `D_WRITE_V;
//                 end
//                 `DCACHE_REQ_HIT_INVALIDATA: begin
//                     if(dcache_cached)begin
//                         dcache_ns = `D_LOAD;
//                     end
//                     else begin 
//                         dcache_ns = `D_WAIT;
//                     end
//                 end
//                 `DCACHE_REQ_CLEAR_LLIT: begin
//                     dcache_ns = `DCACHE_REQ_CLEAR_LLIT;
//                 end
//                 default: begin
//                     dcache_ns = `D_WAIT;
//                 end
//             endcase
//             `D_LOAD: begin
//                 if(~hit_from_dcache)begin
//                     unique case(reg_dcache_op)
//                         `DCACHE_REQ_LOAD_ATOM: begin
//                             dcache_ns 
//                         end
//                     endcase
//                 end
//             end
//             def
//         end
//     endcase
// end

logic icache_cached_to_pipline;
logic [`DCACHE_REQ_TO_PIPLINE_WIDTH]dcache_req_to_pipline;
logic [`ADDRESS_WIDTH]dcache_req_ad_to_pipline;
logic [`DATA_WIDTH]wword_to_pipline;
logic [`BLOCK_EN]dcache_wen_to_pipline;
logic [`BLOCK_WIDTH]wblock_to_pipline;
logic [1:0]dcache_ren_to_pipline;
logic dcache_cached_to_pipline;
logic [`BLOCK_WIDTH]rblock_from_pipline;
//logic [`DATA_WIDTH]rword_from_pipline;

Cache_pipline U_Cache_pipline (.clk(clk), .rstn(rstn), 
                .req_from_icache(icache_req_to_pipline), .req_ad_from_icache(icache_req_ad_to_pipline), .cached_from_icache(icache_cached_to_pipline),
                .req_from_dcache(dcache_req_to_pipline), .req_ad_from_dcache(dcache_req_ad_to_pipline),
                .wword_from_dcache(wword_to_pipline), .wword_en_from_dcache(dcache_wen_to_pipline), .wblock_from_dcache(wblock_to_pipline),
                .rword_en_from_dcache(dcache_ren_to_pipline), .cached_from_dcache(dcache_cached_to_pipline), 
                .rblock_to_cache(rblock_from_pipline), .rword_to_cache(rword_from_pipline), .response(response_from_pipline),
                .req_to_axi(req_to_axi), .wblock_to_axi(wblock_to_axi), .wword_to_axi(wword_to_axi), .wword_en_to_axi(wword_en_to_axi),
                .rword_en_to_axi(rword_en_to_axi), .ad_to_axi(ad_to_axi), .cached_to_axi(cached_to_axi), 
                .rblock_from_axi(rblock_from_axi), .rword_from_axi(rword_from_axi), .ready_from_axi(ready_from_axi), .task_finish_from_axi(task_finish_from_axi));


endmodule