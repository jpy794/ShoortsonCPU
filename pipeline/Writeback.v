module Writeback (
    output [31:0] rd_wb,
    
    // segment-register input
    input [31:0] ex_result_RegInput,
    input [31:0] mem_result_RegInput,
    input [4:0] rd_index_RegInput,
    output reg [4:0] rd_index,
    // SIG
    input [2:0] number_length_RegInput,
    input writeback_valid_RegInput,
    output reg writeback_valid,
    input writeback_src_RegInput,

    input clear_RegInput,
    input clk
);

reg [31:0] ex_result;
reg [31:0] mem_result;
reg [2:0] number_length;
reg writeback_src;

always @(posedge clk) begin
    if (clear_RegInput) begin
        
    end
    else begin
        ex_result       <= ex_result_RegInput;
        mem_result      <= mem_result_RegInput;
        rd_index        <= rd_index_RegInput;
        number_length   <= number_length_RegInput;
        writeback_valid <= writeback_valid_RegInput;
        writeback_src   <= writeback_src_RegInput;
    end
end

endmodule