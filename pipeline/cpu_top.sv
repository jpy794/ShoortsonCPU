`include "cpu_defs.svh"

module CPUTop (
    input logic clk, rst_n
    // TODO: connect cache
);

    /* pass */
    fetch1_fetch2_pass_t pass_if1;
    fetch2_decode_pass_t pass_if2;
    decode_execute_pass_t pass_id;
    execute_memory1_pass_t pass_ex;
    memory1_memory2_pass_t pass_mem1;
    memory2_writeback_pass_t pass_mem2;
    excp_pass_t excp_if1, excp_if2, excp_id, excp_ex, excp_mem1, excp_mem2;

    /* ctrl signals */
    logic stall_if1, stall_if2, stall_id, stall_ex, stall_mem1, stall_mem2, stall_wb;
    logic flush_if1, flush_if2, flush_id, flush_ex, flush_mem1, flush_mem2, flush_wb;

    /* mux csr_addr */
    csr_addr_t csr_addr_wb, csr_addr_id, csr_addr;
    u32_t csr_wr_data, csr_rd_data;
    logic csr_we;
    assign csr_addr = csr_we ? csr_addr_wb : csr_addr_id;

    csr_t tlb_rd_csr, excp_rd_csr, if_rd_csr, id_rd_csr, mem1_rd_csr;
    excp_wr_csr_req_t excp_wr_csr_req;
    tlb_wr_csr_req_t tlb_wr_csr_req;

    CSR U_CSR (
        .clk, .rst_n,
        /* csr inst */
        .addr(csr_addr),
        .rd_data(csr_rd_data),
        .we(csr_we),
        .wr_data(csr_wr_data),
        /* to pipeline */
        .if_rd(if_rd_csr),
        .id_rd(id_rd_csr),
        .mem1_rd(mem1_rd_csr),
        .tlb_rd(tlb_rd_csr),
        .excp_rd(rd_from_csr_to_excp),
        /* wr_req */
        .tlb_wr_req(tlb_wr_req), 
        .excp_wr_req(excp_wr_csr_req)
    );

    reg_idx_t rj, rkd, rd;
    u32_t rj_data, rkd_data, rd_data;
    logic reg_we;
    RegFile U_RegFile (
        .clk, .rst_n,
        .rj,
        .rkd,
        .rj_data,
        .rkd_data,
        
        .we(reg_we),
        .rd,
        .rd_data
    );

    tlb_op_t tlb_op;
    logic [4:0] invtlb_op;
    vppn_t invtlb_vppn;
    asid_t invtlb_asid;
    tlb_entry_t itlb_lookup[TLB_ENTRY_NUM], dtlb_lookup[TLB_ENTRY_NUM];
    TLB U_TLB (
        .clk,
        .rd_csr(tlb_rd_csr),
        .wr_csr_req(tlb_wr_csr_req),
        /* tlb inst */
        .tlb_op,
        .invtlb_op,
        .invtlb_vppn,
        .invtlb_asid,
        /* lookup */
        .itlb_lookup,
        .dtlb_lookup
    );

    u32_t pc_if1_to_btb;
    btb_predict_t btb_pre;
    btb_resolved_t ex_resolved_btb;     // TODO
    logic btb_stall;
    BTB U_BTB (
        .clk, .rst_n,
        .is_stall(btb_stall),
        .pc(pc_if1_to_btb), 
        .predict_out(btb_pre),
        .ex_resolved_in(ex_resolved_btb)
    );

    wr_pc_req_t ex_wr_pc_req, excp_wr_pc_req;
    Fetch1 U_Fetch1 (
        .clk, .rst_n,

        .btb_is_stall(btb_stall),
        .btb_pc(pc_if1_to_btb),
        .btb_predict(btb_pre),

        .ex_wr_pc_req(ex_wr_pc_req),
        .excp_wr_pc_req(excp_wr_pc_req),

        .rd_csr(if_rd_csr),

        .tlb_entrys(itlb_entrys),

        .icache_idx(icache_idx),                // TODO: connect cache
        .icache_op(icache_op),
        .icache_pa(icache_pa),
        .icache_is_cached(icache_is_cached),

        .is_stall(stall_if1),
        .is_flush(flush_if1),
        .pass_out(pass_if1),
        .excp_pass_out(excp_if1)
    );

    logic icache_stall;
    Fetch2 U_Fetch2 (
        .clk, .rst_n,

        .icache_ready(icache_ready),            // TODO: connect cache
        .icache_data(icache_data),
        /* ctrl */
        .icache_stall(icache_stall),

        .is_stall(stall_if2),
        .is_flush(flush_if2), 
        .pass_in(pass_if1),
        .excp_pass_in(excp_if1),
        .pass_out(pass_if2),
        .excp_pass_out(excp_if2)
    );

    logic load_use_stall;
    Decode U_Decode (
        .clk, .rst_n,

        .csr_addr_out(csr_addr_id),
        .csr_data(csr_rd_data),

        .rj_out(rj),
        .rkd_out(rkd),
        .rj_data,
        .rk_data,
        /* ctrl */
        .load_use_stall, 
        .is_stall(stall_id),
        .is_flush(flush_id),
        .pass_in(pass_if2),
        .excp_pass_in(excp_if2),
        .pass_out(pass_id),
        .excp_pass_out(excp_id)
    );

    logic eu_stall;
    logic bp_miss_flush;
    forward_req_t mem1_fwd_req, mem2_fwd_req;
    Execute U_Execute(
        .clk, .rst_n,

        .eu_stall,
        .bp_miss_flush,
        .wr_pc_req(ex_wr_pc_req),
        /* forwarding */
        .mem1_req(mem1_fwd_req),
        .mem2_req(mem2_fwd_req),

        .is_stall(stall_ex),
        .is_flush(flush_ex),
        .pass_in(pass_id),
        .excp_pass_in(excp_id),
        .pass_out(pass_ex),
        .excp_pass_out(excp_ex)
    );

    Memory1 U_Memory1 (
        .clk, .rst_n,

        .fwd_req(mem1_fwd_req), 

        .rd_csr(mem1_rd_csr),

        .tlb_entrys(dtlb_lookup), 
        
        .dcache_idx(dcache_idx),                // TODO: connect dcache
        .dcache_op(dcache_op),
        .dcache_pa(dcache_pa),
        .dcache_is_cached(dcache_is_cached),
        .dcache_byte_type(dcache_byte_type),

        .is_stall(stall_mem1),
        .is_flush(flush_mem1), 
        .pass_in(pass_ex),
        .excp_pass_in(excp_ex), 
        .pass_out(pass_mem1),
        .excp_pass_out(excp_mem1)
    );

    logic dcache_stall;
    Memory2 U_Memory2 (
        .clk, .rst_n,

        .fwd_req(mem2_req),

        .dcache_ready(dcache_ready),        // TODO: connect dcache
        .dcache_data(dcache_data),
        .dcache_stall,

        .is_stall(mem2_stall),
        .is_flush(mem2_flush),
        .pass_in(pass_mem1),
        .excp_pass_in(excp_mem1), 
        .pass_out(pass_mem2),
        .excp_pass_out(excp_mem2)
    );

    excp_pass_t excp_wb;
    virt_t wb_pc;
    logic wb_ertn;
    Writeback U_Writeback (
        .clk, .rst_n,

        .reg_idx(rd),
        .reg_we(reg_we),
        .reg_data(rd_data),

        .csr_addr(csr_addr_wb),
        .csr_we(csr_we),
        .csr_data(csr_wr_data),

        .is_stall(stall_wb),
        .is_flush(flush_wb),
        .pass_in(pass_mem2),
        .excp_pass_out(excp_wb),

        .excp_pass_out(excp_wb),
        .pc_out(wb_pc),
        .inst_ertn(wb_ertn)
    );

    Exception U_Exception (
        .ti_in('0), .hwi_in('0),            // TODO: connect real interrupt
        /* from wb */
        .wb_ertn,                           // TODO: handle eret
        .pc_wb(wb_pc),
        .excp_wb,

        .wr_pc_req(excp_wr_pc_req),

        .rd_csr(excp_rd_csr),
        .wr_csr_req(excp_wr_csr_req)
    );

endmodule
