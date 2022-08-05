`include "cpu_defs.svh"

module Memory1 (
    input clk, rst_n,

    /* branch taken */
    output logic bp_miss_flush,
    output wr_pc_req_t wr_pc_req,

    /* forward */
    output forward_req_t fwd_req,

    /* from csr */
    input csr_t rd_csr,

    /* to csr */
    output csr_addr_t csr_addr,
    output logic csr_we,
    output u32_t csr_data,
    output logic set_llbit,
    output logic clr_llbit,

    /* modify state inst */    
    output modify_state_flush,
    output logic is_ertn,

    /* tlb */
    input tlb_entry_t tlb_entrys[TLB_ENTRY_NUM],

    output tlb_op_req_t tlb_req,
`ifdef DIFF_TEST
    input tlb_idx_t tlb_wr_idx,
`endif

    /* to dcache */
    output dcache_req_t dcache_req,
    output cache_op_t dcache_op,
    output logic [11:0] dcache_idx,
    output u32_t dcache_pa,
    output logic dcache_is_cached,
    output byte_type_t dcache_byte_type,
    output u32_t wr_dcache_data,
    input logic dcache_ready,

    /* icache op */
    output cache_op_t icache_op,
    output logic [11:0] icache_op_idx,
    output phy_t icache_op_pa,
    input logic icache_op_ready,

    /* pipeline */
    output logic set_idle_stall,
    input logic flush_i, stall_i,
    output logic stall_o,
    input execute_memory1_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output memory1_memory2_pass_t pass_out,

    output excp_req_t excp_req,
    input logic int_valid,
`ifdef DIFF_TEST
    ,input excp_event_t excp_event_in
`endif
);

    /* pipeline start */
    execute_memory1_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    logic is_atomic, is_store, is_mem, is_cac;
    assign is_mem = pass_in_r.is_mem;
    assign is_cac = pass_in_r.is_cac;
    assign is_atomic = pass_in_r.is_atomic;
    assign is_store = pass_in_r.is_store;

    logic icache_op_busy_stall;
    assign icache_op_busy_stall = eu_do & is_icac & ~icache_op_ready;

    logic dcache_busy_stall;
    assign dcache_busy_stall = eu_do & is_mem & ~dcache_ready;
    
    assign stall_o = stall_i | dcache_busy_stall | icache_op_busy_stall;

    logic excp_valid;
    assign excp_valid = addr_excp.valid | excp_pass_in_r.valid;

    logic valid_o;
    assign valid_o = pass_in_r.valid & ~stall_o;        // if ~valid_i, do not set exception valid

    logic valid_with_flush;           // only use this for output
    assign valid_with_flush = valid_o & ~flush_i;

    /* for this stage */
    logic chk_excp;
    assign chk_excp = pass_in_r.valid & (is_mem | is_srch_inv);

    logic eu_do;
    assign eu_do = pass_in_r.valid & ~excp_valid & ~int_valid;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
            excp_pass_in_r.valid <= 1'b0;
        end else if(~stall_o | flush_i) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    /* out */
    assign pass_out.dcache_wait_resp = ~is_store & is_mem & eu_do;

    /* out valid */
    assign pass_out.valid = valid_with_flush;
    
    /* exeption */
    excp_pass_t excp_pass;
    always_comb begin
        if(excp_pass_in_r.valid) excp_pass = excp_pass_in_r;
        else                     excp_pass = addr_excp;

        excp_req.valid = valid_o;
        excp_req.epc = pass_in_r.pc;
        excp_req.excp_pass = excp_pass;
        excp_req.excp_pass.valid = excp_valid & valid_o;
    end
    /* pipeline end */

    /* branch taken write pc request */
    wr_pc_req_t bp_miss_req;
    assign bp_miss_req.valid = pass_in_r.bp_miss_wr_pc_req.valid & eu_do;
    assign bp_miss_req.pc = pass_in_r.bp_miss_wr_pc_req.pc;
    assign bp_miss_flush = bp_miss_req.valid;

    /* modify state inst write pc req */
    wr_pc_req_t modify_state_req;
    assign modify_state_req.valid = pass_in_r.is_modify_state & eu_do;
    assign modify_state_req.pc = pass_in_r.is_ertn ? rd_csr.era : pass_in_r.pc_plus4;
    assign modify_state_flush = modify_state_req.valid;

    assign is_ertn = eu_do & pass_in_r.is_ertn;

    always_comb begin
        wr_pc_req = bp_miss_req;
        unique case(1'b1)
            bp_miss_req.valid:      wr_pc_req = bp_miss_req;
            modify_state_req.valid: wr_pc_req = modify_state_req;
            default: ;
        endcase
    end

    assign csr_addr = pass_in_r.csr_addr;
    assign csr_data = pass_in_r.csr_data;
    assign csr_we = eu_do & pass_in_r.is_wr_csr;

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = (pass_in_r.rd != 5'b0) && pass_in_r.is_wr_rd && eu_do;
    assign fwd_req.idx = pass_in_r.rd;
    assign fwd_req.data_valid = ~(pass_in_r.is_mem & ~pass_in_r.is_store);
    always_comb begin
        if(pass_in_r.is_wr_rd_pc_plus4) fwd_req.data = pass_in_r.pc_plus4;
        else                            fwd_req.data = pass_in_r.ex_out;
    end

    /* tlb op */
    always_comb begin
        tlb_req.tlb_op = eu_do ? pass_in_r.tlb_op : TLBNOP;
        tlb_req.invtlb_op = pass_in_r.rd;
        tlb_req.invtlb_asid = pass_in_r.invtlb_asid;
        tlb_req.invtlb_vppn = pass_in_r.rkd_data[31:13];
    end

    /* cacop */
    logic [4:0] cacop_code;
    assign cacop_code = pass_in_r.rd;

    logic is_icac, is_dcac, is_srch_inv;
    always_comb begin
        is_icac = is_cac && (cacop_code[2:0] == 2'b00);
        is_dcac = is_cac && (cacop_code[2:0] == 2'b01);
        is_srch_inv = is_cac && (cacop_code[4:3] == CAC_SRCH_INV);
    end

    cache_op_t cache_op;
    assign cache_op = cacop_code[4:3];
    /* cacop end */

    // to icache
    assign icache_op_idx = pass_in_r.ex_out[11:0];
    assign icache_op_pa = pa;
    always_comb begin
        icache_op = CAC_NOP;
        if(eu_do & is_icac) begin
            icache_op = cache_op;
        end
    end

    /* atomic */
    logic llbit;
    assign llbit = rd_csr.llbctl.r_rollb;
    assign set_llbit = eu_do && is_atomic && ~is_store;
    assign clr_llbit = ~stall_o && eu_do && is_atomic && is_store;      // consider stall to make sure we do not read a wrong llbit

    /* idle */
    assign set_idle_stall = eu_do & pass_in_r.is_idle;

    /* memory1 stage */

    mat_t mat;
    phy_t pa;
    excp_pass_t addr_excp;
    AddrTrans U_AddrTrans (
        .en(chk_excp),
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
        dcache_req = DCAC_NOP;
        if(eu_do & is_mem) begin
            if(pass_in_r.is_store) begin
                if((is_atomic & llbit) | ~is_atomic)
                    dcache_req = DCAC_ST;
            end else begin
                dcache_req = DCAC_LD;
            end
        end
        // TODO: ll sc
    end

    /* dcache op */
    always_comb begin
        dcache_op = CAC_NOP;
        if(eu_do & is_dcac) begin
            dcache_op = cache_op;
        end
    end

    u32_t mem_in;
    always_comb begin
        mem_in = pass_in_r.rkd_data;
        unique case(pass_in_r.byte_type)
            BYTE: begin
                unique case(pa[1:0])
                    2'b00:  mem_in[0+:8] = pass_in_r.rkd_data[7:0];
                    2'b01:  mem_in[8+:8] = pass_in_r.rkd_data[7:0];
                    2'b10:  mem_in[16+:8] = pass_in_r.rkd_data[7:0];
                    2'b11:  mem_in[24+:8] = pass_in_r.rkd_data[7:0];
                    // full case
                endcase
            end
            HALF_WORD: begin
                unique case(pa[1])
                    1'b0: mem_in[0+:16] = pass_in_r.rkd_data[15:0];
                    1'b1: mem_in[16+:16] = pass_in_r.rkd_data[15:0];
                endcase
            end
            WORD:         mem_in = pass_in_r.rkd_data;
            default: ;
        endcase
    end

    assign wr_dcache_data = mem_in;

    /* out to next stage */
    assign pass_out.byte_en = pass_in_r.ex_out[1:0];
    assign pass_out.ex_out = is_atomic & is_store ? {31'b0, llbit} : pass_in_r.ex_out;

    `PASS(pc);
    `PASS(is_atomic);
    `PASS(is_mem);
    `PASS(is_store);
    `PASS(is_signed);
    `PASS(byte_type);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(pc_plus4);
    `PASS(rd);

