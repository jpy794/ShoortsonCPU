module Memory1 (
    // segment-register input
    input [31:0] ex_result,
    output reg [31:0] ex_result_pass,
    input [4:0] rd_index,
    output reg [4:0] rd_index_pass,
    // SIG
    input [2:0] number_length,
    output reg [2:0] number_length_pass,
    input [1:0] memory_rw,
    output reg [1:0] memory_rw_pass,
    input writeback_valid,
    output reg writeback_valid_pass,
    input writeback_src,
    output reg writeback_src_pass,

    input stall, clear,
    output reg clear_pass,
    input clk,

    // interface with TLB
    // interface with ICache
    output [31:0] v_addr
);

always @(posedge clk) begin
    if (clear) begin
        clear_pass <= 1;
    end
    else begin
        clear_pass <= 0;
        if (stall) begin
            ex_result_pass <= ex_result_pass;
            rd_index_pass <= rd_index_pass;
            number_length_pass <= number_length_pass;
            memory_rw_pass <= memory_rw_pass;
            writeback_valid_pass <= writeback_valid_pass;
            writeback_src_pass <= writeback_src_pass;
        end
        else begin
            ex_result_pass <= ex_result;
            rd_index_pass <= rd_index;
            number_length_pass <= number_length;
            memory_rw_pass <= memory_rw;
            writeback_valid_pass <= writeback_valid;
            writeback_src_pass <= writeback_src;
        end
    end
end

endmodule