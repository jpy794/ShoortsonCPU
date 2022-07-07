module Execute (
    output [31:0] ex_result,
    
    // segment-register input
    input [31:0] pc,
    input [31:0] immediate_number,
    input [31:0] rj_read,
    input [31:0] rk_read,
    input [4:0] rd_index,
    output [4:0] rd_index_pass,
    // SIG
    input [1:0] execute_type,
    input [_:0] execute_op_type,
    input [2:0] number_length,
    output [2:0] number_length_pass,
    input [1:0] memory_rw,
    output [1:0] memory_rw_pass,
    input writeback_valid,
    output writeback_valid_pass,
    input writeback_src,
    output writeback_src_pass,

    input clk,

    // forwarding
    input [31:0] mem1_out, mem2_out, wb_out,
    input [4:0] mem1_rd_index, mem2_rd_index, wb_rd_index,
    input mem1_rd_we, mem2_rd_we, wb_rd_we
);

// ALU
ALU alu_instance();

// Mul/Div

endmodule