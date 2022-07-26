`include "cpu_defs.svh"

module ALU (
    input alu_op_t op,
    input u32_t a,
    input u32_t b,
    output u32_t out
);

always_comb begin
    unique case (op)
        ADD:    out = a + b;
        SUB:    out = a - b;
        AND:    out = a & b;
        OR:     out = a | b;
        NOR:    out = ~(a | b);
        XOR:    out = a ^ b;
        SLL:    out = a << b[4:0];
        SRL:    out = a >> b[4:0];
        SRA:    out = a >>> b[4:0];
        SLT:    out = {31'b0, $signed(a) < $signed(b)};
        SLTU:   out = {31'b0, a < b};
        default: out = '0;

    endcase
end

endmodule