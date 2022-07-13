`include "inc/signals.svh"

module Decode (
    output [31:0] immediate_number,
    output [31:0] rj_read,
    output [31:0] rk_read,
    output reg [4:0] rd_index,
    // SIG
    output execute_type_t execute_type, // select which execution component to use
    output reg [3:0] execute_op_type,
    output alu_src1_sel_t alu_src1_sel,
    output alu_src2_sel_t alu_src2_sel,
    output [3:0] compare_cond,
    output branch,
    output reg [2:0] number_length,         // (signed/unsigned) byte/half/word
    output reg [1:0] memory_rw,
    output writeback_valid,
    output writeback_src_t writeback_src,

    // segment-register input
    input [31:0] pc,
    output [31:0] pc_pass,
    input [31:0] inst,

    input clk,

    // writeback
    input [31:0] rd_wb,
    input [4:0] rd_wb_index,
    input rd_we
);

always @(*) begin
    if (inst_bl) rd_index = 1;
    else rd_index = inst[4:0];
end

RegFile regfile_instance(
    .rj_read    (rj_read    ),
    .rk_read    (rk_read    ),
    .rd_write   (rd_wb      ),
    .we         (rd_we      ),
    .rj_index   (inst[9:5]  ),
    .rk_index   (inst[14:10]),
    .rd_index   (rd_wb_index),
    .clk        (clk        )
);

// ImmGen
imm_type_t imm_type;

ImmGen immgen_instance(
    .immediate_number   (immediate_number),
    .inst               (inst),
    .imm_type           (imm_type)
);

// instructions
wire inst_add_w;
wire inst_sub_w;
wire inst_addi_w;
wire inst_lu12i_w;
wire inst_slt;
wire inst_sltu;
wire inst_slti;
wire inst_sltui;
wire inst_pcaddu12i;
wire inst_and;
wire inst_or;
wire inst_nor;
wire inst_xor;
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_div_w;
wire inst_div_wu;
wire inst_mod_w;
wire inst_mod_wu;

wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_slli_w;
wire inst_srli_w;
wire inst_srai_w;

wire inst_beq;
wire inst_bne;
wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;
wire inst_b;
wire inst_bl;
wire inst_jirl;

wire inst_ld_b;
wire inst_ld_h;
wire inst_ld_w;
wire inst_ld_bu;
wire inst_ld_hu;
wire inst_st_b;
wire inst_st_h;
wire inst_st_w;
wire inst_preld;
wire inst_ll_w;
wire inst_sc_w;
wire inst_dbar;
wire inst_ibar;

wire inst_syscall;
wire inst_break;
wire inst_rdcntvl_w;
wire inst_rdcntvh_w;
wire inst_rdcntid;

wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;

wire inst_cacop;

wire inst_tlbsrch;
wire inst_tlbrd;
wire inst_tlbwr;
wire inst_tlbfill;
wire inst_invtlb;

wire inst_ertn;
wire inst_idle;

// instruction types
wire alu_add, alu_sub, alu_and, alu_or, alu_nor, alu_xor, alu_sll, alu_srl, alu_sra;

assign alu_add =    inst_add_w      |
                    inst_addi_w     |
                    inst_lu12i_w    |
                    inst_pcaddu12i;
assign alu_sub =    inst_sub_w;
assign alu_and =    inst_and    |
                    inst_andi;
assign alu_or =     inst_or     |
                    inst_ori;
assign alu_nor =    inst_nor;
assign alu_xor =    inst_xor    |
                    inst_xori;
assign alu_sll =    inst_sll_w  |
                    inst_slli_w;
assign alu_srl =    inst_srl_w  |
                    inst_srli_w;
assign alu_sra =    inst_sra_w  |
                    inst_srai_w;

wire itype_alu;
wire itype_br;
wire itype_mem;

assign itype_alu =  alu_add     |
                    alu_sub     |
                    alu_and     |
                    alu_or      |
                    alu_nor     |
                    alu_xor     |
                    alu_sll     |
                    alu_srl     |
                    alu_sra;

assign itype_br =   inst_beq    |
                    inst_bne    |
                    inst_blt    |
                    inst_bge    |
                    inst_bltu   |
                    inst_bgeu;

assign itype_mem =  inst_ld_b   |
                    inst_ld_h   |
                    inst_ld_w   |
                    inst_ld_bu  |
                    inst_ld_hu  |
                    inst_st_b   |
                    inst_st_h   |
                    inst_st_w;

// generate control signals from hotspot code
// immediate number type
always @(*) begin
    case (1)
        inst_slli_w, inst_srli_w, inst_srai_w:                      imm_type = UI5;
        inst_addi_w, inst_slti, inst_sltui, itype_mem, inst_preld:  imm_type = SI12;
        inst_andi, inst_ori, inst_xori:                             imm_type = UI12;
        inst_ll_w, inst_sc_w:                                       imm_type = SI14;
        inst_lu12i_w, inst_pcaddu12i:                               imm_type = SI20;
        itype_br, inst_jirl:                                        imm_type = OFFS16;
        inst_b, inst_bl:                                            imm_type = OFFS26;
        default:                                                    imm_type = imm_type_t'{NOTCARE};
    endcase
end

// select excution component
wire execute_alu, execute_mul, execute_div, execute_cmp;

alu_op_type_t alu_op_type;

always @(*) begin
    case (1)
        execute_alu: begin
            execute_type = ALU;
            execute_op_type = alu_op_type;
        end
        execute_mul: begin
            execute_type = MUL;
            execute_op_type = 
        end
        execute_div: begin
            execute_type = DIV;
            execute_op_type = 
        end
        execute_cmp: begin
            execute_type = CMP;
            execute_op_type = NOTCARE;
        end
        default: begin
            execute_type = execute_type_t'{NOTCARE};
            execute_op_type = NOTCARE;
        end
    endcase
end

assign execute_alu =    itype_alu   |
                        itype_br    |
                        inst_b      |
                        inst_bl     |
                        inst_jirl   |
                        itype_mem   |
                        inst_preld  |
                        inst_ll_w   |
                        inst_sc_w;

assign execute_mul =    inst_mul_w  |
                        inst_mulh_w |
                        inst_mulh_wu;

assign execute_div =    inst_div_w  |
                        inst_div_wu |
                        inst_mod_w  |
                        inst_mod_wu;

assign execute_cmp =    inst_slt    |
                        inst_sltu   |
                        inst_slti   |
                        inst_sltui;

// alu control
always @(*) begin
    case (1)
        itype_br, inst_b, inst_bl, inst_jirl, 
        itype_mem, inst_preld, inst_ll_w, inst_sc_w,
        alu_add: alu_op_type = ADD;
        alu_sub: alu_op_type = SUB;
        alu_and: alu_op_type = AND;
        alu_or:  alu_op_type = OR;
        alu_nor: alu_op_type = NOR;
        alu_xor: alu_op_type = XOR;
        alu_sll: alu_op_type = SLL;
        alu_srl: alu_op_type = SRL;
        alu_sra: alu_op_type = SRA;
        default: alu_op_type = alu_op_type_t'{NOTCARE};
    endcase
end

always @(*) begin
    case (1)
        inst_pcaddu12i, itype_br, inst_b, inst_bl:  alu_src1_sel = PC;
        inst_lu12i_w:                               alu_src1_sel = ZERO;
        default:                                    alu_src1_sel = RJ;
    endcase
end

always @(*) begin
    case (1)
        inst_slli_w, inst_srli_w, inst_srai_w,
        inst_addi_w, inst_slti, inst_sltui, itype_mem, inst_preld,
        inst_andi, inst_ori, inst_xori,
        inst_ll_w, inst_sc_w,
        inst_lu12i_w, inst_pcaddu12i,
        itype_br, inst_jirl,
        inst_b, inst_bl:            alu_src2_sel = IMM;
        default:                    alu_src2_sel = RK;
    endcase
end

// comparator control
logic cmp_signed;
logic [2:0] cmp_expected;
assign compare_cond = {cmp_signed, cmp_expected};

always @(*) begin
    case (1)
        inst_slt, inst_slti, inst_beq, inst_bne, inst_blt, inst_bge:    cmp_signed = 1;
        inst_sltu, inst_sltui, inst_bltu, inst_bgeu:                    cmp_signed = 0;
        default:                                                        cmp_signed = NOTCARE;
    endcase
end

always @(*) begin
    case (1)
        inst_slt, inst_sltu, inst_slti, inst_sltui,
        inst_blt, inst_bltu:        cmp_expected = 3'b100;
        inst_beq:                   cmp_expected = 3'b010;
        inst_bne:                   cmp_expected = 3'b101;
        inst_bge, inst_bgeu:        cmp_expected = 3'b011;
        inst_b, inst_bl, inst_jirl: cmp_expected = 3'b111;
        default:                    cmp_expected = NOTCARE;
    endcase
end

assign branch = itype_br    |
                inst_b      |
                inst_bl     |
                inst_jirl;

always @(*) begin
    case (1)
        inst_ld_b, inst_st_b:   number_length = 3'b100;
        inst_ld_h, inst_st_h:   number_length = 3'b101;
        inst_ld_bu:             number_length = 3'b000;
        inst_ld_hu:             number_length = 3'b001;
        default:                number_length = 3'b111;
    endcase
end

always @(*) begin
    case (1)
        inst_ld_b, inst_ld_h, inst_ld_w, inst_ld_bu, inst_ld_hu:    memory_rw = 2'b10;
        inst_st_b, inst_st_h, inst_st_w:                            memory_rw = 2'b01;
        default:                                                    memory_rw = 2'b00;
    endcase
end

assign writeback_valid =    itype_alu   |
                            execute_mul |
                            execute_div |
                            execute_cmp |
                            inst_bl     |
                            inst_jirl   |
                            inst_ld_b   |
                            inst_ld_h   |
                            inst_ld_w   |
                            inst_ld_bu  |
                            inst_ld_hu  |
                            inst_ll_w;

always @(*) begin
    case (1)
        itype_alu, execute_mul, execute_div, execute_cmp:   writeback_src = EX;
        inst_bl, inst_jirl:                                 writeback_src = PCplus4;
        itype_mem, inst_ll_w:                               writeback_src = MEM;
        default:                                            writeback_src = writeback_src_t'{NOTCARE};
    endcase
end


// ----- generate instruction hotspot code -----
// refer to Chiplab
// inst_orn, inst_andn, inst_pcaddi removed
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [31:0] rd_d;
wire [31:0] rj_d;
wire [31:0] rk_d;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];
assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(rj  ), .out(rj_d  ));
decoder_5_32 u_dec6(.in(rk  ), .out(rk_d  ));

assign inst_add_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_sll_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_mul_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_break      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_syscall    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_slli_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_idle       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_invtlb     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];
assign inst_dbar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h04];
assign inst_ibar       = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h05];
assign inst_slti       = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui      = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_addi_w     = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_andi       = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori        = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori       = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_ld_b       = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h       = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_w       = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b       = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h       = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w       = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_ld_bu      = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu      = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_cacop      = op_31_26_d[6'h01] & op_25_22_d[4'h8];
assign inst_preld      = op_31_26_d[6'h0a] & op_25_22_d[4'hb];
assign inst_jirl       = op_31_26_d[6'h13];
assign inst_b          = op_31_26_d[6'h14];
assign inst_bl         = op_31_26_d[6'h15];
assign inst_beq        = op_31_26_d[6'h16];
assign inst_bne        = op_31_26_d[6'h17];
assign inst_blt        = op_31_26_d[6'h18];
assign inst_bge        = op_31_26_d[6'h19];
assign inst_bltu       = op_31_26_d[6'h1a];
assign inst_bgeu       = op_31_26_d[6'h1b];
assign inst_lu12i_w    = op_31_26_d[6'h05] & ~inst[25];
assign inst_pcaddu12i  = op_31_26_d[6'h07] & ~inst[25];
assign inst_csrxchg    = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & (~rj_d[5'h00] & ~rj_d[5'h01]);  //rj != 0,1
assign inst_ll_w       = op_31_26_d[6'h08] & ~inst[25] & ~inst[24];
assign inst_sc_w       = op_31_26_d[6'h08] & ~inst[25] &  inst[24];
assign inst_csrrd      = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & rj_d[5'h00];
assign inst_csrwr      = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & rj_d[5'h01];
assign inst_rdcntid    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk_d[5'h18] & rd_d[5'h00];
assign inst_rdcntvl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk_d[5'h18] & rj_d[5'h00] & !rd_d[5'h00];
assign inst_rdcntvh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk_d[5'h19] & rj_d[5'h00];
assign inst_ertn       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0e] & rj_d[5'h00] & rd_d[5'h00];
assign inst_tlbsrch    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0a] & rj_d[5'h00] & rd_d[5'h00];
assign inst_tlbrd      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0b] & rj_d[5'h00] & rd_d[5'h00];
assign inst_tlbwr      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0c] & rj_d[5'h00] & rd_d[5'h00];
assign inst_tlbfill    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0d] & rj_d[5'h00] & rd_d[5'h00];


endmodule



module decoder_2_4(
    input  [ 1:0] in,
    output [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  [ 3:0] in,
    output [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64  //bug7
    assign out[i] = (in == i);
end endgenerate

endmodule