`ifdef DIFF_TEST
    `PASS(is_wr_csr);
    `PASS(csr_addr);
    `PASS(csr_data);
    `PASS(inst);
    `PASS(is_modify_csr);
    `PASS(csr);

    `PASS(is_rdcnt);
    `PASS(cntval_64);

    assign pass_out.excp_event = excp_event_in;

    assign pass_out.is_tlbfill = (pass_in_r.tlb_op == TLBFILL);
    assign pass_out.tlb_wr_idx = tlb_wr_idx;

    assign pass_out.is_ertn = is_ertn;

    assign pass_out.is_ld = ~stall_o & eu_do & pass_in_r.is_mem & ~pass_in_r.is_store;
    assign pass_out.is_st = ~stall_o & eu_do & pass_in_r.is_mem & pass_in_r.is_store;
    assign pass_out.pa = pa;
    assign pass_out.va = pass_in_r.ex_out;

    u32_t mem_in_diff;
    assign pass_out.st_data = mem_in_diff;
    always_comb begin
        mem_in_diff = '0;
        unique case(pass_in_r.byte_type)
            BYTE: begin
                unique case(pa[1:0])
                    2'b00:  mem_in_diff[0+:8] = pass_in_r.rkd_data[7:0];
                    2'b01:  mem_in_diff[8+:8] = pass_in_r.rkd_data[7:0];
                    2'b10:  mem_in_diff[16+:8] = pass_in_r.rkd_data[7:0];
                    2'b11:  mem_in_diff[24+:8] = pass_in_r.rkd_data[7:0];
                    // full case
                endcase
            end
            HALF_WORD: begin
                unique case(pa[1])
                    1'b0: mem_in_diff[0+:16] = pass_in_r.rkd_data[15:0];
                    1'b1: mem_in_diff[16+:16] = pass_in_r.rkd_data[15:0];
                endcase
            end
            WORD:         mem_in_diff = pass_in_r.rkd_data;
            default: ;
        endcase
    end

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