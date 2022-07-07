module Fetch1 (
    output [31:0] pc,

    // segment-register input
    input [31:0] next_pc,
    
    input clk,

    // interface with TLB
    // interface with ICache
    output [31:0] v_addr
);
    
endmodule