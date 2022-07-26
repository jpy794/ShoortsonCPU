`include "cpu_defs.svh"

module BRU (
    input bru_op_t op,
    input u32_t a, b,
    output logic taken
);

    logic eq, lt, ltu;
    assign eq = (a == b);
    assign lt = ($signed(a) < $signed(b));
    assign ltu = (a < b);

    always_comb begin
        taken = '1;
        unique case(op)
        BEQ: taken = eq;
        BNE: taken = ~eq;
        BLT: taken = lt;
        BLTU: taken = ltu;
        BGE: taken = ~lt;
        BGEU: taken = ~ltu;
        B: taken = 1'b1;
        BL: taken = 1'b1;
        JIRL: taken = 1'b1;
        default: //$stop;
            taken = 1'b1;
        endcase
    end

endmodule