`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

// `define FAKE_CACHE
// `define FORCE_TO_CACHE
localparam PALEN = 32;
localparam VALEN = 32;

typedef logic [31:0] u32_t;
typedef logic [63:0] u64_t;
typedef logic [VALEN-1:0] virt_t;
typedef logic [PALEN-1:0] phy_t;

typedef enum logic [1:0] {
    BYTE = 2'b00,
    HALF_WORD = 2'b01,
    WORD = 2'b10
} byte_type_t;

typedef logic [1:0] byte_en_t;

/* cacheop */
typedef enum logic [1:0] {
    CAC_INIT = 2'b00,
    CAC_IDX_INV = 2'b01,
    CAC_SRCH_INV = 2'b10,
    CAC_NOP = 2'b11
} cache_op_t;

/* cache req */
typedef enum logic [1:0] {
    DCAC_NOP = 2'd0,
    DCAC_LD = 2'd1,
    DCAC_ST = 2'd2
} dcache_req_t;

typedef enum logic {
    ICAC_NOP = 1'b0,
    ICAC_LD = 1'b1
} icache_req_t;

`endif