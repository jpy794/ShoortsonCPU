`include "cpu_defs.svh"

module Execute (
    input logic clk, rst_n,

    /* ctrl */
    output logic bp_miss_flush,

    /* TODO: branch resolved */
    output wr_pc_req_t wr_pc_req,
    output br_resolved_t br_resolved,

    /* load use */
    output load_use_t ld_use,

    /* forwarding */
    input forward_req_t mem1_req, mem2_req,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,
    input decode_execute_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output execute_memory1_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    /* pipeline regster */
    decode_execute_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic eu_stall;
    logic rdy_out;
    logic ex_flush, ex_stall;
    assign ex_flush = flush | ~pass_in_r.valid;
    assign ex_stall = ~next_rdy_in | eu_stall;

    assign rdy_in = ex_flush | ~ex_stall;
    assign rdy_out = ~ex_flush & ~ex_stall;        // only use this for pass_out.valid

    /* execute stage */
    u32_t rj_forwarded, rkd_forwarded;
    always_comb begin
        if(mem1_req.valid && pass_in_r.rj == mem1_req.idx)          rj_forwarded = mem1_req.data;
        else if(mem2_req.valid && pass_in_r.rj == mem2_req.idx)     rj_forwarded = mem2_req.data;
        else                                                        rj_forwarded = pass_in_r.rj_data;
    end
    always_comb begin
        if(mem1_req.valid && pass_in_r.rkd == mem1_req.idx)         rkd_forwarded = mem1_req.data;
        else if(mem2_req.valid && pass_in_r.rkd == mem2_req.idx)    rkd_forwarded = mem2_req.data;
        else                                                        rkd_forwarded = pass_in_r.rkd_data;
    end

    /* alu_out */
    u32_t alu_a, alu_b, alu_out;
    always_comb begin
        alu_a = '0;
        unique case(pass_in_r.alu_a_sel)
            RJ: alu_a = pass_in_r.rj_data;
            PC: alu_a = pass_in_r.pc;
            ZERO: alu_a = 32'b0;
            default: $stop;
        endcase
    end

    always_comb begin
        alu_b = '0;
        unique case(pass_in_r.alu_b_sel)
            RKD: alu_b = pass_in_r.rkd_data;
            IMM: alu_b = pass_in_r.imm;
            default: //$stop;
                alu_b = '0;
        endcase
    end

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
    assign wr_pc_req.valid = ~ex_flush & pass_in_r.is_bru & pass_in_r.is_pred & (npc != pass_in_r.btb_pre);
    assign wr_pc_req.pc = npc;

    assign br_resolved.valid = ~ex_flush & pass_in_r.is_bru;
    assign br_resolved.taken = br_taken;
    assign br_resolved.target_pc = alu_out;

    /* mul */
    logic mul_en, mul_signed;
    u64_t mul_out;
    logic mul_done;
    Mul U_Mul (
        .clk, .rst_n,
        .is_flush(ex_flush),
        .is_stall(~next_rdy_in),
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
        .is_flush(ex_flush),
        .is_stall(~next_rdy_in),
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

    /* csr */
    u32_t csr_masked;
    assign csr_masked = (pass_in_r.rj_data & pass_in_r.rkd_data) | (~pass_in_r.rj_data & pass_in_r.csr_data);

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
            CSR: begin
                if(pass_in_r.is_mask_csr) ex_out = csr_masked;
                else            ex_out = pass_in_r.rkd_data;
            end
            default: ex_out = alu_out;
        endcase
    end

    /* load use */
    assign ld_use.idx = pass_in_r.rd;
    assign ld_use.valid = pass_in_r.is_mem & ~pass_in_r.is_store & ~ex_flush;

    /* to ctrl */
    assign eu_stall = ((pass_in_r.is_mul) && !mul_done) || ((pass_in_r.is_div) && !div_done);
    // TODO: div   || ((pass_in_r.is_div) && !div_done);
    assign bp_miss_flush = wr_pc_req.valid;


    /* out to next stage */
    assign pass_out.valid = rdy_out;
    assign pass_out.ex_out = ex_out;
    assign pass_out.invtlb_asid = pass_in_r.rj_data[9:0];
    assign pass_out.pc_plus4 = pass_in_r.pc + 4;

    `PASS(pc);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(rd);
    `PASS(is_wr_csr);
    `PASS(csr_addr);
    `PASS(is_mem);
    `PASS(is_store);
    `PASS(is_signed);
    `PASS(byte_type);
    `PASS(rkd_data);
    `PASS(is_cac);
    `PASS(is_tlb);
    `PASS(tlb_op);

    /* no exception in ex */
    assign excp_pass_out = excp_pass_in_r;

`ifdef DIFF_TEST
    `PASS(inst);
`endif

endmodule