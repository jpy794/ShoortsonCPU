`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

`include "common_defs.svh"

localparam GRLEN = 32;

/* access type enum */
localparam CC = 1;
localparam SUC = 0;
/* access type enum end */

/* tlb */
localparam TLB_ENTRY_NUM = 16;
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
typedef logic [2-1:0] plv_t;
typedef logic [2-1:0] mat_t;
typedef logic [2-1:0] dat_t;
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
    tlb_entry_phy_t [0:0] phy;
} tlb_entry_t;

typedef logic [1:0] tlb_lookup_type_t;
typedef enum tlb_lookup_type_t {
    LOOKUP_LOAD =   2'h1,
    LOOKUP_STORE =  2'h2,
    LOOKUP_FETCH =  2'h3
} tlb_lookup_type_enum_t;
/* tlb end */


/* csr */
// we only need csr[8:0]
typedef logic [8:0] csr_addr_t;

// we only need esubcode[0] and ecode[5:0]
typedef logic [6:0] esubcode_ecode_t;

typedef enum esubcode_ecode_t {
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
} esubcode_ecode_enum_t;

/* tlb inst */

typedef struct packed {
    vppn_t vppn;
    logic [12:0] r0_1;
} csr_tlbehi_t;

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
    logic pie_ipi;
    logic pie_ti;
    logic r0_1;
    logic [7:0] pie_hw;
    logic [1:0] pie_sw;
} lie_t;

typedef struct packed {
    logic r_is_ipi;
    logic r_is_ti;
    logic r0_1;
    logic [7:0] r_is_hw;
    logic [1:0] is_sw;
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

// TODO: llbctl, dmw, tim

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
    csr_save_t [1:0] save;
    // TODO: llbctl
    csr_tlbidx_t tlbidx;
    csr_tlbehi_t tlbehi;
    csr_tlbelo_t [0:0] tlbelo;
    csr_asid_t asid;
    csr_pgd_t pgdl, pgdh, pgd;
    csr_tlbrentry_t tlbrentry;
    // TODO: dmw
    // TODO: tim
} csr_t;

typedef struct packed {
    logic we;
    csr_asid_t asid;
    csr_tlbehi_t tlbehi;
    csr_tlbelo_t [0:0] tlbelo;
    csr_tlbidx_t tlbidx;
} tlb_wr_csr_req_t;

`endif