`include "cpu_defs.svh"

module Fetch1 (
    input logic clk, rst_n,
    
    /* btb */
    output logic btb_is_stall,
    output u32_t btb_pc,
    input btb_predict_t btb_predict,

    /* TODO: decode set pc */

    /* execute stage set pc */
    input wr_pc_req_t ex_wr_pc_req,

    /* writeback stage set pc */
    input wr_pc_req_t excp_wr_pc_req,

    /* TODO: cache op */

    /* from csr */
    input csr_t rd_csr,

    /* tlb */
    input tlb_entry_t tlb_entrys[TLB_ENTRY_NUM],

    /* to icache */
    output logic [11:0] icache_idx,          // for index
    output logic [2:0] icache_op,
    output u32_t icache_pa,
    output logic icache_is_cached,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,

    output fetch1_fetch2_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    mat_t mat;
    phy_t pa;
    excp_pass_t addr_excp;
    AddrTrans U_AddrTrans (
        .va(pc_r),
        .lookup_type(LOOKUP_FETCH),
        .byte_type(WORD),
        .mat,
        .pa,
        .excp(addr_excp),

        .rd_csr,
        .tlb_entrys
    );

    /* to cache */
    /* TODO: maybe flush */
    assign icache_op = is_flush ? IC_NOP : IC_R;
    assign icache_idx = pc_r[11:0];
    assign icache_pa = pa;
    assign icache_is_cached = mat[0];


    /* --- pipeline begin --- */
    /* pipeline reigster: pc_r */
    u32_t pc_r;

    /* pass */
    assign pass_out.is_flush = is_flush;
    assign pass_out.pc = pc_r;
    assign pass_out.btb_pre = npc;

    u32_t npc;

    /* btb stage */
    // btb need 1 clk to output result, so we need to forward pc write req
    assign btb_is_stall = is_stall;
    assign btb_pc = npc;

    /* fetch1 stage */
    always_comb begin
        if(excp_wr_pc_req.valid)    npc = excp_wr_pc_req.pc;
        else if(ex_wr_pc_req.valid) npc = ex_wr_pc_req.pc;
        else if(btb_predict.valid)  npc = btb_predict.npc;      // predict is based on pc(or the pc wr req) in last clk
        else                        npc = pc_r + 4;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pc_r <= 32'h1c000000;
        end else if(~is_stall) begin
            pc_r <= npc;
        end
    end

    /* exeption */
    assign excp_pass_out.valid = addr_excp.valid & ~is_flush;
    assign excp_pass_out.esubcode_ecode = addr_excp.esubcode_ecode;
    assign excp_pass_out.badv = addr_excp.badv;

endmodule