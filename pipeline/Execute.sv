`include "inc/signals.svh"

module Execute (
    output [31:0] ex_result,
    
    // segment-register input
    input [31:0] pc,
    input [31:0] immediate_number,
    input [31:0] rj_read,
    input [31:0] rk_read,
    input [4:0] rd_index,
    output reg [4:0] rd_index_pass,
    // SIG
    input execute_type_t execute_type,
    input [3:0] execute_op_type,
    input alu_src1_sel_t alu_src1_sel,
    input alu_src2_sel_t alu_src2_sel,
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

    // forwarding
    input [31:0] mem1_out, mem2_out, wb_out,
    input [4:0] mem1_rd_index, mem2_rd_index, wb_rd_index,
    input mem1_rd_we, mem2_rd_we, wb_rd_we
);

reg [31:0] pc_pass;
reg [31:0] immediate_number_pass;
reg [31:0] rj_read_pass;
reg [31:0] rk_read_pass;
execute_type_t execute_type_pass;
reg [3:0] execute_op_type_pass;
alu_src1_sel_t alu_src1_sel_pass;
alu_src2_sel_t alu_src2_sel_pass;

always @(posedge clk) begin
    if (clear) begin
        clear_pass <= 1;
    end
    else begin
        clear_pass <= 0;
        if (stall) begin
            pc_pass <= pc_pass;
            immediate_number_pass <= immediate_number_pass;
            rj_read_pass <= rj_read_pass;
            rk_read_pass <= rk_read_pass;
            rd_index_pass <= rd_index_pass;
            execute_type_pass <= execute_type_pass;
            execute_op_type_pass <= execute_op_type_pass;
            alu_src1_sel_pass <= alu_src1_sel_pass;
            alu_src2_sel_pass <= alu_src2_sel_pass;
            number_length_pass <= number_length_pass;
            memory_rw_pass <= memory_rw_pass;
            writeback_valid_pass <= writeback_valid_pass;
            writeback_src_pass <= writeback_src_pass;
        end
        else begin
            pc_pass <= pc;
            immediate_number_pass <= immediate_number;
            rj_read_pass <= rj_read;
            rk_read_pass <= rk_read;
            rd_index_pass <= rd_index;
            execute_type_pass <= execute_type;
            execute_op_type_pass <= execute_op_type;
            alu_src1_sel_pass <= alu_src1_sel;
            alu_src2_sel_pass <= alu_src2_sel;
            number_length_pass <= number_length;
            memory_rw_pass <= memory_rw;
            writeback_valid_pass <= writeback_valid;
            writeback_src_pass <= writeback_src;
        end
    end
end

// ALU
wire [31:0] alu_out;
reg [31:0] alu_src1, alu_src2;

always @(*) begin
    case (alu_src1_sel)
        RJ:     alu_src1 = rj_read;
        PC:     alu_src1 = pc;
        ZERO :  alu_src1 = 0;
        default:alu_src1 = 0;
    endcase
end

always @(*) begin
    case (alu_src2_sel)
        RK:     alu_src2 = rk_read;
        IMM:    alu_src2 = immediate_number;
        default:alu_src2 = 0;
    endcase
end

ALU alu_instance(
    .alu_out    (alu_out),
    .alu_src1   (alu_src1),
    .alu_src2   (alu_src2),
    .op_type    (execute_op_type)
);

// Mul

// Div

// Comp
wire comp_out;
reg [2:0] comp_u, comp_s;

always @(*) begin
    if (rj_read < rk_read) comp_u[0] = 1;
    else comp_u[0] = 0;
    if (rj_read == rk_read) comp_u[1] = 1;
    else comp_u[1] = 0;
    if (rj_read > rk_read) comp_u[2] = 1;
    else comp_u[2] = 0;
end

always @(*) begin
    if (rj_read[31] == 1 && rk_read[31] == 0) comp_s = 3'b100;
    else if (rj_read[31] == 0 && rk_read[31] == 1) comp_s = 3'b001;
    else if (rj_read[31] == 1 && rk_read[31] == 1) begin
        if (rj_read[30:0] > rk_read[30:0]) comp_s[0] = 1;
        else comp_s[0] = 0;
        if (rj_read[30:0] == rk_read[30:0]) comp_s[1] = 1;
        else comp_s[1] = 0;
        if (rj_read[30:0] < rk_read[30:0]) comp_s[2] = 1;
        else comp_s[2] = 0;
    end
    else begin
        if (rj_read[30:0] < rk_read[30:0]) comp_s[0] = 1;
        else comp_s[0] = 0;
        if (rj_read[30:0] == rk_read[30:0]) comp_s[1] = 1;
        else comp_s[1] = 0;
        if (rj_read[30:0] > rk_read[30:0]) comp_s[2] = 1;
        else comp_s[2] = 0;
    end
end

endmodule