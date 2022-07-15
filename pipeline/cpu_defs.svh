`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

`include "common_defs.svh"

localparam GRLEN = 32;

/* tlb */
localparam TLB_ENTRY_NUM = 16;
localparam TLB_IDX_WID = $clog2(TLB_ENTRY_NUM);
localparam ASID_WID = 10;

typedef logic [ASID_WID-1:0] asid_t;
typedef logic [5:0] ps_t;

typedef enum ps_t { 
    PS_4KB = 'd12,
    PS_4MB = 'd21
} ps_enum_t;

typedef struct packed {
    logic [PALEN-12-1:0] ppn;
    logic [2-1:0] plv;
    logic [2-1:0] mat;
    logic d;
    logic v;
} tlb_entry_phy_t;

typedef struct packed {
    /* compare part */
    logic [VALEN-13-1:0] vppn;
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

`endif