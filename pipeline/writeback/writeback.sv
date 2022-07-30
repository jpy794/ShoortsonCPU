`include "cpu_defs.svh"

module Writeback (
    input clk, rst_n,

    /* to regfile */
    output reg_idx_t reg_idx,
    output logic reg_we,
    output u32_t reg_data,

    /* to csr */
    output csr_addr_t csr_addr,
    output logic csr_we,
    output u32_t csr_data,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,

    input memory2_writeback_pass_t pass_in
`ifdef DIFF_TEST
    ,input excp_event_t excp_event_in
`endif
);

    memory2_writeback_pass_t pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
        end
    end

    logic rdy_out;
    logic wb_flush, wb_stall;
    assign wb_flush = flush | ~pass_in_r.valid;
    assign wb_stall = ~next_rdy_in;

    assign rdy_in = wb_flush | ~wb_stall;
    assign rdy_out = ~wb_flush & ~wb_stall;        // only use this for pass_out.valid

    /* writeback stage */
    
    assign reg_idx = pass_in_r.rd;
    assign reg_data = pass_in_r.is_wr_rd_pc_plus4 ? pass_in_r.pc_plus4 : pass_in_r.ex_mem_out;
    assign reg_we = ~wb_flush & pass_in_r.is_wr_rd;

    assign csr_addr = pass_in_r.csr_addr;
    assign csr_data = pass_in_r.ex_mem_out;
    assign csr_we = ~wb_flush & pass_in_r.is_wr_csr;
    
`ifdef DIFF_TEST
    /* from mycpu */
    logic             cmt_valid;
    logic             cmt_cnt_inst;
    logic     [63:0]  cmt_timer_64;
    logic     [ 7:0]  cmt_inst_ld_en;
    logic     [31:0]  cmt_ld_paddr;
    logic     [31:0]  cmt_ld_vaddr;
    logic     [ 7:0]  cmt_inst_st_en;
    logic     [31:0]  cmt_st_paddr;
    logic     [31:0]  cmt_st_vaddr;
    logic     [31:0]  cmt_st_data;
    logic             cmt_csr_rstat_en;
    logic     [31:0]  cmt_csr_data;

    logic             cmt_wen;
    logic     [ 7:0]  cmt_wdest;
    logic     [31:0]  cmt_wdata;
    logic     [31:0]  cmt_pc;
    logic     [31:0]  cmt_inst;

    logic             cmt_excp_flush;
    logic             cmt_ertn;
    logic     [5:0]   cmt_csr_ecode;
    logic             cmt_tlbfill_en;
    logic     [4:0]   cmt_rand_index;
    logic     [10:0]  cmt_int_no;           // TODO: something may be wrong here

    logic             trap;
    logic     [ 7:0]  trap_code;
    logic     [63:0]  cycleCnt;
    logic     [63:0]  instrCnt;

    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
            {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
            {trap, trap_code, cycleCnt, instrCnt} <= 0;
            cmt_int_no <= '0;
        end else if (~trap) begin
            cmt_valid       <= ~wb_flush;
            cmt_cnt_inst    <= '0;                  // TODO
            cmt_timer_64    <= '0;                  // TODO
            cmt_inst_ld_en  <= pass_in_r.is_ld ? pass_in_r.byte_valid : 8'b0;
            cmt_ld_paddr    <= pass_in_r.pa;
            cmt_ld_vaddr    <= pass_in_r.va;
            cmt_inst_st_en  <= pass_in_r.is_st ? pass_in_r.byte_valid : 8'b0;
            cmt_st_paddr    <= pass_in_r.pa;
            cmt_st_vaddr    <= pass_in_r.va;
            cmt_st_data     <= pass_in_r.st_data;
            cmt_csr_rstat_en<= csr_we & csr_addr == 'h5;
            cmt_csr_data    <= csr_data;

            cmt_wen     <=  reg_we;
            cmt_wdest   <=  reg_idx;
            cmt_wdata   <=  reg_data;
            cmt_pc      <=  pass_in_r.pc;
            cmt_inst    <=  pass_in_r.inst;

            cmt_int_no <= excp_event_in.int_no;
            cmt_excp_flush  <= excp_event_in.valid;
            cmt_ertn        <= excp_event_in.is_eret;
            cmt_csr_ecode   <= excp_event_in.ecode;
            cmt_tlbfill_en  <= 0;                       // TODO
            cmt_rand_index  <= '0;

            trap            <= 0;
            trap_code       <= '0;
            cycleCnt        <= '0;
            instrCnt        <= '0;
        end
    end

    DifftestInstrCommit DifftestInstrCommit(
        .clock              (clk            ),
        .coreid             (0              ),
        .index              (0              ),
        .valid              (cmt_valid      ),
        .pc                 (cmt_pc         ),
        .instr              (cmt_inst       ),
        .skip               (0              ),
        .is_TLBFILL         (cmt_tlbfill_en ),
        .TLBFILL_index      (cmt_rand_index ),
        .is_CNTinst         (cmt_cnt_inst   ),
        .timer_64_value     (cmt_timer_64   ),
        .wen                (cmt_wen        ),
        .wdest              (cmt_wdest      ),
        .wdata              (cmt_wdata      ),
        .csr_rstat          (cmt_csr_rstat_en),
        .csr_data           (cmt_csr_data   )
    );

    DifftestExcpEvent DifftestExcpEvent(
        .clock              (clk            ),
        .coreid             (0              ),
        .excp_valid         (cmt_excp_flush ),
        .eret               (cmt_ertn       ),
        .intrNo             (cmt_int_no),
        .cause              (cmt_csr_ecode  ),
        .exceptionPC        (cmt_pc         ),
        .exceptionInst      (cmt_inst       )
    );

    DifftestTrapEvent DifftestTrapEvent(
        .clock              (clk            ),
        .coreid             (0              ),
        .valid              (trap           ),
        .code               (trap_code      ),
        .pc                 (cmt_pc         ),
        .cycleCnt           (cycleCnt       ),
        .instrCnt           (instrCnt       )
    );

    DifftestStoreEvent DifftestStoreEvent(
        .clock              (clk            ),
        .coreid             (0              ),
        .index              (0              ),
        .valid              (cmt_inst_st_en ),
        .storePAddr         (cmt_st_paddr   ),
        .storeVAddr         (cmt_st_vaddr   ),
        .storeData          (cmt_st_data    )
    );

    DifftestLoadEvent DifftestLoadEvent(
        .clock              (clk            ),
        .coreid             (0              ),
        .index              (0              ),
        .valid              (cmt_inst_ld_en ),
        .paddr              (cmt_ld_paddr   ),
        .vaddr              (cmt_ld_vaddr   )
    );
`endif

endmodule