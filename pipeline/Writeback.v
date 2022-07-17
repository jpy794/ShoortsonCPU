module Writeback (
    output [31:0] rd_wb,
    
    // segment-register input
    input [31:0] ex_result,
    input [31:0] mem_result,
    input [4:0] rd_index,
    output reg [4:0] rd_index_pass,
    // SIG
    input [2:0] number_length,
    input writeback_valid,
    output reg writeback_valid_pass,
    input writeback_src,

    input clear,
    input clk
);

reg [31:0] ex_result_pass;
reg [31:0] mem_result_pass;
reg [2:0] number_length_pass;
reg writeback_src_pass;

always @(posedge clk) begin
    if (clear) begin
        
    end
    else begin
        ex_result_pass <= ex_result;
        mem_result_pass <= mem_result;
        rd_index_pass <= rd_index;
        number_length_pass <= number_length;
        writeback_valid_pass <= writeback_valid;
        writeback_src_pass <= writeback_src;
    end
end

endmodule