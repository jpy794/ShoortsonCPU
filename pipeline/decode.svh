// for BRU
typedef enum logic [3:0] {
    BEQ,    // pc + imm
    BNE,
    BLT,
    BLTU,
    BGE,
    BGEU,
    B,
    BL,     // pc + 4 -> rd / pc + imm
    JIRL    // pc + 4 -> rd / rj + imm
} bru_op_t;

// for MUL, DIV
typedef enum logic [1:0] { LO, HI, HIU } mul_op_t;
typedef enum logic [1:0] { Q, QU, R, RU } div_op_t;

// for ALU
typedef enum logic [3:0] { ADD, SUB, AND, OR, NOR, XOR, SLL, SRL, SRA, SLT, SLTU } alu_op_t;
typedef enum logic [1:0] { RJ, PC, ZERO } alu_a_sel_t;
typedef enum logic [0:0] {
    RKD,        // store / br need to read rd
    IMM
} alu_b_sel_t;

typedef enum logic [1:0] {
    ALU,
    MUL,
    DIV,
    CSR
} ex_out_sel_t;

typedef enum logic [2:0] {
    TLBSRCH,
    TLBRD,
    TLBWR,
    TLBFILL,
    INVTLB
} tlb_op_t;

typedef enum logic [1:0] {
    BYTE = 2'b10,
    HALF_WORD = 2'b01,
    WORD = 2'b00
} byte_type_t;

typedef logic [1:0] byte_en_t;

/*
    CSR,        // ex_out = rj_data or (rj_data & rd_data) | (~rj_data & csr_data)     (TODO: rj != 0 / 1 what's the point???)
    TLB,
    CAC,        // ex_out = rj_data + imm
    MEM         // ex_out = rj_data + imm
*/
