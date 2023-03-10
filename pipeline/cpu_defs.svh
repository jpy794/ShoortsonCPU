`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

`include "common_defs.svh"
`include "decode.svh"
`include "pipeline.svh"


localparam GRLEN = 32;
localparam TIMLEN = 32;     // if change, also need to change tval...

typedef logic [4:0] reg_idx_t;

/* tlb */
`ifdef DIFF_TEST
localparam TLB_ENTRY_NUM = 32;
`else
localparam TLB_ENTRY_NUM = 16;
`endif
localparam TLB_IDX_WID = $clog2(TLB_ENTRY_NUM);
localparam ASID_WID = 10;
/* ps enum */
localparam PS_4KB = 12;
localparam PS_4MB = 21;
/* ps enum end */

typedef logic [TLB_IDX_WID-1:0] tlb_idx_t;
typedef logic [VALEN-13-1:0] vppn_t;
typedef logic [PALEN-12-1:0] ppn_t;
typedef logic [ASID_WID-1:0] asid_t;
typedef logic [5:0] ps_t;

typedef enum logic [2-1:0] {
    USER = 2'd3,
    KERNEL = 2'd0
} plv_t;

typedef enum logic [2-1:0] {
    MAT_NOCACHE = 2'b0,
    MAT_CACHE = 2'b1
} mat_t;
typedef mat_t dat_t;

typedef logic [GRLEN-1:12] pgd_base_t;

typedef struct packed {
    ppn_t ppn;
    plv_t plv;
    mat_t mat;
    logic d;
    logic v;
} tlb_entry_phy_t;

typedef struct packed {
    /* compare part */
    vppn_t vppn;
    ps_t ps;
    logic g;
    asid_t asid;
    logic e;

    /* physical part */
    tlb_entry_phy_t [1:0] phy;
} tlb_entry_t;

typedef enum logic [1:0] {
    LOOKUP_LOAD =   2'h1,
    LOOKUP_STORE =  2'h2,
    LOOKUP_FETCH =  2'h3
} tlb_lookup_type_t;
/* tlb end */


/* csr */
// we only need csr[8:0]
typedef logic [8:0] csr_addr_t;

// we only need esubcode[0] and ecode[5:0]
typedef enum logic [6:0] {
    INT =   {1'h0, 6'h0},
    PIL =   {1'h0, 6'h1},       // page invalid load
    PIS =   {1'h0, 6'h2},       // page invalid store
    PIF =   {1'h0, 6'h3},       // page invalid fetch
    PME =   {1'h0, 6'h4},       // page modify (store but dirty)
    PPI =   {1'h0, 6'h7},       // page privilege
    ADEF =  {1'h0, 6'h8},       // address fetch
    ADEM =  {1'h1, 6'h8},       // address mem
    ALE =   {1'h0, 6'h9},       // address align
    SYS =   {1'h0, 6'hb},
    BRK =   {1'h0, 6'hc},
    INE =   {1'h0, 6'hd},       // instruction not exist
    IPE =   {1'h0, 6'he},       // instruction privilege
    FPD =   {1'h0, 6'hf},
    FPE =   {1'h0, 6'h12},
    TLBR =  {1'h0, 6'h3f}       // tlb refill
} esubcode_ecode_t;

/* tlb inst */

typedef struct packed {
    vppn_t vppn;
    logic [12:0] r0_1;
} csr_tlbehi_t;             // TODO: when exception, write vaddr to here

/* for tlbelo0 tlbelo1 */
typedef struct packed {
    logic [35-PALEN:0] r0_1;
    ppn_t ppn;
    logic r0_2;
    logic g;
    mat_t mat;
    plv_t plv;
    logic d;
    logic v;
} csr_tlbelo_t;

typedef struct packed {
    logic ne;
    logic r0_1;
    ps_t ps;
    logic [7:0] r0_2;
    logic [15-TLB_IDX_WID:0] r0_3;
    tlb_idx_t index;
} csr_tlbidx_t;

typedef struct packed {
    logic [7:0] r0_1;
    logic [7:0] r_asidbits;
    logic [5:0] r0_2;
    asid_t asid;
} csr_asid_t;

/* pt walk */
/* for both pgdh pgdl pgd */
typedef struct packed {
    pgd_base_t base;
    logic [11:0] r0_1;
} csr_pgd_t;

/* tlb refill exception */
typedef struct packed {
    logic [25:0] pa;
    logic [5:0] r0_1;
} csr_tlbrentry_t;

typedef struct packed {
    logic ipi;
    logic ti;
    logic noi;
    logic [7:0] hwi;
    logic [1:0] swi;
} lie_t;

typedef struct packed {
    logic r_ipi;
    logic r_ti;
    logic r0_1;
    logic [7:0] r_hwi;
    logic [1:0] swi;
} is_t;

typedef struct packed {
    logic [8:0] r0_1;
    esubcode_ecode_t r_esubcode_ecode;
    logic [2:0] r0_2;
    is_t is;
} csr_estat_t;

typedef struct packed {
    logic [22:0] r0_1;
    dat_t datm;
    dat_t datf;
    logic pg;
    logic da;
    logic ie;
    plv_t plv;
} csr_crmd_t;

typedef struct packed {
    logic [28:0] r0_1;
    logic pie;
    plv_t pplv;
} csr_prmd_t;

typedef struct packed {
    logic [30:0] r0_1;
    logic fpe;
} csr_euen_t;

typedef struct packed {
    logic [18:0] r0_1;
    lie_t lie;
} csr_ecfg_t;

typedef u32_t csr_era_t;
typedef u32_t csr_badv_t;

typedef struct packed {
    logic [25:0] va;
    logic [5:0] r0_1;
} csr_eentry_t;

typedef struct packed {
    logic [22:0] r0_1;
    logic [8:0] r_coreid;
} csr_cpuid_t;

typedef u32_t csr_save_t;

typedef struct packed {
    logic [2:0] vseg;
    logic r0_1;
    logic [2:0] pseg;
    logic [18:0] r0_2;
    mat_t mat;
    logic plv3;
    logic [1:0] r0_3;
    logic plv0;
} csr_dmw_t;

// TODO: llbctl

typedef u32_t csr_tid_t;
typedef struct packed {
    logic [TIMLEN-2-1:0] initval;       // [1:0] = 2'b0
    logic periodic;
    logic en;
} csr_tcfg_t;
typedef logic [TIMLEN-1:0] csr_tval_t;      // read only
typedef struct packed {
    logic [30:0] r0_1;
    logic clr;              // w1 r0
} csr_ticlr_t;

typedef struct packed {
    logic [28:0] r0_1;
    logic klo;
    logic w1_wcllb;
    logic r_rollb;
} csr_llbctl_t;

typedef struct packed {
    csr_crmd_t crmd;
    csr_prmd_t prmd;
    csr_euen_t euen;
    csr_ecfg_t ecfg;
    csr_estat_t estat;
    csr_era_t era;
    csr_badv_t badv;
    csr_eentry_t eentry;
    csr_cpuid_t cpuid;
    csr_save_t [3:0] save;
    // TODO: llbctl
    csr_tlbidx_t tlbidx;
    csr_tlbehi_t tlbehi;
    csr_tlbelo_t [1:0] tlbelo;
    csr_asid_t asid;
    csr_pgd_t pgdl, pgdh, pgd;
    csr_tlbrentry_t tlbrentry;
    csr_dmw_t [1:0] dmw;
    csr_tid_t tid;
    csr_tcfg_t tcfg;
    csr_tval_t tval;
    csr_ticlr_t ticlr;
    csr_llbctl_t llbctl;
} csr_t;

typedef struct packed {
    logic we;
    csr_asid_t asid;
    csr_tlbehi_t tlbehi;
    csr_tlbelo_t [1:0] tlbelo;
    csr_tlbidx_t tlbidx;
} tlb_wr_csr_req_t;

typedef struct packed {
    logic valid;
    esubcode_ecode_t esubcode_ecode;
    virt_t badv;
} excp_pass_t;

typedef struct packed {
    logic valid;            // not bubble
    virt_t epc;
    excp_pass_t excp_pass;
} excp_req_t;

typedef struct packed {
    logic valid;
    logic [10:0] int_no;
    logic [5:0] ecode;
} excp_event_t;

typedef struct packed {
    logic we;
    csr_crmd_t crmd;
    csr_prmd_t prmd;
    csr_estat_t estat;
    csr_era_t era;
    csr_badv_t badv;
    csr_tlbehi_t tlbehi;
} excp_wr_csr_req_t;

/* btb */
localparam INST_ALIGN_WID = 2;

localparam BRHISTORY_LENGTH = 4;
localparam BTB_SIZE = 1024;
localparam BTB_IDX_WID = $clog2(BTB_SIZE);
localparam BTB_TARGET_WID = 32 - INST_ALIGN_WID;
localparam BTB_TAG_WID = BTB_TARGET_WID - BTB_IDX_WID;

typedef logic [BTB_IDX_WID-1:0] btb_idx_t;
typedef logic [BTB_TAG_WID-1:0] btb_tag_t;
typedef logic [BTB_TARGET_WID-1:0] btb_target_t;
typedef struct packed {
    btb_tag_t tag;
    btb_target_t target;
} btb_entry_t;

/* ras */
localparam RA_STACK_SIZE = 32;
localparam RA_STACK_IDX_WID = $clog2(RA_STACK_SIZE);

/* to fetch */
typedef struct packed {
    logic valid;
    u32_t npc;
} btb_predict_t;

/* from if2 */
typedef struct packed {
    logic valid;
    u32_t pc;
} btb_invalid_t;

/* from ex */
typedef struct packed {
    logic valid;            // valid for j / b inst
    logic taken;
    u32_t pc, target_pc;
} br_resolved_t;

typedef struct packed {
    logic is_predict;
    u32_t pc;
} next_pc_t;

typedef struct packed {
    logic valid;
    logic is_predict;
    u32_t pc;
} wr_pc_req_t;

/* forwarding */
typedef struct packed {
    logic valid;
    reg_idx_t idx;
    u32_t data;
    logic data_valid;
} forward_req_t;

/* load use */
typedef struct packed {
    logic valid;
    reg_idx_t idx;
} load_use_t;

/* pipeline pass */
typedef struct packed {
    logic valid;
    virt_t pc;
    next_pc_t next;
    logic icache_wait_resp;
} fetch1_fetch2_pass_t;

typedef struct packed {
    logic valid;
    virt_t pc;
    next_pc_t next;
    u32_t inst;
} fetch2_decode_pass_t;

typedef struct packed {
    logic valid;
    virt_t pc;
    next_pc_t next;

    logic is_mul, is_div, is_bru;
    ex_out_sel_t ex_out_sel;
    alu_a_sel_t alu_a_sel;
    alu_b_sel_t alu_b_sel;
    alu_op_t alu_op;
    mul_op_t mul_op;
    div_op_t div_op;
    bru_op_t bru_op;
    cnt_op_t cnt_op;
    reg_idx_t rj, rkd, rd;
    forward_req_t ex_req;
    u32_t rj_data, rkd_data;
    u32_t imm;

    /* for inst executed in wb */
    logic is_wr_rd;
    logic is_wr_rd_pc_plus4;

    logic is_wr_csr;
    logic is_mask_csr;
    csr_addr_t csr_addr;
    u32_t csr_data;

    /* for inst executed in mem */
    logic is_atomic;
    logic is_mem;
    logic is_store;
    logic is_signed;
    byte_type_t byte_type;

    logic is_cac;
    logic is_ertn;

    logic is_modify_state;
    
    tlb_op_t tlb_op;

    logic is_idle;

`ifdef DIFF_TEST
    u32_t inst;

    logic is_modify_csr;
    csr_t csr;

    logic is_rdcnt;
