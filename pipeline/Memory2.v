module Memory2 (
    output [31:0] mem_result,

    // segment-register input
    input [31:0] ex_result_RegInput,
    output reg [31:0] ex_result,
    input [4:0] rd_index_RegInput,
    output reg [4:0] rd_index,
    // SIG
    input [2:0] number_length_RegInput,
    output reg [2:0] number_length,
    input [1:0] memory_rw_RegInput,
    input writeback_valid_RegInput,
    output reg writeback_valid,
    input writeback_src_RegInput,
    output reg writeback_src,

    input stall_RegInput, clear_RegInput,
    output reg clear,
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

reg [1:0] memory_rw;

always @(posedge clk) begin
    if (clear_RegInput) begin
        clear <= 1;
    end
    else begin
        clear <= 0;
        if (stall_RegInput) begin
            ex_result       <= ex_result;
            rd_index        <= rd_index;
            number_length   <= number_length;
            memory_rw       <= memory_rw;
            writeback_valid <= writeback_valid;
            writeback_src   <= writeback_src;
        end
        else begin
            ex_result       <= ex_result_RegInput;
            rd_index        <= rd_index_RegInput;
            number_length   <= number_length_RegInput;
            memory_rw       <= memory_rw_RegInput;
            writeback_valid <= writeback_valid_RegInput;
            writeback_src   <= writeback_src_RegInput;
        end
    end
end

endmodule