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
    output u32_t wr_dcache_data,
    input logic dcache_busy,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,
    input execute_memory1_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output memory1_memory2_pass_t pass_out,
    
    output excp_req_t excp_req
);
    initial begin
        pass_in_r.is_store = 1'b0;
    end  //FIX

    execute_memory1_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk , negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic dcache_busy_stall;
    logic rdy_out;
    logic mem1_flush, mem1_stall;
    assign mem1_flush = flush | ~pass_in_r.valid;
    assign mem1_stall = ~next_rdy_in | dcache_busy_stall;

    assign rdy_in = mem1_flush | ~mem1_stall;
    assign rdy_out = ~mem1_flush & ~mem1_stall;        // only use this for pass_out.valid

    assign dcache_busy_stall = pass_in_r.is_mem & dcache_busy;      // flush has a higher priority, so do not need to AND flush here

    /* load use */
    assign ld_use.idx = pass_in_r.rd;
    assign ld_use.valid = pass_in_r.is_mem & ~pass_in_r.is_store & ~mem1_flush;

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = pass_in_r.is_wr_rd & ~mem1_flush;
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
        .en(~mem1_flush & pass_in_r.is_mem),
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
    always_comb begin
        dcache_op = DC_NOP;
        if(~mem1_flush & pass_in_r.is_mem) begin
            if(pass_in_r.is_store) dcache_op = {DC_W[4:2], pass_in_r.byte_type};
            else                   dcache_op = {DC_R[4:2], pass_in_r.byte_type};
        end
    end
    assign wr_dcache_data = pass_in_r.rkd_data;


    /* out to next stage */
    assign pass_out.valid = rdy_out;
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

    /* exception */
    assign excp_req.valid = pass_in_r.valid;
    assign excp_req.excp_pass = excp_pass_in_r.valid ? excp_pass_in_r : addr_excp;
    assign excp_req.epc = pass_in_r.pc;
    assign excp_req.inst_ertn = 1'b0;           // TODO: impl ertn

`ifdef DIFF_TEST
    `PASS(inst);

    assign pass_out.is_ld = rdy_out & pass_in_r.is_mem & ~pass_in_r.is_store;
    assign pass_out.is_st = rdy_out & pass_in_r.is_mem & pass_in_r.is_store;
    assign pass_out.pa = pa;
    assign pass_out.va = pass_in_r.ex_out;
    assign pass_out.st_data = pass_in_r.rkd_data;

    /* generate valid for difftest */
    always_comb begin
        pass_out.byte_valid = 8'b0;
        unique case(pass_in_r.byte_type)
            BYTE:       pass_out.byte_valid[0] = 1'b1;
            HALF_WORD:  pass_out.byte_valid[1] = 1'b1;
            WORD:       pass_out.byte_valid[2] = 1'b1;
            default: ;
        endcase
    end

`endif

endmodule