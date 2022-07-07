module Writeback (
    output [31:0] rd_wb,
    
    // segment-register input
    input [31:0] ex_result,
    input [31:0] mem_result,
    input [4:0] rd_index,
    output [4:0] rd_index_pass,
    // SIG
    input [2:0] number_length,
    input writeback_valid,
    output writeback_valid_pass,

    input clk
);

endmodule