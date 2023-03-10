`include "cache.svh"

module Cache_pipline(
    input logic clk,
    input logic rstn,

    input logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]req_from_icache,
    input logic [`ADDRESS_WIDTH]req_ad_from_icache,

    dcache_req_to_pipline_t req_from_dcache,
    input logic [`ADDRESS_WIDTH]req_ad_from_dcache,
    input logic [`DATA_WIDTH]wword_from_dcache,
    input logic [`BLOCK_WIDTH]wblock_from_dcache,
    input logic [`AXI_STRB_WIDTH]wword_en_from_dcache,
    input logic [2:0]rword_en_from_dcache,

    output logic [`BLOCK_WIDTH]rblock_to_icache,
    output logic [`BLOCK_WIDTH]rblock_to_dcache,
    output logic [`DATA_WIDTH]rword_to_icache,
    output logic [`DATA_WIDTH]rword_to_dcache,
    output logic [`RESPONSE_FROM_PIPLINE_WIDTH]response,

    //from axi
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

pipline_state_t cs, ns;

logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]reg_req_from_icache;
logic [`ADDRESS_WIDTH]reg_req_ad_from_icache;
dcache_req_to_pipline_t reg_req_from_dcache;
logic [`ADDRESS_WIDTH]reg_req_ad_from_dcache;

// assign rblock_to_cache = rblock_from_axi;
// assign rword_to_cache = rword_from_axi;

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_req_from_icache <= `ICACHE_REQ_TO_PIPLINE_NONE;
    end
    else begin
        if((cs == I_PIPLINE_LOAD_WORD_FINISH) || (cs == I_PIPLINE_LOAD_BLOCK_FINISH))begin
                reg_req_from_icache <= `ICACHE_REQ_TO_PIPLINE_NONE;
        end
        else begin
            if(req_from_icache != `ICACHE_REQ_TO_PIPLINE_NONE)begin
                reg_req_from_icache <= req_from_icache;
            end
        end
    end
end

always_ff @(posedge clk)begin
    if(req_from_icache != `ICACHE_REQ_TO_PIPLINE_NONE)begin
        reg_req_ad_from_icache <= req_ad_from_icache;
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_req_from_dcache <= DCACHE_REQ_TO_PIPLINE_NONE;
    end
    else begin
        if((ns == PIPLINE_STORE_WORD_FINISH) || (ns == D_PIPLINE_LOAD_WORD_FINISH) ||
            (ns == D_PIPLINE_LOAD_BLOCK_FINISH) || (ns == PIPLINE_STORE_BLOCK_FINISH))begin
            reg_req_from_dcache <= DCACHE_REQ_TO_PIPLINE_NONE;
        end
        else begin
            if(req_from_dcache != DCACHE_REQ_TO_PIPLINE_NONE)begin
                reg_req_from_dcache <= req_from_dcache;
            end
        end
    end
end

always_ff @(posedge clk)begin
    if(req_from_dcache != DCACHE_REQ_TO_PIPLINE_NONE)begin
        reg_req_ad_from_dcache <= req_ad_from_dcache;
    end
end

always_ff @(posedge clk)begin
    if(req_from_dcache == DCACHE_REQ_TO_PIPLINE_LOAD_WORD)begin
        rword_en_to_axi <= rword_en_from_dcache;
    end
    else if(req_from_icache == `ICACHE_REQ_TO_PIPLINE_WORD)begin
        rword_en_to_axi <= 3'h2;
    end
end

always_ff @(posedge clk)begin
    if(req_from_dcache == DCACHE_REQ_TO_PIPLINE_STORE_WORD)begin
        wword_en_to_axi <= wword_en_from_dcache;
    end
end

always_ff @(posedge clk)begin
    if(req_from_dcache == DCACHE_REQ_TO_PIPLINE_STORE_WORD)begin
        wword_to_axi <= wword_from_dcache;
    end
end

always_ff @(posedge clk)begin
    if(req_from_dcache == DCACHE_REQ_TO_PIPLINE_STORE_BLOCK)begin
        wblock_to_axi <= wblock_from_dcache;
    end 
end
always_ff @(posedge clk)begin
    if(!rstn)begin
        cs <= PIPLINE_WAIT;
    end
    else begin
        cs <= ns;
    end
end

