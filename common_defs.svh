`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

`define FAKE_CACHE
`define CACHED_TO_TEST
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

`endif