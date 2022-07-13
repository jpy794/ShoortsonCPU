localparam NOTCARE = 0;

typedef enum logic [2:0] { UI5, SI12, UI12, SI14, SI20, OFFS16, OFFS26 } imm_type_t;

typedef enum logic [1:0] { ALU, MUL, DIV, CMP } execute_type_t;

// for ALU
typedef enum logic [3:0] { ADD, SUB, AND, OR, NOR, XOR, SLL, SRL, SRA } alu_op_type_t;
typedef enum { RJ, PC, ZERO } alu_src1_sel_t;
typedef enum { RK, IMM } alu_src2_sel_t;

typedef enum logic [1:0] { EX, MEM, PCplus4 } writeback_src_t;