`endif
} decode_execute_pass_t;

typedef struct packed {
    logic valid;
    virt_t pc;

    u32_t ex_out;

    /* for inst executed in wb */
    logic is_wr_rd;
    virt_t pc_plus4;
    logic is_wr_rd_pc_plus4;
    reg_idx_t rd;               // also cacop_code / invtlb_op

    logic is_wr_csr;
    csr_addr_t csr_addr;
    u32_t csr_data;

    /* for inst executed in mem */
    logic is_atomic;
    logic is_mem;
    logic is_store;
    logic is_signed;
    byte_type_t byte_type;
    u32_t rkd_data;           // also store_data / invtlb_vppn([31:13])

    logic is_cac;
    logic is_ertn;

    tlb_op_t tlb_op;
    asid_t invtlb_asid;         // rj_data[9:0]

    logic is_modify_state;

    logic is_idle;

`ifdef DIFF_TEST
    u32_t inst;

    logic is_modify_csr;
    csr_t csr;

    logic is_rdcnt;
    logic [63:0] cntval_64;
`endif
} execute_memory1_pass_t;

typedef struct packed {
    logic valid;
    virt_t pc;

    u32_t ex_out;

    logic is_atomic;
    logic is_mem;
    logic is_store;
    logic is_signed;
    byte_type_t byte_type;
    byte_en_t byte_en;          // addr[1:0]

    /* for inst executed in wb */
    logic is_wr_rd;
    logic is_wr_rd_pc_plus4;
    virt_t pc_plus4;
    reg_idx_t rd;
    
    logic dcache_wait_resp;

`ifdef DIFF_TEST
    u32_t inst;

    logic is_ertn;
    logic is_modify_csr;
    csr_t csr;
    csr_estat_t old_estat;

    logic is_wr_csr;
    csr_addr_t csr_addr;
    u32_t csr_data;

    logic is_ld, is_st;
    virt_t va, pa;
    u32_t st_data;
    logic [7:0] byte_valid;

    logic is_rdcnt;
    logic [63:0] cntval_64;

    logic is_tlbfill;
    tlb_idx_t tlb_wr_idx;

    excp_event_t excp_event;
