`include "inc/signals.svh"

module Execute (
    output reg [31:0] ex_result,
    output br_taken,
    
    // segment-register input
    input [31:0] pc_RegInput,
    input [31:0] immediate_number_RegInput,
    input [31:0] rj_read_RegInput,
    input [31:0] rk_read_RegInput,
    input [4:0] rd_index_RegInput,
    output reg [4:0] rd_index,
    // SIG
    input execute_type_t execute_type_RegInput,
    input [3:0] execute_op_type_RegInput,
    input alu_src1_sel_t alu_src1_sel_RegInput,
    input alu_src2_sel_t alu_src2_sel_RegInput,
    input [3:0] compare_cond,
    input branch,
    input [2:0] number_length_RegInput,
    output reg [2:0] number_length,
    input [1:0] memory_rw_RegInput,
    output reg [1:0] memory_rw,
    input writeback_valid_RegInput,
    output reg writeback_valid,
    input writeback_src_RegInput,
    output reg writeback_src,

    input stall_RegInput, clear_RegInput,
    output reg clear,
    output busy,
    input clk,

    // forwarding
    input [31:0] mem1_out, mem2_out, wb_out,
    input [4:0] mem1_rd_index, mem2_rd_index, wb_rd_index,
    input mem1_rd_we, mem2_rd_we, wb_rd_we
);

reg [31:0] pc;
reg [31:0] immediate_number;
reg [31:0] rj_read;
reg [31:0] rk_read;
execute_type_t execute_type;
reg [3:0] execute_op_type;
alu_src1_sel_t alu_src1_sel;
alu_src2_sel_t alu_src2_sel;

always @(posedge clk) begin
    if (clear_RegInput) begin
        clear <= 1;
    end
    else begin
        clear <= 0;
        if (stall_RegInput) begin
            pc                  <= pc;
            immediate_number    <= immediate_number;
            rj_read             <= rj_read;
            rk_read             <= rk_read;
            rd_index            <= rd_index;
            execute_type        <= execute_type;
            execute_op_type     <= execute_op_type;
            alu_src1_sel        <= alu_src1_sel;
            alu_src2_sel        <= alu_src2_sel;
            number_length       <= number_length;
            memory_rw           <= memory_rw;
            writeback_valid     <= writeback_valid;
            writeback_src       <= writeback_src;
        end
        else begin
            pc                  <= pc_RegInput;
            immediate_number    <= immediate_number_RegInput;
            rj_read             <= rj_read_RegInput;
            rk_read             <= rk_read_RegInput;
            rd_index            <= rd_index_RegInput;
            execute_type        <= execute_type_RegInput;
            execute_op_type     <= execute_op_type_RegInput;
            alu_src1_sel        <= alu_src1_sel_RegInput;
            alu_src2_sel        <= alu_src2_sel_RegInput;
            number_length       <= number_length_RegInput;
            memory_rw           <= memory_rw_RegInput;
            writeback_valid     <= writeback_valid_RegInput;
            writeback_src       <= writeback_src_RegInput;
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
wire [63:0] mul_out;
wire mul_en, mul_signed, mul_done;

assign mul_en = &(execute_type & MUL);
assign mul_signed = &(execute_op_type & HI);

Mul mul_instance(
    .clk        (clk        ),
    .rst_n      (~clear     ),
    .a          (rj_read    ),
    .b          (rk_read    ),
    .en         (mul_en     ),
    .is_signed  (mul_signed ),
    .out        (mul_out    ),
    .done       (mul_done   )
);

// Div
wire [31:0] div_out_q, div_out_r;
wire div_en, div_signed, div_done;

assign div_en = &(execute_type & DIV);
assign div_signed = &(execute_op_type & Q) | &(execute_op_type & R);

Div div_instance(
    .clk        (clk        ),
    .rst_n      (~clear     ),
    .dividend   (rj_read    ),
    .divisor    (rk_read    ),
    .en         (div_en     ),
    .is_signed  (div_signed ),
    .quotient   (div_out_q  ),
    .remainder  (div_out_r  ),
    .done       (div_done   )
);

assign busy = (&(execute_type & MUL) & ~mul_done) | (&(execute_type & DIV) & ~div_done);

// Comp
reg comp_out;
assign br_taken = comp_out & branch;

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

always @(*) begin
    case (compare_cond[3])
        0: comp_out = |(compare_cond[2:0] & comp_u);
        1: comp_out = |(compare_cond[2:0] & comp_s);
    endcase
end

always @(*) begin
    case (execute_type)
        ALU: ex_result = alu_out;
        MUL: begin
            if (execute_op_type == LOW)
                ex_result = mul_out[31:0];
            else
                ex_result = mul_out[63:32];
        end
        DIV: begin
            if (execute_op_type == Q || execute_op_type == QU)
                ex_result = div_out_q;
            else
                ex_result = div_out_r;
        end
        CMP: ex_result = {31'b0, comp_out};
        default: ex_result = NOTCARE;
    endcase
end

endmodule