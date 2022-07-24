`include "../cpu_defs.svh"

module Fetch1 (
    input logic clk, rst_n,
    
    /* btb */
    output logic btb_is_stall,
    output u32_t btb_pc,
    input btb_predict_t btb_predict,

    /* TODO: decode set pc */

    /* execute stage set pc */
    input wr_pc_req_t ex_wr_pc_req,

    /* TODO: cache op */

    /* from csr */
    input csr_t rd_csr,

    /* itlb */
    input itlb_entrys[TLB_ENTRY_NUM],

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

    /* TODO: dmw */

    /* tlb_lookup */
    virt_t tlb_va;
    mat_t tlb_mat;
    esubcode_ecode_t tlb_ecode;
    logic tlb_is_exc;
    phy_t tlb_pa;
    TLBLookup U_TLBLookup (
        .entrys(itlb_entrys),

        .asid(rd_csr.asid.asid),
        .plv(rd_csr.crmd.plv),

        .va(tlb_va),
        .lookup_type(LOOKUP_FETCH),

        .pa(tlb_pa),
        .mat(tlb_mat),
        .ecode(tlb_ecode),
        .is_exc(tlb_is_exc)
    );

    /* to cache */
    /* TODO: maybe flush */
    assign icache_op = is_flush ? IC_NOP : IC_RW;
    assign icache_idx = pc_r[11:0];
    assign icache_pa = tlb_pa;
    assign icache_is_cached = tlb_mat[0];

    /* addr translate */
    logic is_direct;
    assign is_direct = rd_csr.crmd.da; // maybe consider crmd.pg ?

    logic is_dmw_found;
    assign is_dmw_found = 1'b0; // TODO: dmw

    logic is_tlb;
    assign is_tlb = ~is_direct & ~is_dmw_found;


    /* --- exception begin --- */
    assign excp_pass_out.badv = pc_r;
    always_comb begin
        excp_pass_out.valid = 1'b0;
        excp_pass_out.esubcode_ecode = tlb_ecode;
        if(pc_r[1:0] != 2'b00) begin
            /* fetch unaligned */
            excp_pass_out.valid = 1'b1;
            excp_pass_out.esubcode_ecode = ALE;
        end else if(tlb_is_exc & is_tlb) begin
            /* tlb exception */
            excp_pass_out.valid = 1'b1;
        end
    end


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
        if(ex_wr_pc_req.valid)      npc = ex_wr_pc_req.pc;
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

endmodule