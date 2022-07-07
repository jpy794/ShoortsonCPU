module ALU (
    output [31:0] alu_out,
    input [31:0] alu_src1,
    input [31:0] alu_src2,
    input [_:0] op_type
);

always @(*) begin
    case (op_type)
        : 
        default: 
    endcase
end

endmodule