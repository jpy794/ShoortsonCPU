`include "cpu_defs.svh"

module CPUTop (
    input logic clk, rst_n,

    output logic stall_icache,
    output logic [11:0] icache_idx,
    output logic [2:0] icache_op,
    output logic icache_is_cached,
    output logic [31:0] icache_pa,
    input logic [31:0] icache_data,
    input logic icache_busy, icache_data_valid,

    output logic stall_dcache,
    output logic [11:0] dcache_idx,
    output logic [4:0] dcache_op,
    output logic dcache_is_cached,
    output logic [31:0] dcache_pa,
    output logic [31:0] wr_dcache_data,
    input logic [31:0] rd_dcache_data,
    input logic dcache_busy, dcache_data_valid,

    // TODO: int
    input logic [7:0] intrpt,

    // TODO:DEBUG LINE
    output logic [31:0] debug0_wb_pc,
    output logic [3:0] debug0_wb_rf_wen,
    output logic [4:0] debug0_wb_rf_wnum,
    output logic [31:0] debug0_wb_rf_wdata,
    output logic [31:0] debug0_wb_inst
);

    /* pass */
    fetch1_fetch2_pass_t pass_if1;
    fetch2_decode_pass_t pass_if2;
    decode_execute_pass_t pass_id;
    execute_memory1_pass_t pass_ex;
    memory1_memory2_pass_t pass_mem1;
    memory2_writeback_pass_t pass_mem2;
    excp_pass_t excp_if1, excp_if2, excp_id, excp_ex, excp_mem1;

    /* ctrl signals */
    logic flush_if1, flush_if2, flush_id, flush_ex, flush_mem1, flush_mem2, flush_wb;
    logic if1_rdy_in, if2_rdy_in, id_rdy_in, ex_rdy_in, mem1_rdy_in, mem2_rdy_in, wb_rdy_in;

    /* mux csr_addr */
    csr_addr_t csr_addr_wb, csr_addr_id, csr_addr;
    u32_t csr_wr_data, csr_rd_data;
    logic csr_we;
    assign csr_addr = csr_we ? csr_addr_wb : csr_addr_id;

    csr_t tlb_rd_csr, excp_rd_csr, if_rd_csr, id_rd_csr, mem1_rd_csr;
    excp_wr_csr_req_t excp_wr_csr_req;
    tlb_wr_csr_req_t tlb_wr_csr_req;

    RegCSR U_CSR (
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
        .excp_rd(excp_rd_csr),
        /* wr_req */
        .tlb_wr_req(tlb_wr_csr_req), 
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

    tlb_op_req_t tlb_req;
    tlb_entry_t itlb_lookup[TLB_ENTRY_NUM], dtlb_lookup[TLB_ENTRY_NUM];
    TLB U_TLB (
        .clk,
        .rd_csr(tlb_rd_csr),
        .wr_csr_req(tlb_wr_csr_req),
        /* tlb inst */
        .tlb_req,
        /* lookup */
        .itlb_lookup,
        .dtlb_lookup
    );

    u32_t pc_if1_to_btb;
    btb_predict_t btb_pre;
    btb_invalid_t if2_btb_invalid;
    br_resolved_t ex_resolved_br;
    logic stall_btb;
    BPU U_BPU (
        .clk, .rst_n,
        .is_stall(stall_btb),
        .pc(pc_if1_to_btb), 
        .predict_out(btb_pre),
        .btb_invalid_in(if2_btb_invalid),
        .ex_resolved_in(ex_resolved_br)
    );

    wr_pc_req_t if2_wr_pc_req, ex_wr_pc_req, excp_wr_pc_req;
    Fetch1 U_Fetch1 (
        .clk, .rst_n,

        .stall_btb,
        .btb_pc(pc_if1_to_btb),
        .btb_predict(btb_pre),

        .if2_wr_pc_req(if2_wr_pc_req),
        .ex_wr_pc_req(ex_wr_pc_req),
        .excp_wr_pc_req(excp_wr_pc_req),

        .rd_csr(if_rd_csr),

        .tlb_entrys(itlb_lookup),

        .icache_idx,
        .icache_op,
        .icache_pa,
        .icache_is_cached,
        .icache_busy,

        .flush(flush_if1),
        .next_rdy_in(if2_rdy_in),
        .rdy_in(if1_rdy_in),

        .pass_out(pass_if1),
        .excp_pass_out(excp_if1)
    );

    logic bp_error_flush;
    Fetch2 U_Fetch2 (
        .clk, .rst_n,

        .icache_data,
        .icache_data_valid,

        .flush(flush_if2),
        .next_rdy_in(id_rdy_in),
        .rdy_in(if2_rdy_in),

        .bp_error_flush(bp_error_flush),

        .wr_pc_req(if2_wr_pc_req),
        .btb_invalid(if2_btb_invalid),

        .pass_in(pass_if1),
        .excp_pass_in(excp_if1),
        .pass_out(pass_if2),
        .excp_pass_out(excp_if2)
    );

    load_use_t ex_ld_use, mem1_ld_use, mem2_ld_use;
    Decode U_Decode (
        .clk, .rst_n,

        .csr_addr_out(csr_addr_id),
        .csr_data(csr_rd_data),

        .rj_out(rj),
        .rkd_out(rkd),
        .rj_data,
        .rkd_data,

        .ex_ld_use,
        .mem1_ld_use,
        .mem2_ld_use,

        .flush(flush_id),
        .next_rdy_in(ex_rdy_in),
        .rdy_in(id_rdy_in),

        .pass_in(pass_if2),
        .excp_pass_in(excp_if2),
        .pass_out(pass_id),
        .excp_pass_out(excp_id)
    );

    logic bp_miss_flush;
    forward_req_t mem1_fwd_req, mem2_fwd_req;
    Execute U_Execute(
        .clk, .rst_n,

        /* flush ctrl */
        .bp_miss_flush,
        .wr_pc_req(ex_wr_pc_req),
        .br_resolved(ex_resolved_br),

        .ld_use(ex_ld_use),
        /* forwarding */
        .mem1_req(mem1_fwd_req),
        .mem2_req(mem2_fwd_req),

        .flush(flush_ex),
        .next_rdy_in(mem1_rdy_in),
        .rdy_in(ex_rdy_in),

        .pass_in(pass_id),
        .excp_pass_in(excp_id),
        .pass_out(pass_ex),
        .excp_pass_out(excp_ex)
    );

    excp_req_t excp_req;
    Memory1 U_Memory1 (
        .clk, .rst_n,

        .ld_use(mem1_ld_use),
        .fwd_req(mem1_fwd_req), 

        .rd_csr(mem1_rd_csr),

        .tlb_entrys(dtlb_lookup), 
        .tlb_req,
        
        .dcache_idx,
        .dcache_op,
        .dcache_pa,
        .dcache_is_cached,
        .wr_dcache_data,
        .dcache_busy,

        .flush(flush_mem1),
        .next_rdy_in(mem2_rdy_in),
        .rdy_in(mem1_rdy_in),

        .pass_in(pass_ex),
        .excp_pass_in(excp_ex), 
        .pass_out(pass_mem1),
        .excp_pass_out(excp_mem1)
    );

    Memory2 U_Memory2 (
        .clk, .rst_n,

        .ld_use(mem2_ld_use),
        .fwd_req(mem2_fwd_req),

        .rd_dcache_data,
        .dcache_data_valid,

        .flush(flush_mem2),
        .next_rdy_in(wb_rdy_in),
        .rdy_in(mem2_rdy_in),

        .pass_in(pass_mem1),
        .excp_pass_in(excp_mem1), 
        .pass_out(pass_mem2),

        .excp_req
    );

`ifdef DIFF_TEST
    excp_event_t excp_event[3];
    always_ff @(posedge clk) begin
        excp_event[1] <= excp_event[0];
        excp_event[2] <= excp_event[1];
    end
