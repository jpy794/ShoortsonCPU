`include "cpu_defs.svh"

module Memory1 (
    input clk, rst_n,

    /* load use */
    output load_use_t ld_use,

    /* forward */
    output forward_req_t fwd_req,

    /* from csr */
    input csr_t rd_csr,

    /* tlb */
    input tlb_entry_t tlb_entrys[TLB_ENTRY_NUM],

    /* to dcache */
    output logic [11:0] dcache_idx,          // for index
    output logic [4:0] dcache_op,
    output u32_t dcache_pa,
    output logic dcache_is_cached,
    output byte_type_t dcache_byte_type,
    output u32_t wr_dcache_data,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,
    input execute_memory1_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output memory1_memory2_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    execute_memory1_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic mem1_flush = is_flush | pass_in_r.is_flush;

    /* load use */
    assign ld_use.idx = pass_in_r.rd;
    assign ld_use.valid = pass_in_r.is_wr_rd;

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = pass_in_r.is_wr_rd;
    assign fwd_req.idx = pass_in_r.rd;
    always_comb begin
        if(pass_in_r.is_wr_rd_pc_plus4) fwd_req.data = pass_in_r.pc_plus4;
        else                            fwd_req.data = pass_in_r.ex_out;
    end

    /* memory1 stage */

    mat_t mat;
    phy_t pa;
    excp_pass_t addr_excp;
    AddrTrans U_AddrTrans (
        .va(pass_in_r.ex_out),
        .lookup_type(pass_in_r.is_store ? LOOKUP_STORE : LOOKUP_LOAD),
        .byte_type(pass_in_r.byte_type),
        .mat,
        .pa,
        .excp(addr_excp),

        .rd_csr,
        .tlb_entrys
    );

    /* to dcache */
    assign dcache_idx = pass_in_r.ex_out[11:0];
    assign dcache_pa = pa;
    assign dcache_is_cached = mat[0];
    assign dcache_byte_type = pass_in_r.byte_type;
    always_comb begin
        dcache_op = DC_NOP;
        if(~mem1_flush & pass_in_r.is_mem) begin
            if(pass_in_r.is_store) dcache_op = DC_W;
            else                   dcache_op = DC_R;
        end
    end
    assign wr_dcache_data = pass_in_r.rkd_data;


    /* out to next stage */
    assign pass_out.is_flush = mem1_flush;
    assign pass_out.byte_en = pass_in_r.ex_out[1:0];

    `PASS(pc);
    `PASS(ex_out);
    `PASS(is_mem);
    `PASS(is_store);
    `PASS(is_signed);
    `PASS(byte_type);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(pc_plus4);
    `PASS(rd);
    `PASS(is_wr_csr);
    `PASS(csr_addr);

    assign excp_pass_out = excp_pass_in_r.valid ? excp_pass_in_r : addr_excp;

endmodule