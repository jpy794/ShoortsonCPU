`include "cpu_defs.svh"

module Fetch1 (
    input logic clk, rst_n,
    
    /* btb */
    output logic stall_btb,
    output u32_t btb_pc,
    input btb_predict_t btb_predict,

    /* TODO: decode set pc */

    /* if2 stage set pc */
    input wr_pc_req_t if2_wr_pc_req,

    /* execute stage set pc */
    input wr_pc_req_t mem1_wr_pc_req,

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
    input logic icache_ready,

    /* pipeline */
    input logic flush_i, stall_i,
    output logic stall_o,

    output fetch1_fetch2_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    /* pipeline start */
    logic icache_busy_stall;
    assign icache_busy_stall = eu_do & ~icache_ready;

    assign stall_o = stall_i | icache_busy_stall;

    logic valid_o;
    assign valid_o = ~stall_o;        // if ~valid_i, do not set exception valid

    logic excp_valid;
    assign excp_valid = addr_excp.valid;

    /* for this stage */
    logic eu_do;
    assign eu_do = ~excp_valid;

    /* out */
    assign pass_out.valid = valid_o & ~flush_i;
    assign pass_out.pc = pc_r;
    assign pass_out.icache_req = eu_do;

    /* exeption */
    always_comb begin
        excp_pass_out = addr_excp;
        excp_pass_out.valid = excp_pass_out.valid & valid_o;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pc_r <= 32'h1c000000;
        end else if(~stall_o | flush_i) begin
            pc_r <= npc;
        end
    end
    /* pipeline end */


    mat_t mat;
    phy_t pa;
    excp_pass_t addr_excp;
    AddrTrans U_AddrTrans (
        .en(1'b1),
        .va(pc_r),
        .lookup_type(LOOKUP_FETCH),
        .byte_type(WORD),
        .mat,
        .pa,
        .excp(addr_excp),

        .rd_csr,
        .tlb_entrys
    );

    /* icache */
    assign icache_op = eu_do ? IC_R : IC_NOP;
    assign icache_idx = pc_r[11:0];
    assign icache_pa = pa;
    assign icache_is_cached = mat[0];


    /* --- pipeline begin --- */
    /* pipeline reigster: pc_r */
    u32_t pc_r;

    u32_t npc;

    /* btb stage */
    // btb need 1 clk to output result, so we need to forward pc write req
    assign stall_btb = stall_o;
    assign btb_pc = npc;
    assign pass_out.next.pc = npc;

    /* fetch1 stage */
    always_comb begin
        if(excp_wr_pc_req.valid) begin
            npc = excp_wr_pc_req.pc;
            pass_out.next.is_predict = 0;
        end
        else if(mem1_wr_pc_req.valid) begin
            npc = mem1_wr_pc_req.pc;
            pass_out.next.is_predict = 0;
        end
        else if(if2_wr_pc_req.valid) begin
            npc = if2_wr_pc_req.pc;
            pass_out.next.is_predict = if2_wr_pc_req.is_predict;
        end
        else if(btb_predict.valid) begin
            npc = btb_predict.npc;      // predict is based on pc(or the pc wr req) in last clk
            pass_out.next.is_predict = 1;
        end
        else begin
            npc = pc_r + 4;
            pass_out.next.is_predict = 1;
        end
    end

endmodule