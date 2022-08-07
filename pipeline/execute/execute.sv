`include "cpu_defs.svh"

module Execute (
    input logic clk, rst_n,

    /* branch resolved */
    output br_resolved_t br_resolved,

    /* forwarding */
    output forward_req_t fwd_req,

    /* rd csr (rdcntid) */
    input csr_t rd_csr,

    /* pipeline */
    input logic flush_i, stall_i,
    output logic stall_o,
    input decode_execute_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output execute_memory1_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    /* pipeline start */
    decode_execute_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    logic eu_stall;
    assign stall_o = stall_i | eu_stall;

    logic excp_valid;
    assign excp_valid = excp_pass_in_r.valid;

    logic valid_o;
    assign valid_o = pass_in_r.valid & ~stall_o;        // if ~valid_i, do not set exception valid

    logic valid_with_flush;           // only use this for output
    assign valid_with_flush = valid_o & ~flush_i;

    /* for this stage */
    logic eu_do;
    assign eu_do = pass_in_r.valid & ~excp_valid;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
            excp_pass_in_r.valid <= 1'b0;
        end else if(~stall_o | flush_i) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    /* out valid */
    assign pass_out.valid = valid_with_flush;
    
    /* exeption */
    always_comb begin
        excp_pass_out = excp_pass_in_r;
        excp_pass_out.valid = excp_pass_out.valid & valid_with_flush;
    end
    /* pipeline end */

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = (pass_in_r.rd != 5'b0) && pass_in_r.is_wr_rd && eu_do;
    assign fwd_req.idx = pass_in_r.rd;
    assign fwd_req.data_valid = ~(pass_in_r.is_mem & ~pass_in_r.is_store) && ~(pass_in_r.is_atomic && pass_in_r.is_store);
    always_comb begin
        if(pass_in_r.is_wr_rd_pc_plus4) fwd_req.data = pc_plus4;
        else                            fwd_req.data = ex_out;
    end

    /* execute stage */
    u32_t rj_forwarded, rkd_forwarded;
    always_comb begin
        if(pass_in_r.ex_req.valid && pass_in_r.rj == pass_in_r.ex_req.idx)  rj_forwarded = pass_in_r.ex_req.data;
        else                                                                rj_forwarded = pass_in_r.rj_data;
    end
    always_comb begin
        if(pass_in_r.ex_req.valid && pass_in_r.rkd == pass_in_r.ex_req.idx) rkd_forwarded = pass_in_r.ex_req.data;
        else                                                                rkd_forwarded = pass_in_r.rkd_data;
    end

    /* alu_out */
    u32_t alu_a, alu_b, alu_out;
    always_comb begin
        alu_a = '0;
        unique case(pass_in_r.alu_a_sel)
            RJ: alu_a = rj_forwarded;
            PC: alu_a = pass_in_r.pc;
            ZERO: alu_a = 32'b0;
            default: ;
        endcase
    end

    always_comb begin
        alu_b = '0;
        unique case(pass_in_r.alu_b_sel)
            RKD: alu_b = rkd_forwarded;
            IMM: alu_b = pass_in_r.imm;
            CSR: alu_b = pass_in_r.csr_data;
            CNT: alu_b = cnt_out;
            default: ;
        endcase
    end

    u32_t cnt_out;
`ifdef DIFF_TEST
    logic [63:0] cnt_out_64;
`endif
    StableCNT U_StableCNT (
        .clk, .rst_n,
        .rd_csr,
        .op(pass_in_r.cnt_op),
        .out(cnt_out)
`ifdef DIFF_TEST
        ,.out_64(cnt_out_64)
