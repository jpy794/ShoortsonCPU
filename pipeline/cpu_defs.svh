`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

`include "common_defs.svh"

localparam GRLEN = 32;

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

/* tlb ins */
typedef struct packed {
    virt_t va;
} csr_badv_t;

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
} csr_tlbentry_t;

typedef struct packed {
    esubcode_ecode_t esubcode_ecode;
} csr_estat_t;

`endif