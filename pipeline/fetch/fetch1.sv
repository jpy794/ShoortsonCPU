`include "../cpu_defs.svh"

module Fetch1 (
    input logic clk, rst_n,
    
    /* btb */
    output u32_t btb_pc,
    input btb_predict_t btb_predict,

    /* TODO: decode set pc */

    /* execute set pc */
    input wr_pc_req_t ex_wr_pc_req,

    /* next stage */
    output fetch1_fetch2_pass_t pass_out
);

    u32_t pc, npc;

    /* btb stage */
    // btb need 1 clk to output result, so we need to forward pc write req
    always_comb begin
        if(ex_wr_pc_req.valid)  btb_pc = ex_wr_pc_req.pc;
        else                    btb_pc = pc;
    end

    /* fetch1 stage */
    always_comb begin
        if(ex_wr_pc_req.valid)      npc = ex_wr_pc_req.pc;
        else if(btb_predict.valid)  npc = btb_predict.npc;      // predict is based on pc(or the pc wr req) in last clk
        else                        npc = pc + 4;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pc <= 32'h1C000000; 
        end else begin
            pc <= npc;
        end
    end

endmodule