always_comb begin
    ns = cs;
    unique case(cs)
        PIPLINE_WAIT: begin
            unique case(reg_req_from_dcache)
                DCACHE_REQ_TO_PIPLINE_STORE_BLOCK: begin
                    ns = PIPLINE_REQ_STORE_BLOCK;
                end
                DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK: begin
                    ns = D_PIPLINE_REQ_LOAD_BLOCK;
                end
                DCACHE_REQ_TO_PIPLINE_LOAD_WORD: begin
                    ns = D_PIPLINE_REQ_LOAD_WORD;
                end
                DCACHE_REQ_TO_PIPLINE_STORE_WORD: begin
                    ns = PIPLINE_REQ_STORE_WORD;
                end
                default: begin
                    unique case(reg_req_from_icache)
                        `ICACHE_REQ_TO_PIPLINE_BLOCK: begin
                            ns = I_PIPLINE_REQ_LOAD_BLOCK;
                        end
                        `ICACHE_REQ_TO_PIPLINE_WORD: begin
                            ns = I_PIPLINE_REQ_LOAD_WORD;
                        end
                        default: ;
                    endcase
                end
            endcase
        end
        PIPLINE_REQ_STORE_BLOCK: begin
            if(ready_from_axi)begin
                ns = PIPLINE_WAIT_STORE_BLOCK;
            end
        end
        PIPLINE_WAIT_STORE_BLOCK: begin
            if(task_finish_from_axi)begin
                ns = PIPLINE_STORE_BLOCK_FINISH;
            end
        end
        PIPLINE_STORE_BLOCK_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        PIPLINE_REQ_STORE_WORD: begin
            if(ready_from_axi)begin
                ns = PIPLINE_WAIT_STORE_WORD;
            end
        end
        PIPLINE_WAIT_STORE_WORD: begin
            if(task_finish_from_axi)begin
                ns = PIPLINE_STORE_WORD_FINISH;
            end
        end 
        PIPLINE_STORE_WORD_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        D_PIPLINE_REQ_LOAD_BLOCK: begin
            if(ready_from_axi)begin
                ns = D_PIPLINE_WAIT_LOAD_BLOCK;
            end
        end
        D_PIPLINE_WAIT_LOAD_BLOCK: begin
            if(task_finish_from_axi)begin
                ns = D_PIPLINE_LOAD_BLOCK_FINISH;
            end
        end
        D_PIPLINE_LOAD_BLOCK_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        D_PIPLINE_REQ_LOAD_WORD: begin
            if(ready_from_axi)begin
                ns = D_PIPLINE_WAIT_LOAD_WORD;
            end
        end
        D_PIPLINE_WAIT_LOAD_WORD: begin
            if(task_finish_from_axi)begin
                ns= D_PIPLINE_LOAD_WORD_FINISH;
            end
        end
        D_PIPLINE_LOAD_WORD_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        I_PIPLINE_REQ_LOAD_BLOCK: begin
            if(ready_from_axi)begin
                ns = I_PIPLINE_WAIT_LOAD_BLOCK;
            end
        end
        I_PIPLINE_WAIT_LOAD_BLOCK: begin
            if(task_finish_from_axi)begin
                ns = I_PIPLINE_LOAD_BLOCK_FINISH;
            end
        end
        I_PIPLINE_LOAD_BLOCK_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        I_PIPLINE_REQ_LOAD_WORD: begin
            if(ready_from_axi)begin
                ns = I_PIPLINE_WAIT_LOAD_WORD;
            end
        end
        I_PIPLINE_WAIT_LOAD_WORD: begin
            if(task_finish_from_axi)begin
                ns = I_PIPLINE_LOAD_WORD_FINISH;
            end
        end
        I_PIPLINE_LOAD_WORD_FINISH: begin
            ns = PIPLINE_WAIT;
        end
        default: ;
    endcase
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        req_to_axi <= `REQ_TO_AXI_NONE;
    end
    else begin
        unique case(ns)
            I_PIPLINE_REQ_LOAD_BLOCK: begin
                req_to_axi <= `REQ_TO_AXI_LOAD_BLOCK;
            end
            I_PIPLINE_REQ_LOAD_WORD: begin
                req_to_axi <= `REQ_TO_AXI_LOAD_WORD;
            end
            D_PIPLINE_REQ_LOAD_BLOCK: begin
                req_to_axi <= `REQ_TO_AXI_LOAD_BLOCK;
            end
            D_PIPLINE_REQ_LOAD_WORD: begin
                req_to_axi <= `REQ_TO_AXI_LOAD_WORD;
            end
            PIPLINE_REQ_STORE_BLOCK: begin
                req_to_axi <= `REQ_TO_AXI_WRITE_BLOCK;
            end
            PIPLINE_REQ_STORE_WORD: begin
                req_to_axi <= `REQ_TO_AXI_WRITE_WORD;
            end
            default: begin
                req_to_axi <= `REQ_TO_AXI_NONE;
            end
        endcase
    end
