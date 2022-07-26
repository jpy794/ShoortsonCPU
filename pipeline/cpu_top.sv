`include "cpu_defs.svh"

module CPUTop (
    input logic clk, rst_n,

    output logic is_icache_stall,           // TODO: impl this
    output logic [11:0] icache_idx,
    output logic [2:0] icache_op,
    output logic icache_is_cached,
    output logic [19:0] icache_pa,
    input logic icache_ready,
    input logic [31:0] icache_data,

    output logic is_dcache_stall,           // TODO: impl this
    output logic [11:0] dcache_idx,
    output logic [2:0] dcache_op,
    output logic dcache_is_cached,
    output logic [19:0] dcache_pa,
    input logic [31:0] dcache_ready,
    input logic [31:0] wr_dcache_data,
    output logic [31:0] rd_dcache_data,

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
    excp_pass_t excp_if1, excp_if2, excp_id, excp_ex, excp_mem1, excp_mem2;

    /* ctrl signals */
    logic stall_if1, stall_if2, stall_id, stall_ex, stall_mem1, stall_mem2, stall_wb;
    logic flush_if1, flush_if2, flush_id, flush_ex, flush_mem1, flush_mem2, flush_wb;

    /* mux csr_addr */
    csr_addr_t csr_addr_wb, csr_addr_id, csr_addr;
    u32_t csr_wr_data, csr_rd_data;
    logic csr_we;
    assign csr_addr = csr_we ? csr_addr_wb : csr_addr_id;

    csr_t tlb_rd_csr, excp_rd_csr, oif_rd_csr, id_rd_csr, mem1_rd_csr;
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

        .icache_idx,
        .icache_op,
        .icache_pa,
        .icache_is_cached,

        .is_stall(stall_if1),
        .is_flush(flush_if1),
        .pass_out(pass_if1),
        .excp_pass_out(excp_if1)
    );

    logic icache_stall;
    Fetch2 U_Fetch2 (
        .clk, .rst_n,

        .icache_ready,
        .icache_data,
        /* ctrl */
        .icache_stall,

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
        
        .dcache_idx,
        .dcache_op,
        .dcache_pa,
        .dcache_is_cached,
        .dcache_byte_type,
        .wr_dcache_data,

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

        .dcache_ready,
        .rd_cache_data,
        /* ctrl */
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

// logic [`AXI_ID_WIDTH]arid;
// logic [`ADDRESS_WIDTH]araddr;
// logic [`AXI_LEN_WIDTH]arlen;
// logic [`AXI_SIZE_WIDTH]arsize;
// logic [`AXI_BURST_WIDTH]arburst;
// logic [`AXI_LOCK_WIDTH]arlock;
// logic [`AXI_CACHE_WIDTH]arcache;
// logic [`AXI_PROT_WIDTH]arprot;
// logic arvalid;
// logic arready;
// logic [`AXI_ID_WIDTH]awid;
// logic [`ADDRESS_WIDTH]awaddr;
// logic [`AXI_LEN_WIDTH]awlen;
// logic [`AXI_SIZE_WIDTH]awsize;
// logic [`AXI_LOCK_WIDTH]awlock;
// logic [`AXI_CACHE_WIDTH]awcache;
// logic [`AXI_PROT_WIDTH]awprot;
// logic awvalid;
// logic awready;
// logic [`AXI_ID_WIDTH]rid;
// logic [`DATA_WIDTH]rdata;
// logic [`AXI_RESP_WIDTH]rresp;
// logic rlast;
// logic rvalid;
// logic rready;
// logic [`AXI_ID_WIDTH]wid;
// logic [`DATA_WIDTH]wdata;
// logic [`AXI_STRB_WIDTH]wstrb;
// logic wlast;
// logic wvaild;
// logic wready;
// logic [`AXI_ID_WIDTH]bid;
// logic [`AXI_RESP_WIDTH]bresp;
// logic bready;
// logic bvaild;


endmodule
