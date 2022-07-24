`include "../cpu_defs.svh"

module ALU (
    input alu_op_t op,
    input u32_t a,
    input u32_t b,
    output u32_t out
);

always_comb begin
    unique case (op_type)
        ADD: begin
            out = a + b;
        end
        SUB: begin
            out = a - b;
        end
        AND: begin
            out = a & b;
        end
        OR: begin
            out = a | b;
        end
        NOR: begin
            out = ~(a | b);
        end
        XOR: begin
            out = a ^ b;
        end
        SLL: begin
            out = a << b[4:0];
        end
        SRL: begin
            out = a >> b[4:0];
        end
        SRA: begin
            out = a >>> b[4:0];
        end
        default: begin
            out = '0;
        end
    endcase
end

endmodule