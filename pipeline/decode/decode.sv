`include "cpu_defs.svh"

// TODO: hazard detect

module Decode (
    input logic clk, rst_n,

    /* from csr */
    output csr_addr_t csr_addr_out,
    input u32_t csr_data,
    input logic csr_bad_addr,

    input csr_t rd_csr,

    /* from regfile */
    output reg_idx_t rj_out, rkd_out,
    input u32_t rj_data, rkd_data,

    /* forwarding & load use*/
    input forward_req_t ex_req, mem1_req, mem2_req,

    /* pipeline */
    input logic flush_i, stall_i,
    output logic stall_o,
    input fetch2_decode_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output decode_execute_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    /* pipeline start */
    fetch2_decode_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    logic load_use_stall;
    assign stall_o = stall_i | load_use_stall;

    logic excp_valid;
    assign excp_valid = id_excp.valid | excp_pass_in_r.valid;

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
        if(excp_pass_in_r.valid) excp_pass_out = excp_pass_in_r;
        else                     excp_pass_out = id_excp;
        excp_pass_out.valid = excp_valid & valid_with_flush;
    end
    /* pipeline end */

    u32_t inst;
    assign inst = pass_in_r.inst;

    /* forwarding */
    u32_t rj_forwarded, rkd_forwarded;
    logic rj_load_use, rkd_load_use;
    assign load_use_stall = (rj_load_use & is_use_rj) | (rkd_load_use & is_use_rkd);
    always_comb begin
        rj_load_use = 1'b0;
        rj_forwarded = rj_data;
        if(ex_req.valid && rj == ex_req.idx) begin
            /* seperately forward data from ex to reduce latency */
            rj_load_use = ~ex_req.data_valid;
        end else if(mem1_req.valid && rj == mem1_req.idx) begin
            rj_forwarded = mem1_req.data;
            rj_load_use = ~mem1_req.data_valid;
        end
        else if(mem2_req.valid && rj == mem2_req.idx) begin
            rj_forwarded = mem2_req.data;
            rj_load_use = ~mem2_req.data_valid;
        end
        else rj_forwarded = rj_data;
    end
    always_comb begin
        rkd_load_use = 1'b0;
        rkd_forwarded = rkd_data;
        if(ex_req.valid && rkd == ex_req.idx) begin
            /* seperately forward data from ex to reduce latency */
            rkd_load_use = ~ex_req.data_valid;
        end else if(mem1_req.valid && rkd == mem1_req.idx) begin
            rkd_forwarded = mem1_req.data;
            rkd_load_use = ~mem1_req.data_valid;
        end
        else if(mem2_req.valid && rkd == mem2_req.idx) begin
            rkd_forwarded = mem2_req.data;
            rkd_load_use = ~mem2_req.data_valid;
        end
        else rkd_forwarded = rkd_data;
    end

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

    logic is_atomic;
    assign is_atomic = inst_ll_w  |
                       inst_sc_w  ;

    logic is_mem;
    logic is_store, is_load;
    assign is_mem = inst_ld_b  |
                    inst_ld_bu |
                    inst_ld_h  |
                    inst_ld_hu |
                    inst_ld_w  |
                    inst_st_b  |
                    inst_st_h  |
                    inst_st_w  |
                    inst_ll_w  |
                    inst_sc_w  ;
    assign is_store = inst_st_b |
                      inst_st_h |
                      inst_st_w |
                      inst_sc_w ;
    assign is_load = is_mem & ~is_store;

    logic is_mem_signed;
    assign is_mem_signed = inst_ld_b |
                           inst_ld_h ;

    byte_type_t mem_byte_type;
    assign mem_byte_type = is_atomic ? WORD : byte_type_t'(inst[23:22]);

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
                      inst_bl   ;

    logic is_mul;
    assign is_mul = inst_mul_w   |
                    inst_mulh_w  |
                    inst_mulh_wu ;
    logic is_div;
    assign is_div = inst_div_w  |
                    inst_div_wu |
                    inst_mod_w  |
                    inst_mod_wu ;

    logic is_cnt;
    assign is_cnt = inst_rdcntid_w |
                    inst_rdcntvh_w |
                    inst_rdcntvl_w ;
    logic is_rdcntid_rdcntvl;
    assign inst_rdcntid_w = is_rdcntid_rdcntvl && (inst[4:0] == 5'b0);
    assign inst_rdcntvl_w = is_rdcntid_rdcntvl && ~inst_rdcntid_w;      // TODO: figure out what if rj = rd = 0

    logic is_csr;       // NOTE: it's directly generated by case
    assign inst_csrrd = is_csr && (rj == 5'b0);
    assign inst_csrwr = is_csr && (rj == 5'b1);
    assign inst_csrxchg = is_csr & ~inst_csrrd & ~inst_csrwr;

    tlb_op_t tlb_op;
    always_comb begin
        tlb_op = TLBNOP;
        unique case(1'b1)
            inst_tlbsrch:   tlb_op = TLBSRCH;
            inst_tlbrd:     tlb_op = TLBRD;
            inst_tlbwr:     tlb_op = TLBWR;
            inst_tlbfill:   tlb_op = TLBFILL;
            inst_invtlb:    tlb_op = INVTLB;
            default: ;
        endcase
    end

    logic is_alu_add;
    assign is_alu_add = inst_add_w |
                        inst_addi_w |
                        is_mem |
                        is_br |
                        inst_pcaddu12i |
                        inst_lu12i_w |
                        inst_cacop |
                        is_csr |
                        is_cnt ;

    cnt_op_t cnt_op;
    always_comb begin
        cnt_op = CNTID;
        unique case(1'b1)
            inst_rdcntid_w: cnt_op = CNTID;
            inst_rdcntvh_w: cnt_op = CNTVH;
            inst_rdcntvl_w: cnt_op = CNTVL;
            default: ;
        endcase
    end

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
    assign is_wr_rd = is_load  |
                      is_mul   |
                      is_div   |
                      is_csr   |
                      is_alu   |
                      inst_pcaddu12i |
                      inst_lu12i_w   |
                      is_br_wb       |
                      is_cnt         |
                      inst_sc_w      ;          // write result 0 or 1 to rd

    logic is_rd_as_rk;
    assign is_rd_as_rk = is_store |
                         inst_beq |
                         inst_bne |
                         inst_blt |
                         inst_bge |
                         inst_bltu |
                         inst_bgeu |
                         is_csr ;

    reg_idx_t rj, rkd, rd;
    assign rj = inst[9:5];
    assign rd = inst_bl ? 5'b1 : 
                inst_rdcntid_w ? inst[9:5] :
                inst[4:0];
    assign rkd = is_rd_as_rk ? rd : inst[14:10];

    logic alu_a_rj, alu_a_pc, alu_a_zero;
    assign alu_a_pc = is_br_off     |
                      inst_pcaddu12i;
    assign alu_a_zero = inst_lu12i_w |
                        is_csr       |
                        is_cnt       ;
                        


    logic alu_b_rkd, alu_b_imm, alu_b_csr, alu_b_cnt;
    assign alu_b_imm = is_uimm5  |
                       is_simm12 |
                       is_uimm12 |
                       is_simm20 |
                       is_simm14 |
                       is_simm16 |
                       is_simm26 ;
    assign alu_b_csr = is_csr;
    assign alu_b_cnt = is_cnt;
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
                       (is_mem & ~is_atomic);
            
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
            is_simm14: imm = {{16{simm14[13]}}, simm14, 2'b0};
            is_simm16: imm = {{14{simm16[15]}}, simm16, 2'b0};
            is_simm20: imm = {simm20, 12'b0};
            is_simm26: imm = {{4{simm26[25]}}, simm26, 2'b0};
            default: imm = '0;
        endcase
    end

    // we only need csr[8:0]
    csr_addr_t csr_addr;
    assign csr_addr = inst[18:10];

    logic csr_non_zero_bad_addr;
    assign csr_non_zero_bad_addr = (inst[23:19] != 5'b0) || csr_bad_addr;

    bru_op_t bru_op;
    assign bru_op = bru_op_t'(inst[29:26]);

    logic is_modify_csr;
    assign is_modify_csr = inst_csrwr   |       // mem1
                           inst_csrxchg |
                           inst_tlbsrch |
                           inst_tlbrd   |
                           inst_ertn    ;       // maybe mem2 ?
    logic is_modify_tlb;
    assign is_modify_tlb = inst_tlbwr   |
                           inst_tlbfill |
                           inst_invtlb  ;
    
    logic is_modify_state;
    assign is_modify_state = is_modify_csr | is_modify_tlb | inst_cacop | inst_ibar | inst_idle;        // make sure i$ can see the result of cacop

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
        inst_ertn = 1'b0;

        is_rdcntid_rdcntvl = 1'b0;
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
            {22'b0000_0000_0000_0000_0110_00, {10{1'b?}}}: is_rdcntid_rdcntvl = 1'b1;
            {22'b0000_0000_0000_0000_0110_01, 5'b0, {5{1'b?}}}: inst_rdcntvh_w = 1'b1;
            {17'b0000_0000_0001_0000_0, {15{1'b?}}}: inst_add_w = 1'b1;
            {17'b0000_0000_0001_0001_0, {15{1'b?}}}: inst_sub_w = 1'b1;
            {17'b0000_0000_0001_0010_0, {15{1'b?}}}: inst_slt = 1'b1;
            {17'b0000_0000_0001_0010_1, {15{1'b?}}}: inst_sltu = 1'b1;
            {17'b0000_0000_0001_0100_0, {15{1'b?}}}: inst_nor = 1'b1;
            {17'b0000_0000_0001_0100_1, {15{1'b?}}}: inst_and = 1'b1;
            {17'b0000_0000_0001_0101_0, {15{1'b?}}}: inst_or = 1'b1;
            {17'b0000_0000_0001_0101_1, {15{1'b?}}}: inst_xor = 1'b1;
            {17'b0000_0000_0001_0111_0, {15{1'b?}}}: inst_sll_w = 1'b1;
            {17'b0000_0000_0001_0111_1, {15{1'b?}}}: inst_srl_w = 1'b1;
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
                       is_br        |
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
                        is_store    |
                        is_br_off   |
                        inst_csrwr  |
                        inst_csrxchg;

    /* out to next stage */
    assign pass_out.is_mul = is_mul;
    assign pass_out.is_div = is_div;
    assign pass_out.is_bru = is_br;
    assign pass_out.ex_out_sel =  is_mul ? MUL
                                : is_div ? DIV
                                : ALU;
    assign pass_out.alu_a_sel = alu_a_pc ? PC
                      : alu_a_zero ? ZERO
                      : RJ;
    assign pass_out.alu_b_sel = alu_b_imm ? IMM
                                : alu_b_csr ? CSR
                                : alu_b_cnt ? CNT
                                : RKD;
    assign pass_out.mul_op = mul_op_t'(inst[16:15]);
    assign pass_out.div_op = div_op_t'(inst[16:15]);
    assign pass_out.alu_op = alu_op;
    assign pass_out.bru_op = bru_op;
    assign pass_out.cnt_op = cnt_op;

    assign pass_out.rj = rj;
    assign pass_out.rkd = rkd;
    assign pass_out.rd = rd;
    assign pass_out.ex_req = ex_req;
    assign pass_out.rj_data = rj_forwarded;
    assign pass_out.rkd_data = rkd_forwarded;
    assign pass_out.imm = imm;
    assign pass_out.is_wr_rd = is_wr_rd;
    assign pass_out.is_wr_rd_pc_plus4 = is_br_wb;
    assign pass_out.is_wr_csr = (inst_csrwr | inst_csrxchg) && ~csr_non_zero_bad_addr;
    assign pass_out.is_mask_csr = inst_csrxchg;
    assign pass_out.csr_addr = csr_addr;
    assign pass_out.csr_data = csr_non_zero_bad_addr ? 32'b0 : csr_data;
    assign pass_out.is_atomic = is_atomic;
    assign pass_out.is_mem = is_mem;
    assign pass_out.is_store = is_store;
    assign pass_out.is_signed = is_mem_signed;
    assign pass_out.byte_type = mem_byte_type;
    assign pass_out.is_cac = inst_cacop;
    assign pass_out.is_ertn = inst_ertn;
    assign pass_out.tlb_op = tlb_op;
    assign pass_out.is_idle = inst_idle;

    assign pass_out.is_modify_state = is_modify_state;

    `PASS(pc);
    `PASS(next);

    // only modify csr in mem1, mem2, and we should set flush after the inst reach mem2

    /* exception */
    logic is_tlb;
    assign is_tlb = inst_tlbrd      |
                    inst_tlbwr      |
                    inst_tlbfill    |
                    inst_tlbsrch    |
                    inst_invtlb     ;
    logic is_plv;
    assign is_plv = is_csr      |
                    is_tlb      |
                    inst_ertn   |
                    inst_idle   |
                    inst_cacop && (simm12[3:0] != 4'd8 && simm12[3:0] != 4'd9);     // invalidate hit i$ and d$

    logic invtlb_badop;
    assign invtlb_badop = rd != 5'h0 &&
                          rd != 5'h1 &&
                          rd != 5'h2 &&
                          rd != 5'h3 &&
                          rd != 5'h4 &&
                          rd != 5'h5 &&
                          rd != 5'h6 ;
    
    excp_pass_t id_excp;
    always_comb begin
        id_excp.valid = 1'b0;
        id_excp.esubcode_ecode = IPE;
        id_excp.badv = '0;
        if(is_plv && rd_csr.crmd.plv != KERNEL) begin
            id_excp.valid = 1'b1;
            id_excp.esubcode_ecode = IPE;
        end else begin
            unique case(1'b1)
                inst_syscall: begin
                    id_excp.valid = 1'b1;
                    id_excp.esubcode_ecode = SYS;
                end
                inst_break: begin
                    id_excp.valid = 1'b1;
                    id_excp.esubcode_ecode = BRK;
                end
                bad_inst, invtlb_badop & inst_invtlb: begin
                    id_excp.valid = 1'b1;
                    id_excp.esubcode_ecode = INE;
                end
                default: ;
            endcase
        end
    end

    /*  pass_in_r.valid     excp_pass_in_r.valid
        y                   y                       this inst exception
        y                   n                       this inst no exception
        n                   y                       not happended
        n                   n                       bubble              */
    /* if exception (pass in or this stage), flush this stage, and pass exception */

`ifdef DIFF_TEST
    `PASS(inst);

    /* to make difftest happy */
    assign pass_out.is_modify_csr = is_modify_csr;
    assign pass_out.csr = rd_csr;

    assign pass_out.is_rdcnt = is_cnt;
`endif

endmodule