`endif

    Writeback U_Writeback (
        .clk, .rst_n,

        .reg_idx(rd),
        .reg_we(reg_we),
        .reg_data(rd_data),

        .csr_addr(csr_addr_wb),
        .csr_we(csr_we),
        .csr_data(csr_wr_data),

        .flush(flush_wb),
        .next_rdy_in(1'b1),
        .rdy_in(wb_rdy_in),

        .pass_in(pass_mem2)

`ifdef DIFF_TEST
        ,.excp_event_in(excp_event[2])
`endif
    );

    /* debug */
    assign debug0_wb_inst = '0;
    assign debug0_wb_pc = '0;
    assign debug0_wb_rf_wdata = '0;
    assign debug0_wb_rf_wen = '0;
    assign debug0_wb_rf_wnum = '0;

    logic excp_flush;
    Exception U_Exception (
        .ti_in('0), .hwi_in('0),            // TODO: connect real interrupt
        /* from mem1 */
        .req(excp_req),

        .wr_pc_req(excp_wr_pc_req),

        .excp_flush,

        .rd_csr(excp_rd_csr),
        .wr_csr_req(excp_wr_csr_req)
`ifdef DIFF_TEST
        ,.excp_event_out(excp_event[0])
`endif
    );

    assign stall_icache = ~ex_rdy_in;
    assign stall_dcache = ~wb_rdy_in;

    assign flush_if1 = bp_error_flush | bp_miss_flush | excp_flush;
    assign flush_if2 = bp_miss_flush | excp_flush;
    assign flush_id = bp_miss_flush | excp_flush;
    assign flush_ex = excp_flush;
    assign flush_mem1 = excp_flush;
    assign flush_mem2 = 1'b0;
    assign flush_wb = 1'b0;

endmodule
