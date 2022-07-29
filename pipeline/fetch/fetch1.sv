`include "cpu_defs.svh"

module Fetch1 (
    input logic clk, rst_n,
    
    /* btb */
    output logic stall_btb,
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
    input logic icache_busy,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,

    output fetch1_fetch2_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    logic rdy_out;
    logic if1_flush, if1_stall;                      // use if1_flush as ~valid for eu
    assign if1_flush = flush;                        // flush: invalidate current inst in pass_r and allow next inst in
    assign if1_stall = ~next_rdy_in | icache_busy;   // stall: do not allow next pass_in in
                                                     //        flush has a higher priority
    assign rdy_in = if1_flush | ~if1_stall;
    assign rdy_out = ~if1_flush & ~if1_stall;        // only use this for pass_out.valid

    mat_t mat;
    phy_t pa;
    excp_pass_t addr_excp;
    AddrTrans U_AddrTrans (
        .en(~if1_flush),
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
    assign icache_op = if1_flush ? IC_NOP : IC_R;
    assign icache_idx = pc_r[11:0];
    assign icache_pa = pa;
    assign icache_is_cached = mat[0];


    /* --- pipeline begin --- */
    /* pipeline reigster: pc_r */
    u32_t pc_r;

    u32_t npc;

    /* btb stage */
    // btb need 1 clk to output result, so we need to forward pc write req
    assign stall_btb = if1_stall;
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
        end else if(rdy_in) begin
            pc_r <= npc;
        end
    end

    /* pass */
    assign pass_out.valid = rdy_out;
    assign pass_out.pc = pc_r;
    assign pass_out.btb_pre = npc;

    /* exeption */
    assign excp_pass_out.valid = addr_excp.valid;               // when pass excp, do not consider flush, handle it at mem1
    assign excp_pass_out.esubcode_ecode = addr_excp.esubcode_ecode;
    assign excp_pass_out.badv = addr_excp.badv;

endmodule