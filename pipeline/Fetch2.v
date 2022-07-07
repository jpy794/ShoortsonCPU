module Fetch2 (
    output [31:0] inst,

    // segment-register input
    input [31:0] pc,
    output [31:0] pc_pass,

    input clk,

    // interface with TLB
    input tlb_hit,
    input [63:0] tlb_read,
    
    // interface with ICache
    output [31:0] p_addr,
    output p_addr_valid,
    input cache_ready,
    input [31:0] cache_read
);

endmodule