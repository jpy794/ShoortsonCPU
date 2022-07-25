`include "cpu_defs.svh"
`include "cache3/cache.svh"

module CPUTop (
    input logic clk, rst_n,
    // TODO: connect cache
    output logic [`AXI_ID_WIDTH]arid,
    output logic [`ADDRESS_WIDTH]araddr,
    output logic [`AXI_LEN_WIDTH]arlen,
    output logic [`AXI_SIZE_WIDTH]arsize,
    output logic [`AXI_BURST_WIDTH]arburst,
    output logic [`AXI_LOCK_WIDTH]arlock,
    output logic [`AXI_CACHE_WIDTH]arcache,
    output logic [`AXI_PROT_WIDTH]arprot,
    output logic arvalid,
    input logic arready,
    //write request
    output logic [`AXI_ID_WIDTH]awid,
    output logic [`ADDRESS_WIDTH]awaddr,
    output logic [`AXI_LEN_WIDTH]awlen,
    output logic [`AXI_SIZE_WIDTH]awsize,    
    output logic [`AXI_BURST_WIDTH]awburst,
    output logic [`AXI_LOCK_WIDTH]awlock,
    output logic [`AXI_CACHE_WIDTH]awcache,
    output logic [`AXI_PROT_WIDTH]awprot,
    output logic awvalid,
    input logic awready,
    //read back
    input logic [`AXI_ID_WIDTH]rid,
    input logic [`DATA_WIDTH]rdata,
    input logic [`AXI_RESP_WIDTH]rresp,
    input logic rlast,
    input logic rvalid,
    output logic rready,
    //write data
    output logic [`AXI_ID_WIDTH]wid,   
    output logic [`DATA_WIDTH]wdata,
    output logic [`AXI_STRB_WIDTH]wstrb,
    output logic wlast,
    output logic wvalid,
    input logic wready,
    //write back
    input logic [`AXI_ID_WIDTH]bid,
    input logic [`AXI_RESP_WIDTH]bresp,
    output logic bready,
    input logic bvaild,

    //TODO:DEBUG LINE
    output [31:0]debug0_wb_pc,
    output [3:0]debug0_wb_rf_wen,
    output [4:0]debug0_wb_rf_wnum,
    output [31:0]debug0_wb_rf_wdata
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
logic [`AXI_REQ_WIDTH]req_to_axi;
logic [`BLOCK_WIDTH]wblock_to_axi;
logic [`DATA_WIDTH]wword_to_axi;
logic [`AXI_STRB_WIDTH]wword_en_to_axi;
logic [`AXI_STRB_WIDTH]rword_en_to_axi;
logic [`ADDRESS_WIDTH]ad_to_axi;
logic cached_to_axi;

logic [`BLOCK_WIDTH]rblock_from_axi;
logic [`DATA_WIDTH]rword_from_axi;
logic ready_from_axi;
logic task_finish_from_axi;  
    Cache cache(.clk(clk), 
                .rstn(rst_n), 
                .ins_va(icache_idx),
                .ins_pa(icache_pa),
                .ins_op(icache_op),
                .ins_stall(icache_stall), 
                .ins_cached(icache_is_cached), 
                .ins(icache_data),
                .icache_ready(icache_ready),
                .data_va(dcache_idx),
                .data_pa(dcache_pa),
                .data_op({dcache_op, dcache_byte_type}),
                .data_stall(dcache_stall),
                .data_cached(dcache_is_cached),
                .store_data(),
                .load_data(dcache_data),
                .dcache_ready(dcache_ready),
                
                .req_to_axi(req_to_axi), 
                .wblock_to_axi(wblock_to_axi),
                .wword_to_axi(wword_to_axi), 
                .wword_en_to_axi(wword_en_to_axi),
                .rword_en_to_axi(rword_en_to_axi), 
                .ad_to_axi(ad_to_axi), 
                .cached_to_axi(cached_to_axi), 
                .rblock_from_axi(rblock_from_axi), 
                .rword_from_axi(rword_from_axi), 
                .ready_from_axi(ready_from_axi), 
                .task_finish_from_axi(task_finish_from_axi));

To_AXI to_axi(.clk(clk), 
                .rstn(rst_n),
                .req(req_to_axi),
                .wblock(wblock_to_axi),
                .wword(wword_to_axi),
                .wword_en(wword_en_to_axi),
                .ad(ad_to_axi),
                .cached(cached_to_axi),
                .task_finish(task_finish_from_axi),
                .rblock(rblock_from_axi),
                .rword(rword_from_axi),
                .rword_en(rword_en_to_axi),
                .arid(arid),
                .araddr(araddr),
                .arlen(arlen),
                .arsize(arsize),
                .arburst(arburst),
                .arlock(arlock),
                .arcache(arcache),
                .arprot(arprot),
                .arvalid(arvalid),
                .arready(arready),
                .awid(awid),
                .awaddr(awaddr),
                .awlen(awlen),
                .awsize(awsize),
                .awburst(awburst),
                .awlock(awlock),
                .awcache(awcache),
                .awprot(awprot),
                .awvalid(awvalid),
                .awready(awready),
                .rid(rid),
                .rdata(rdata),
                .rresp(rresp),
                .rlast(rlast),
                .rvalid(rvalid),
                .rready(rready),
                .wid(wid),
                .wdata(wdata),
                .wstrb(wstrb),
                .wlast(wlast),
                .wvaild(wvaild),
                .wready(wready),
                .bid(bid),
                .bresp(bresp),
                .bready(bready),
                .bvaild(bvaild));

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
