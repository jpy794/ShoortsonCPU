`include "inc/signals.svh"

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
    input execute_type_t execute_type,
    input [3:0] execute_op_type,
    input alu_src1_sel_t alu_src1_sel,
    input alu_src2_sel_t alu_src2_sel,
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