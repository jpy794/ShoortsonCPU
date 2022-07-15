`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

localparam PALEN = 32;
localparam VALEN = 32;

typedef logic [31:0] u32_t;
typedef logic [VALEN-1:0] virt_t;
typedef logic [PALEN-1:0] phy_t;

`endif