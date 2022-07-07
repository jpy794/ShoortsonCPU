module Memory2 (
    output [31:0] mem_result,

    // segment-register input
    input [31:0] ex_result,
    output [31:0] ex_result_pass,
    input [4:0] rd_index,
    output [4:0] rd_index_pass,
    // SIG
    input [2:0] number_length,
    output [2:0] number_length_pass,
    input [1:0] memory_rw,
    input writeback_valid,
    output writeback_valid_pass,

    input clk,

    // interface with TLB
    input tlb_hit,
    input [63:0] tlb_read,
    
    // interface with DCache
    output [31:0] p_addr,
    output p_addr_valid,
    output [1:0] cache_rw,
    output [31:0] cache_write,
    input cache_ready,
    input [31:0] cache_read
);

endmodule