end

// always_ff @(posedge clk)begin
//     unique case(ns)
//         PIPLINE_REQ_STORE_BLOCK: begin
//             cached_to_axi <= cached_from_dcache;
//         end
//         PIPLINE_REQ_STORE_WORD: begin
//             cached_to_axi <= cached_from_dcache;
//         end
//         D_PIPLINE_REQ_LOAD_BLOCK: begin
//             cached_to_axi <= cached_from_dcache;
//         end
//         D_PIPLINE_REQ_LOAD_WORD: begin
//             cached_to_axi <= cached_from_dcache;
//         end
//         I_PIPLINE_REQ_LOAD_BLOCK: begin
//             cached_to_axi <= cached_from_icache;
//         end
//         I_PIPLINE_REQ_LOAD_WORD: begin
//             cached_to_axi <= cached_from_icache;
//         end
//     endcase
// end

always_ff @(posedge clk)begin
    unique case(ns)
        PIPLINE_REQ_STORE_BLOCK: begin
            ad_to_axi <= reg_req_ad_from_dcache;
        end
        PIPLINE_REQ_STORE_WORD: begin
            ad_to_axi <= reg_req_ad_from_dcache;
        end
        D_PIPLINE_REQ_LOAD_BLOCK: begin
            ad_to_axi <= reg_req_ad_from_dcache;
        end
        D_PIPLINE_REQ_LOAD_WORD: begin
            ad_to_axi <= reg_req_ad_from_dcache;
        end
        I_PIPLINE_REQ_LOAD_WORD: begin
            ad_to_axi <= reg_req_ad_from_icache;
        end
        I_PIPLINE_REQ_LOAD_BLOCK: begin
            ad_to_axi <= reg_req_ad_from_icache;
        end
        default: ;
    endcase
end

// always_ff @(posedge clk)begin
//     unique case(ns)
//         PIPLINE_REQ_STORE_BLOCK: begin
//             req_from_to_axi <= `REQ_FROM_DCACHE;
//         end
//         PIPLINE_REQ_STORE_WORD: begin
//             req_from_to_axi <= `REQ_FROM_DCACHE;
//         end
//         D_PIPLINE_REQ_LOAD_BLOCK: begin
//             req_from_to_axi <= `REQ_FROM_DCACHE;
//         end
//         D_PIPLINE_REQ_LOAD_WORD: begin
//             req_from_to_axi <= `REQ_FROM_DCACHE;
//         end
//         `I_PIPLINE_REQ_LOAD_WORD: begin
//             req_from_to_axi <= `REQ_FROM_ICACHE;
//         end
//         `I_PIPLINE_REQ_LOAD_BLOCK: begin
//             req_from_to_axi <= `REQ_FROM_ICACHE;
//         end
//     endcase
// end

always_ff @(posedge clk)begin
    unique case(ns)
        PIPLINE_STORE_WORD_FINISH: begin
            response <= `FINISH_DCACHE_REQ;
        end
        PIPLINE_STORE_BLOCK_FINISH: begin
            response <= `FINISH_DCACHE_REQ;
        end
        D_PIPLINE_LOAD_BLOCK_FINISH: begin
            response <= `FINISH_DCACHE_REQ;
        end
        D_PIPLINE_LOAD_WORD_FINISH: begin
            response <= `FINISH_DCACHE_REQ;
        end
        I_PIPLINE_LOAD_BLOCK_FINISH: begin
            response <= `FINISH_ICACHE_REQ;
        end
        I_PIPLINE_LOAD_WORD_FINISH: begin
            response <= `FINISH_ICACHE_REQ;
        end
        default: response <= `FINISH_CACHE_REQ_NONE;
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        D_PIPLINE_LOAD_BLOCK_FINISH: begin
            rblock_to_dcache <= rblock_from_axi;
        end
        D_PIPLINE_LOAD_WORD_FINISH: begin
            rword_to_dcache <= rword_from_axi;
        end
        I_PIPLINE_LOAD_BLOCK_FINISH: begin
            rblock_to_icache <= rblock_from_axi;
        end
        I_PIPLINE_LOAD_WORD_FINISH: begin
            rword_to_icache <= rword_from_axi;
        end
        default: ;
    endcase
end


endmodule