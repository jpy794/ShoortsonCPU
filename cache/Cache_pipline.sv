`include "cache.svh"

module Cache_pipline(
    input logic clk,
    input logic rstn,

    input logic [`ICACHE_REQ_TO_PIPLINE_WIDTH]req_from_icache,
    input logic [`ADDRESS_WIDTH]req_ad_from_icache,
    input logic cached_from_icache,

    input logic [`DCACHE_REQ_TO_PIPLINE_WIDTH]req_from_dcache,
    input logic [`ADDRESS_WIDTH]req_ad_from_dcache,
    input logic [`DATA_WIDTH]wword_from_dcache,
    input logic [`BLOCK_WIDTH]wblock_from_dcache,
    input logic [`AXI_STRB_WIDTH]wword_en_from_dcache,
    input logic [`DCACHE_REQ_REN_WIDTH]rword_en_from_dcache,
    input logic cached_from_dcache,

    output logic [`BLOCK_WIDTH]rblock_to_cache,
    output logic [`ADDRESS_WIDTH]rword_to_cache,
    output logic [`RESPONSE_FROM_PIPLINE]response,

    //from axi
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

logic [`PIPLINE_STATE_WIDTH]cs, ns;

assign wblock_to_axi = wblock_from_dcache;
assign wword_to_axi = wword_from_dcache; 
assign rblock_to_cache = rblock_from_axi;
assign rword_to_cache = rword_from_axi;
assign wword_en_to_axi = wword_en_from_dcache;
assign rword_en_to_axi = rword_en_from_dcache;

always_ff @(posedge clk)begin
    if(!rstn)begin
        cs <= `PIPLINE_WAIT;
    end
    else begin
        cs <= ns;
    end
end

always_comb begin
    unique case(cs)
        `PIPLINE_WAIT: begin
            unique case(req_from_dcache)
                `DCACHE_REQ_TO_PIPLINE_LOAD_STORE_BLOCK: begin
                    ns = `PIPLINE_REQ_STORE_BLOCK;
                end
                `DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK: begin
                    ns = `D_PIPLINE_REQ_LOAD_BLOCK;
                end
                `DCACHE_REQ_TO_PIPLINE_LOAD_WORD: begin
                    ns = `D_PIPLINE_REQ_LOAD_WORD;
                end
                `DCACHE_REQ_TO_PIPLINE_STORE_WORD: begin
                    ns = `PIPLINE_REQ_STORE_WORD;
                end
                default: begin
                    unique case(req_from_icache)
                        `ICACHE_REQ_TO_PIPLINE_BLOCK: begin
                            ns = `I_PIPLINE_REQ_LOAD_BLOCK;
                        end
                        `ICACHE_REQ_TO_PIPLINE_WORD: begin
                            ns = `I_PIPLINE_REQ_LOAD_WORD;
                        end
                        default: begin
                            ns = `PIPLINE_WAIT;
                        end
                    endcase
                end
            endcase
        end
        `PIPLINE_REQ_STORE_BLOCK: begin
          //  ns = `PIPLINE_STORE_BLOCK_WAIT_READY;
            if(ready_from_axi)begin
                ns = `PIPLINE_STORE_BLOCK_WAIT_FINISH;
            end
            else begin
                ns = `PIPLINE_REQ_STORE_BLOCK;
            end
        end
        // `PIPLINE_STORE_BLOCK_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `PIPLINE_STORE_BLOCK_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `PIPLINE_STORE_BLOCK_WAIT_READY;
        //     end
        // end
        `PIPLINE_STORE_BLOCK_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns = `PIPLINE_STORE_BLOCK_FINISH;
            end
            else begin
                ns = `PIPLINE_STORE_BLOCK_WAIT_FINISH;
            end
        end
        `PIPLINE_STORE_BLOCK_FINISH: begin
            ns = `D_PIPLINE_REQ_LOAD_BLOCK;
        end
        `D_PIPLINE_REQ_LOAD_BLOCK: begin
            if(ready_from_axi)begin
                ns = `D_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
            end
            else begin
                ns = `D_PIPLINE_REQ_LOAD_BLOCK;
            end
            //ns = `D_PIPLINE_LOAD_BLOCK_WAIT_READY;
        end
        // `D_PIPLINE_LOAD_BLOCK_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `D_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `D_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
        //     end
        // end
        `D_PIPLINE_LOAD_BLOCK_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns = `D_PIPLINE_LOAD_BLOCK_FINISH;
            end
            else begin
                ns = `D_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
            end
        end
        `D_PIPLINE_LOAD_BLOCK_FINISH: begin
            ns = `PIPLINE_WAIT;
        end
        `PIPLINE_REQ_STORE_WORD: begin
            if(ready_from_axi)begin
                ns = `PIPLINE_STORE_WORD_WAIT_FINISH;
            end
            else begin
                ns = `PIPLINE_REQ_STORE_WORD;
            end
           // ns = `PIPLINE_STORE_WORD_WAIT_READY;
        end
        // `PIPLINE_STORE_BLOCK_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `PIPLINE_STORE_WORD_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `PIPLINE_STORE_WORD_WAIT_READY;
        //     end
        // end
        `PIPLINE_STORE_WORD_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns = `PIPLINE_STORE_WORD_FINISH;
            end
            else begin
                ns = `PIPLINE_STORE_WORD_WAIT_FINISH;
            end
        end
        `PIPLINE_STORE_WORD_FINISH: begin
            ns = `PIPLINE_WAIT;
        end
        `D_PIPLINE_REQ_LOAD_WORD: begin
            if(ready_from_axi)begin
                ns = `D_PIPLINE_LOAD_WORD_WAIT_FINISH;
            end
            else begin
                ns = `D_PIPLINE_REQ_LOAD_WORD;
            end
            //ns = `D_PIPLINE_LOAD_WORD_WAIT_READY;
        end
        // `D_PIPLINE_LOAD_WORD_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `D_PIPLINE_LOAD_WORD_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `D_PIPLINE_LOAD_WORD_WAIT_FINISH;
        //     end
        // end
        `D_PIPLINE_LOAD_WORD_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns= `D_PIPLINE_LOAD_WORD_FINISH;
            end
            else begin
                ns = `D_PIPLINE_LOAD_WORD_WAIT_FINISH;
            end
        end
        `D_PIPLINE_LOAD_WORD_FINISH: begin
            ns = `PIPLINE_WAIT;
        end
        `I_PIPLINE_REQ_LOAD_BLOCK: begin
            if(ready_from_axi)begin
                ns = `I_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
            end
            else begin
                ns = `I_PIPLINE_REQ_LOAD_BLOCK;
            end
         //   ns = `I_PIPLINE_LOAD_BLOCK_WAIT_READY;
        end
        // `I_PIPLINE_LOAD_BLOCK_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `I_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `I_PIPLINE_LOAD_BLOCK_WAIT_READY;
        //     end
        // end
        `I_PIPLINE_LOAD_BLOCK_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns = `I_PIPLINE_LOAD_BLOCK_FINISH;
            end
            else begin
                ns = `I_PIPLINE_LOAD_BLOCK_WAIT_FINISH;
            end
        end
        `I_PIPLINE_LOAD_BLOCK_FINISH: begin
            ns = `PIPLINE_WAIT;
        end
        `I_PIPLINE_REQ_LOAD_WORD: begin
            if(ready_from_axi)begin
                ns = `I_PIPLINE_LOAD_WORD_WAIT_FINISH;
            end
            else begin
                ns = `I_PIPLINE_REQ_LOAD_WORD;
            end
        end
        // `I_PIPLINE_LOAD_WORD_WAIT_READY: begin
        //     if(ready_from_axi)begin
        //         ns = `I_PIPLINE_LOAD_WORD_WAIT_FINISH;
        //     end
        //     else begin
        //         ns = `I_PIPLINE_LOAD_WORD_WAIT_READY;
        //     end
        // end
        `I_PIPLINE_LOAD_WORD_WAIT_FINISH: begin
            if(task_finish_from_axi)begin
                ns = `I_PIPLINE_LOAD_WORD_FINISH;
            end
            else begin
                ns = `I_PIPLINE_LOAD_WORD_WAIT_FINISH;
            end
        end
        `I_PIPLINE_LOAD_WORD_FINISH: begin
            ns = `PIPLINE_WAIT;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `I_PIPLINE_REQ_LOAD_BLOCK: begin
            req_to_axi <= `REQ_TO_AXI_LOAD_BLOCK;
        end
        `I_PIPLINE_REQ_LOAD_WORD: begin
            req_to_axi <= `REQ_TO_AXI_LOAD_WORD;
        end
        `D_PIPLINE_REQ_LOAD_BLOCK: begin
            req_to_axi <= `REQ_TO_AXI_LOAD_BLOCK;
        end
        `D_PIPLINE_REQ_LOAD_WORD: begin
            req_to_axi <= `REQ_TO_AXI_LOAD_WORD;
        end
        `PIPLINE_REQ_STORE_BLOCK: begin
            req_to_axi <= `REQ_TO_AXI_WRITE_BLOCK;
        end
        `PIPLINE_REQ_STORE_WORD: begin
            req_to_axi <= `REQ_TO_AXI_WRITE_WORD;
        end
        default:
            req_to_axi <= `REQ_TO_AXI_NONE;
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `PIPLINE_REQ_STORE_BLOCK: begin
            cached_to_axi <= cached_from_dcache;
        end
        `PIPLINE_REQ_STORE_WORD: begin
            cached_to_axi <= cached_from_dcache;
        end
        `D_PIPLINE_REQ_LOAD_BLOCK: begin
            cached_to_axi <= cached_from_dcache;
        end
        `D_PIPLINE_REQ_LOAD_WORD: begin
            cached_to_axi <= cached_from_dcache;
        end
        `I_PIPLINE_REQ_LOAD_BLOCK: begin
            cached_to_axi <= cached_from_icache;
        end
        `I_PIPLINE_REQ_LOAD_WORD: begin
            cached_to_axi <= cached_from_icache;
        end
    endcase
end

// always_ff @(posedge clk)begin
//     unique case(ns)
//     `I_PIPLINE_REQ_LOAD_BLOCK: begin
//         rblock_to_cache <= rblock_from_axi;
//     end
//     `I_PIPLINE_REQ_LOAD_WORD: begin
//         rblock_to_cache <= 
//     end
//     endcase
// end
always_ff @(posedge clk)begin
    unique case(ns)
        `PIPLINE_REQ_STORE_BLOCK: begin
            ad_to_axi <= req_ad_from_dcache;
        end
        `PIPLINE_REQ_STORE_WORD: begin
            ad_to_axi <= req_ad_from_dcache;
        end
        `D_PIPLINE_REQ_LOAD_BLOCK: begin
            ad_to_axi <= req_ad_from_dcache;
        end
        `D_PIPLINE_REQ_LOAD_WORD: begin
            ad_to_axi <= req_ad_from_dcache;
        end
        `I_PIPLINE_REQ_LOAD_WORD: begin
            ad_to_axi <= req_ad_from_icache;
        end
        `I_PIPLINE_REQ_LOAD_BLOCK: begin
            ad_to_axi <= req_ad_from_icache;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `PIPLINE_STORE_WORD_FINISH: begin
            response <= `FINISH_ICACHE_REQ;
        end
        `D_PIPLINE_LOAD_BLOCK_FINISH: begin
            response <= `FINISH_DCACHE_REQ;
        end
        `D_PIPLINE_LOAD_WORD_FINISH: begin
            response <= `FINISH_DCACHE_REQ; 
        end
        `I_PIPLINE_LOAD_BLOCK_FINISH: begin
            response <= `FINISH_ICACHE_REQ;
        end
        `I_PIPLINE_LOAD_WORD_FINISH: begin
            response <= `FINISH_ICACHE_REQ;
        end
        default: response <= `FINISH_CACHE_REQ_NONE;
    endcase
end
endmodule