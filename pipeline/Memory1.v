module Memory1 (
    // segment-register input
    input [31:0] ex_result,
    output [31:0] ex_result_pass,
    input [4:0] rd_index,
    output [4:0] rd_index_pass,
    // SIG
    input [2:0] number_length,
    output [2:0] number_length_pass,
    input [1:0] memory_rw,
    output [1:0] memory_rw_pass,
    input writeback_valid,
    output writeback_valid_pass,
    input writeback_src,
    output writeback_src_pass,

    input clk,

    // interface with TLB
    // interface with ICache
    output [31:0] v_addr
);

endmodule