module Decode (
    output [31:0] immediate_number,
    output [31:0] rj_read,
    output [31:0] rk_read,
    output [4:0] rd_index,
    // SIG
    output [1:0] execute_type,      // select which execution component to use
    output [_:0] execute_op_type,
    output [2:0] number_length,     // (signed/unsigned) byte/half/word
    output [1:0] memory_rw,
    output writeback_valid,
    output writeback_src,

    // segment-register input
    input [31:0] pc,
    output [31:0] pc_pass,
    input [31:0] inst,

    input clk,

    // writeback
    input [31:0] rd_wb,
    input [4:0] rd_wb_index,
    input rd_we
);

RegFile regfile_instance(
    .rj_read(rj_read),
    .rk_read(rk_read),
    .rd_write(rd_wb),
    .we(rd_we),
    .rj_index(),
    .rk_index(),
    .rd_index(),
    .clk(clk)
);

endmodule