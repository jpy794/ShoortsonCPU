`include "../inc/signals.svh"

module ALU (
    output reg [31:0] alu_out,
    input [31:0] alu_src1,
    input [31:0] alu_src2,
    input alu_op_type_t op_type
);

always @(*) begin
    case (op_type)
        ADD: begin
            alu_out = alu_src1 + alu_src2;
        end
        SUB: begin
            alu_out = alu_src1 - alu_src2;
        end
        AND: begin
            alu_out = alu_src1 & alu_src2;
        end
        OR: begin
            alu_out = alu_src1 | alu_src2;
        end
        NOR: begin
            alu_out = ~(alu_src1 | alu_src2);
        end
        XOR: begin
            alu_out = alu_src1 ^ alu_src2;
        end
        SLL: begin
            alu_out = alu_src1 << alu_src2[4:0];
        end
        SRL: begin
            alu_out = alu_src1 >> alu_src2[4:0];
        end
        SRA: begin
            alu_out = alu_src1 >>> alu_src2[4:0];
        end
        default: begin
            alu_out = 0;
        end
    endcase
end

endmodule