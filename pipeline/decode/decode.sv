`include "cpu_defs.svh"

// TODO: hazard detect

module Decode (
    input logic clk, rst_n,

    /* from csr */
    output csr_addr_t csr_addr_out,
    input u32_t csr_data,

    /* from regfile */
    output reg_idx_t rj_out, rkd_out,
    input u32_t rj_data, rkd_data,

    /* load use */
    input load_use_t ex_ld_use,
    input load_use_t mem1_ld_use,

    /* ctrl */
    output logic load_use_stall,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,
    input fetch2_decode_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output decode_execute_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    fetch2_decode_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic id_flush;
    assign id_flush = is_flush | pass_in_r.is_flush;

    u32_t inst;
    assign inst = pass_in_r.inst;

    /* decode stage */
    logic inst_add_w;
    logic inst_sub_w;
    logic inst_slt;
    logic inst_sltu;
    logic inst_nor;
    logic inst_and;
    logic inst_or;
    logic inst_xor;
    logic inst_lu12i_w;
    logic inst_addi_w;
    logic inst_slti;
    logic inst_sltui;
    logic inst_pcaddu12i;
    logic inst_andi;
    logic inst_ori;
    logic inst_xori;
    logic inst_mul_w;
    logic inst_mulh_w;
    logic inst_mulh_wu;
    logic inst_div_w;
    logic inst_mod_w;
    logic inst_div_wu;
    logic inst_mod_wu;

    logic inst_slli_w;
    logic inst_srli_w;
    logic inst_srai_w;
    logic inst_sll_w;
    logic inst_srl_w;
    logic inst_sra_w;

    logic inst_jirl;
    logic inst_b;
    logic inst_bl;
    logic inst_beq;
    logic inst_bne;
    logic inst_blt;
    logic inst_bge;
    logic inst_bltu;
    logic inst_bgeu;

    logic inst_ll_w;
    logic inst_sc_w;
    logic inst_ld_b;
    logic inst_ld_bu;
    logic inst_ld_h;
    logic inst_ld_hu;
    logic inst_ld_w;
    logic inst_st_b;
    logic inst_st_h;
    logic inst_st_w;

    logic inst_syscall;
    logic inst_break;
    logic inst_csrrd;
    logic inst_csrwr;
    logic inst_csrxchg;
    logic inst_ertn;

    logic inst_rdcntid_w;
    logic inst_rdcntvl_w;
    logic inst_rdcntvh_w;
    logic inst_idle;

    logic inst_tlbsrch;
    logic inst_tlbrd;
    logic inst_tlbwr;
    logic inst_tlbfill;
    logic inst_invtlb;

    logic inst_cacop;
    logic inst_preld;
    logic inst_dbar;
    logic inst_ibar;

    logic bad_inst;

    logic is_mem;
    logic is_store;
    assign is_mem = inst_ld_b  |
                    inst_ld_bu |
                    inst_ld_h  |
                    inst_ld_hu |
                    inst_ld_w  |
                    inst_st_b  |
                    inst_st_h  |
                    inst_st_w  ;
    assign is_store = inst_st_b |
                      inst_st_h |
                      inst_st_w ;

    logic is_mem_signed;
    assign is_mem_signed = inst_ld_b |
                           inst_ld_h ;

    byte_type_t mem_byte_type;
    assign mem_byte_type = inst[23:22];

    logic is_br_off;
    assign is_br_off =  inst_b    |
                        inst_bl   |
                        inst_beq  |
                        inst_bne  |
                        inst_blt  |
                        inst_bge  |
                        inst_bltu |
                        inst_bgeu ;
    logic is_br_reg;
    assign is_br_reg = inst_jirl ;

    logic is_br;
    assign is_br = is_br_off | is_br_reg;

    logic is_br_wb;
    assign is_br_wb = inst_jirl |
                      inst_beq  |
                      inst_bne  |
                      inst_blt  |
                      inst_bge  |
                      inst_bltu |
                      inst_bgeu ;

    logic is_mul;
    assign is_mul = inst_mul_w   |
                    inst_mulh_w  |
                    inst_mulh_wu ;
    logic is_div;
    assign is_div = inst_div_w  |
                    inst_div_wu |
                    inst_mod_w  |
                    inst_mod_wu ;

    logic is_csr;       // NOTE: it's directly generated by case
    assign inst_csrrd = is_csr && (rj == 5'b0);
    assign inst_csrwr = is_csr && (rj == 5'b1);
    assign inst_csrxchg = is_csr & ~inst_csrrd & ~inst_csrwr;

    logic is_tlb;
    assign is_tlb = inst_tlbsrch |
                    inst_tlbrd   |
                    inst_tlbwr   |
                    inst_tlbfill ;

    logic is_eret;
    assign is_eret = inst_ertn;

    logic is_alu_add;
    assign is_alu_add = inst_add_w |
                        inst_addi_w |
                        is_mem |
                        is_br |
                        inst_pcaddu12i |
                        inst_lu12i_w |
                        inst_cacop ;

    alu_op_t alu_op;
    always_comb begin
        alu_op = ADD;
        unique case(1'b1)
            is_alu_add :                alu_op = ADD;
            inst_sub_w :                alu_op = SUB;
            inst_slt | inst_slti :      alu_op = SLT;
            inst_sltu | inst_sltui :    alu_op = SLTU;
            inst_nor :                  alu_op = NOR;
            inst_and | inst_andi:       alu_op = AND;
            inst_or | inst_ori:         alu_op = OR;
            inst_xor | inst_xori :      alu_op = XOR;
            inst_sll_w | inst_slli_w :  alu_op = SLL;
            inst_srl_w | inst_srli_w :  alu_op = SRL;
            inst_sra_w | inst_srai_w :  alu_op = SRA;
            default: alu_op = ADD;
        endcase
    end

    logic is_alu;
    assign is_alu =   inst_add_w |
                      inst_sub_w |
                      inst_slt   |
                      inst_sltu  |
                      inst_nor   |
                      inst_and   |
                      inst_or    |
                      inst_xor   |
                      inst_sll_w |
                      inst_srl_w |
                      inst_sra_w |
                      inst_slli_w |
                      inst_srli_w |
                      inst_srai_w |
                      inst_slti   |
                      inst_sltui  |
                      inst_addi_w |
                      inst_andi   |
                      inst_ori    |
                      inst_xori   ;

    logic is_wr_rd;
    assign is_wr_rd = is_store |
                      is_mul   |
                      is_div   |
                      is_csr   |
                      is_alu   |
                      inst_pcaddu12i |
                      inst_lu12i_w   |
                      is_br_wb       ;

    logic is_rd_as_rk;
    assign is_rd_as_rk = is_store |
                         inst_beq |
                         inst_bne |
                         inst_blt |
                         inst_bge |
                         inst_bltu |
                         inst_bgeu ;

    reg_idx_t rj, rkd, rd;
    assign rj = inst[9:5];
    assign rd = inst[4:0];
    assign rkd = is_rd_as_rk ? rd : inst[14:10];

    logic alu_a_rj, alu_a_pc, alu_a_zero;
    assign alu_a_pc = is_br_off     |
                      inst_pcaddu12i;
    assign alu_a_zero = inst_lu12i_w;


    logic alu_b_rkd, alu_b_imm;
    assign alu_b_imm = is_uimm5  |
                       is_simm12 |
                       is_uimm12 |
                       is_simm20 |
                       is_simm14 |
                       is_simm16 |
                       is_simm26 ;
    // TODO: impl this
    logic [14:0] syscall_break_code;
    assign syscall_break_code = inst[14:0];

    logic is_uimm5;
    logic [4:0] uimm5;
    assign uimm5 = inst[14:10];
    assign is_uimm5 = inst_slli_w |
                      inst_srli_w |
                      inst_srai_w ;

    logic is_simm12;
    logic [11:0] simm12;
    assign simm12 = inst[21:10];
    assign is_simm12 = inst_slti   |
                       inst_sltui  |
                       inst_addi_w |
                       inst_cacop  |
                       is_mem      ;
            
    logic is_uimm12;
    logic [11:0] uimm12;
    assign uimm12 = inst[21:10];
    assign is_uimm12 = inst_andi |
                       inst_ori  |
                       inst_xori ;

    logic is_simm16;
    logic [15:0] simm16;
    assign simm16 = inst[25:10];
    assign is_simm16 = inst_jirl |
                       inst_beq  |
                       inst_bne  |
                       inst_blt  |
                       inst_bge  |
                       inst_bltu |
                       inst_bgeu ;
    
    logic is_simm26;
    logic [25:0] simm26;
    assign simm26 = {inst[9:0], inst[25:10]};
    assign is_simm26 = inst_b  |
                       inst_bl ;

    logic is_simm20;
    logic [19:0] simm20;
    assign simm20 = inst[24:5];
    assign is_simm20 = inst_lu12i_w   |
                       inst_pcaddu12i ;

    logic is_simm14;
    logic [13:0] simm14;
    assign simm14 = inst[23:10];
    assign is_simm14 = inst_ll_w |
                       inst_sc_w ;

    u32_t imm;
    always_comb begin
        imm = '0;
        unique case(1'b1)
            is_uimm5:  imm = {27'b0, uimm5};
            is_uimm12: imm = {20'b0, uimm12};
            is_simm12: imm = {{20{simm12[11]}}, simm12};
            is_simm14: imm = {{18{simm14[13]}}, simm14};
            is_simm16: imm = {{16{simm16[15]}}, simm16};
            is_simm20: imm = {{12{simm20[19]}}, simm20};
            is_simm26: imm = {{6{simm26[25]}}, simm26};
            default: imm = '0;
        endcase
    end

    // we only need csr[8:0]
    csr_addr_t csr_addr;
    assign csr_addr = inst[18:10];

    bru_op_t bru_op;
    assign bru_op = inst[29:26];

    always_comb begin
        inst_add_w = 1'b0;
        inst_sub_w = 1'b0;
        inst_slt = 1'b0;
        inst_sltu = 1'b0;
        inst_nor = 1'b0;
        inst_and = 1'b0;
        inst_or = 1'b0;
        inst_xor = 1'b0;
        inst_lu12i_w = 1'b0;
        inst_addi_w = 1'b0;
        inst_slti = 1'b0;
        inst_sltui = 1'b0;
        inst_pcaddu12i = 1'b0;
        inst_andi = 1'b0;
        inst_ori = 1'b0;
        inst_xori = 1'b0;
        inst_mul_w = 1'b0;
        inst_mulh_w = 1'b0;
        inst_mulh_wu = 1'b0;
        inst_div_w = 1'b0;
        inst_mod_w = 1'b0;
        inst_div_wu = 1'b0;
        inst_mod_wu = 1'b0;

        inst_slli_w = 1'b0;
        inst_srli_w = 1'b0;
        inst_srai_w = 1'b0;
        inst_sll_w = 1'b0;
        inst_srl_w = 1'b0;
        inst_sra_w = 1'b0;

        inst_jirl = 1'b0;
        inst_b = 1'b0;
        inst_bl = 1'b0;
        inst_beq = 1'b0;
        inst_bne = 1'b0;
        inst_blt = 1'b0;
        inst_bge = 1'b0;
        inst_bltu = 1'b0;
        inst_bgeu = 1'b0;

        inst_ll_w = 1'b0;
        inst_sc_w = 1'b0;
        inst_ld_b = 1'b0;
        inst_ld_bu = 1'b0;
        inst_ld_h = 1'b0;
        inst_ld_hu = 1'b0;
        inst_ld_w = 1'b0;
        inst_st_b = 1'b0;
        inst_st_h = 1'b0;
        inst_st_w = 1'b0;

        inst_syscall = 1'b0;
        inst_break = 1'b0;
        inst_csrrd = 1'b0;
        inst_csrwr = 1'b0;
        inst_csrxchg = 1'b0;
        inst_ertn = 1'b0;

        inst_rdcntid_w = 1'b0;
        inst_rdcntvl_w = 1'b0;
        inst_rdcntvh_w = 1'b0;
        inst_idle = 1'b0;

        inst_tlbsrch = 1'b0;
        inst_tlbrd = 1'b0;
        inst_tlbwr = 1'b0;
        inst_tlbfill = 1'b0;
        inst_invtlb = 1'b0;

        inst_cacop = 1'b0;
        inst_preld = 1'b0;
        inst_dbar = 1'b0;
        inst_ibar = 1'b0;

        bad_inst = 1'b0;
        is_csr = 1'b0;

        unique casez(inst)
            // TODO: rdcnt
            {17'b0000_0000_0001_0000_0, {15{1'b?}}}: inst_add_w = 1'b1;
            {17'b0000_0000_0001_0001_0, {15{1'b?}}}: inst_sub_w = 1'b1;
            {17'b0000_0000_0001_0010_0, {15{1'b?}}}: inst_slt = 1'b1;
            {17'b0000_0000_0001_0010_1, {15{1'b?}}}: inst_sltu = 1'b1;
            {17'b0000_0000_0001_0100_0, {15{1'b?}}}: inst_nor = 1'b1;
            {17'b0000_0000_0001_0101_1, {15{1'b?}}}: inst_and = 1'b1;
            {17'b0000_0000_0001_0101_0, {15{1'b?}}}: inst_or = 1'b1;
            {17'b0000_0000_0001_0101_1, {15{1'b?}}}: inst_xor = 1'b1;
            {17'b0000_0000_0001_0111_0, {15{1'b?}}}: inst_sll_w = 1'b1;
            {17'b0000_0000_0001_0001_0, {15{1'b?}}}: inst_srl_w = 1'b1;
            {17'b0000_0000_0001_1000_0, {15{1'b?}}}: inst_sra_w = 1'b1;
            {17'b0000_0000_0001_1100_0, {15{1'b?}}}: inst_mul_w = 1'b1;
            {17'b0000_0000_0001_1100_1, {15{1'b?}}}: inst_mulh_w = 1'b1;
            {17'b0000_0000_0001_1101_0, {15{1'b?}}}: inst_mulh_wu = 1'b1;
            {17'b0000_0000_0010_0000_0, {15{1'b?}}}: inst_div_w = 1'b1;
            {17'b0000_0000_0010_0000_1, {15{1'b?}}}: inst_mod_w = 1'b1;
            {17'b0000_0000_0010_0001_0, {15{1'b?}}}: inst_div_wu = 1'b1;
            {17'b0000_0000_0010_0001_1, {15{1'b?}}}: inst_mod_wu = 1'b1;
            {17'b0000_0000_0010_1010_0, {15{1'b?}}}: inst_break = 1'b1;
            {17'b0000_0000_0010_1011_0, {15{1'b?}}}: inst_syscall = 1'b1;
            {17'b0000_0000_0100_0000_1, {15{1'b?}}}: inst_slli_w = 1'b1;
            {17'b0000_0000_0100_0100_1, {15{1'b?}}}: inst_srli_w = 1'b1;
            {17'b0000_0000_0100_1000_1, {15{1'b?}}}: inst_srai_w = 1'b1;

            {10'b0000_0010_00, {22{1'b?}}}: inst_slti = 1'b1;
            {10'b0000_0010_01, {22{1'b?}}}: inst_sltui = 1'b1;
            {10'b0000_0010_10, {22{1'b?}}}: inst_addi_w = 1'b1;
            {10'b0000_0011_01, {22{1'b?}}}: inst_andi = 1'b1;
            {10'b0000_0011_10, {22{1'b?}}}: inst_ori = 1'b1;
            {10'b0000_0011_11, {22{1'b?}}}: inst_xori = 1'b1;

            {8'b0000_0100, {24{1'b?}}}: is_csr = 1'b1;

            {10'b0000_0110_00, {22{1'b?}}}: inst_cacop = 1'b1;

            {32'b0000011001001000001010_00000_00000}: inst_tlbsrch = 1'b1;
            {32'b0000011001001000001011_00000_00000}: inst_tlbrd = 1'b1;
            {32'b0000011001001000001100_00000_00000}: inst_tlbwr = 1'b1;
            {32'b0000011001001000001101_00000_00000}: inst_tlbfill = 1'b1;
            {32'b0000011001001000001110_00000_00000}: inst_ertn = 1'b1;

            {17'b00000110010010001, {15{1'b?}}}: inst_idle = 1'b1;
            {17'b00000110010010011, {15{1'b?}}}: inst_invtlb = 1'b1;

            {7'b0001010, {25{1'b?}}}: inst_lu12i_w = 1'b1;
            {7'b0001110, {25{1'b?}}}: inst_pcaddu12i = 1'b1;

            {8'b00100000, {24{1'b?}}}: inst_ll_w = 1'b1;
            {8'b00100001, {24{1'b?}}}: inst_sc_w = 1'b1;
            {10'b0010100000, {22{1'b?}}}: inst_ld_b = 1'b1;
            {10'b0010100001, {22{1'b?}}}: inst_ld_h = 1'b1;
            {10'b0010100010, {22{1'b?}}}: inst_ld_w = 1'b1;
            {10'b0010100100, {22{1'b?}}}: inst_st_b = 1'b1;
            {10'b0010100101, {22{1'b?}}}: inst_st_h = 1'b1;
            {10'b0010100110, {22{1'b?}}}: inst_st_w = 1'b1;
            {10'b0010101000, {22{1'b?}}}: inst_ld_bu = 1'b1;
            {10'b0010101001, {22{1'b?}}}: inst_ld_hu = 1'b1;

            {10'b0010101011, {22{1'b?}}}: inst_preld = 1'b1;

            {17'b00111000011100100, {15{1'b?}}}: inst_dbar = 1'b1;
            {17'b00111000011100101, {15{1'b?}}}: inst_ibar = 1'b1;

            {6'b010011, {26{1'b?}}}: inst_jirl = 1'b1;
            {6'b010100, {26{1'b?}}}: inst_b = 1'b1;
            {6'b010101, {26{1'b?}}}: inst_bl = 1'b1;
            {6'b010110, {26{1'b?}}}: inst_beq = 1'b1;
            {6'b010111, {26{1'b?}}}: inst_bne = 1'b1;
            {6'b011000, {26{1'b?}}}: inst_blt = 1'b1;
            {6'b011001, {26{1'b?}}}: inst_bge = 1'b1;
            {6'b011010, {26{1'b?}}}: inst_bltu = 1'b1;
            {6'b011011, {26{1'b?}}}: inst_bgeu = 1'b1;

            default: bad_inst = 1'b1;
        endcase
    end

    /* out */
    assign rj_out = rj;
    assign rkd_out = rkd;
    assign csr_addr_out = csr_addr;

    /* load use stall */
    // TODO: rdcnt
    logic is_use_rj;
    assign is_use_rj = is_alu       |
                       is_mem       |
                       inst_jirl    |
                       is_mul       |
                       is_div       |
                       inst_cacop   |
                       inst_invtlb  |
                       inst_csrxchg ;
    logic is_use_rkd;
    assign is_use_rkd = inst_invtlb |
                        inst_add_w  |
                        inst_sub_w  |
                        inst_slt    |
                        inst_sltu   |
                        inst_nor    |
                        inst_and    |
                        inst_or     |
                        inst_xor    |
                        inst_sll_w  |
                        inst_srl_w  |
                        inst_sra_w  |
                        is_mul      |
                        is_div      |
                        is_mem      |
                        is_br_off   ;

    always_comb begin
        load_use_stall = 1'b0;
        if(ex_ld_use.valid) begin
            if(rj == ex_ld_use.idx && is_use_rj
            || rkd == ex_ld_use.idx && is_use_rkd) begin
                load_use_stall = 1'b1;
            end
        end
        if(mem1_ld_use.valid) begin
            if(rj == mem1_ld_use.idx && is_use_rj
            || rkd == mem1_ld_use.idx && is_use_rkd) begin
                load_use_stall = 1'b1;
            end
        end
    end


    /* out to next stage */
    assign pass_out.is_flush = id_flush | load_use_stall;
    assign pass_out.is_mul = is_mul;
    assign pass_out.is_div = is_div;
    assign pass_out.is_bru = is_br;
    assign pass_out.ex_out_sel = is_csr ? CSR
                                : is_mul ? MUL
                                : is_div ? DIV
                                : ALU;
    assign pass_out.alu_a_sel = alu_a_pc ? PC
                      : alu_a_zero ? ZERO
                      : RJ;
    assign pass_out.alu_b_sel = alu_b_imm ? IMM : RKD;
    assign pass_out.mul_op = inst[16:15];
    assign pass_out.div_op = inst[16:15];
    assign pass_out.alu_op = alu_op;
    assign pass_out.bru_op = bru_op;

    assign pass_out.rj = rj;
    assign pass_out.rkd = rkd;
    assign pass_out.rd = rd;
    assign pass_out.rj_data = rj_data;
    assign pass_out.rkd_data = rkd_data;
    assign pass_out.imm = imm;
    assign pass_out.is_wr_rd = is_wr_rd;
    assign pass_out.is_wr_rd_pc_plus4 = is_br_wb;
    assign pass_out.is_wr_csr = inst_csrwr | inst_csrxchg;
    assign pass_out.is_mask_csr = inst_csrxchg;
    assign pass_out.csr_addr = csr_addr;
    assign pass_out.csr_data = csr_data;
    assign pass_out.is_mem = is_mem;
    assign pass_out.is_store = is_store;
    assign pass_out.is_signed = is_mem_signed;
    assign pass_out.byte_type = mem_byte_type;
    assign pass_out.is_cac = inst_cacop;
    assign pass_out.is_tlb = is_tlb;
    assign pass_out.tlb_op = '0;            // TODO: impl tlbop

    `PASS(pc);
    `PASS(btb_pre);

    assign excp_pass_out = excp_pass_in_r;

endmodule