`endif
    );

    ALU U_ALU (
        .op(pass_in_r.alu_op),
        .a(alu_a),
        .b(alu_b),
        .out(alu_out)
    );

    /* bru_out */
    logic br_taken;
    BRU U_BRU (
        .op(pass_in_r.bru_op),
        .a(rj_forwarded),
        .b(rkd_forwarded),
        .taken(br_taken)
    );
    
    /* branch and btb fill */
    u32_t npc;
    assign npc = br_taken ? alu_out : pass_in_r.pc + 4;
    assign pass_out.bp_miss_wr_pc_req.valid = valid_o & pass_in_r.is_bru & pass_in_r.next.is_predict & (npc != pass_in_r.next.pc);
    assign pass_out.bp_miss_wr_pc_req.pc = npc;

    assign br_resolved.valid = valid_o & pass_in_r.is_bru;
    assign br_resolved.taken = br_taken;
    assign br_resolved.pc = pass_in_r.pc;
    assign br_resolved.target_pc = alu_out;

    /* mul */
    logic mul_en, mul_signed;
    u64_t mul_out;
    logic mul_done;
    Mul U_Mul (
        .clk, .rst_n,
        .is_flush(flush_i),
        .is_stall(stall_i),
        .a(rj_forwarded),
        .b(rkd_forwarded),
        .en(mul_en),
        .is_signed(mul_signed),
        .out(mul_out),
        .done(mul_done)
    );

    assign mul_en = pass_in_r.is_mul && !mul_done;
    always_comb begin
        mul_signed = 1'b0;
        case(pass_in_r.mul_op)
            LO: mul_signed = 1'b1;
            HI: mul_signed = 1'b1;
            HIU: mul_signed = 1'b0;
            default: //$stop;
                mul_signed = 1'b0;
        endcase
    end

    // div
    logic div_en, div_signed;
    u32_t div_quotient, div_remainder;
    logic div_done;
    Div U_Div (
        .clk, .rst_n,
        .is_flush(flush_i),
        .is_stall(stall_i),
        .dividend(rj_forwarded),
        .divisor(rkd_forwarded),
        .en(div_en),
        .is_signed(div_signed),
        .quotient(div_quotient),
        .remainder(div_remainder),
        .done(div_done)
    );

    assign div_en = pass_in_r.is_div && !div_done;
    always_comb begin
        div_signed = 1'b0;
        case(pass_in_r.div_op)
            QU: div_signed = 1'b0;
            RU: div_signed = 1'b0;
            Q: div_signed = 1'b1;
            R: div_signed = 1'b1;
            // full case
        endcase
    end

    /* exe ctrl */
    u32_t ex_out;
    always_comb begin
        ex_out = alu_out;
        unique case(pass_in_r.ex_out_sel)
            ALU: ex_out = alu_out;
            MUL:  begin
                unique case(pass_in_r.mul_op)
                    LO: ex_out = mul_out[31:0];
                    HI: ex_out = mul_out[63:32];
                    HIU: ex_out = mul_out[63:32];
                    default: //$stop;
                        ex_out = alu_out;
                endcase
            end
            DIV:   begin
                unique case(pass_in_r.div_op)
                    Q: ex_out = div_quotient;
                    QU: ex_out = div_quotient;
                    R: ex_out = div_remainder;
                    RU: ex_out = div_remainder;
                    // full case
                endcase
            end
            default: ;
        endcase
    end

    /* to ctrl */
    assign eu_stall = ((pass_in_r.is_mul) && !mul_done) || ((pass_in_r.is_div) && !div_done);
    // TODO: div   || ((pass_in_r.is_div) && !div_done);

    /* csr */
    u32_t csr_masked;
    assign csr_masked = (rj_forwarded & rkd_forwarded) | (~rj_forwarded & pass_in_r.csr_data);

    u32_t pc_plus4;
    assign pc_plus4 = pass_in_r.pc + 4;

    /* out to next stage */
    assign pass_out.ex_out = ex_out;
    assign pass_out.pc_plus4 = pc_plus4;
    assign pass_out.invtlb_asid = rj_forwarded[9:0];

    assign pass_out.csr_data = pass_in_r.is_mask_csr ? csr_masked : rkd_forwarded;
    assign pass_out.rkd_data = rkd_forwarded;

    `PASS(pc);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(rd);
    `PASS(is_wr_csr);
    `PASS(csr_addr);
    `PASS(is_atomic);
    `PASS(is_mem);
    `PASS(is_store);
    `PASS(is_signed);
    `PASS(byte_type);
    `PASS(is_cac);
    `PASS(is_ertn);
    `PASS(tlb_op);
    `PASS(is_idle);

    `PASS(is_modify_state);

`ifdef DIFF_TEST
    `PASS(inst);
    `PASS(is_modify_csr);
    `PASS(csr);

    `PASS(is_rdcnt);
    assign pass_out.cntval_64 = cnt_out_64;
`endif

endmodule