`endif
} memory1_memory2_pass_t;

typedef struct packed {
    logic valid;
    virt_t pc;

    u32_t ex_mem_out;

    /* for inst executed in wb */
    logic is_wr_rd;             // two wrs should be mutually exclusive
    logic is_wr_rd_pc_plus4;
    virt_t pc_plus4;
    reg_idx_t rd;

`ifdef DIFF_TEST
    u32_t inst;

    logic is_ertn;
    logic is_modify_csr;
    csr_t csr;
    csr_estat_t old_estat;

    logic is_wr_csr;
    csr_addr_t csr_addr;
    u32_t csr_data;

    logic is_ld, is_st;
    virt_t va, pa;
    u32_t st_data;
    logic [7:0] byte_valid;

    logic is_rdcnt;
    logic [63:0] cntval_64;

    logic is_tlbfill;
    tlb_idx_t tlb_wr_idx;

   excp_event_t excp_event;
`endif
} memory2_writeback_pass_t;
/* pipeline pass end */

typedef struct packed {
    tlb_op_t tlb_op;
    logic [4:0] invtlb_op;      // rd
    vppn_t invtlb_vppn;
    asid_t invtlb_asid;
    
    /* tlbsrch */
    logic found;
    tlb_idx_t found_idx;
} tlb_op_req_t;

`endif