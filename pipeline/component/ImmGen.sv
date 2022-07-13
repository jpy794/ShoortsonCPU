`include "../inc/signals.svh"

module ImmGen (
    output reg [31:0] immediate_number,
    input [31:0] inst,
    input imm_type_t imm_type
);

always @(*) begin
    case (imm_type)
        UI5:    immediate_number = { {27{ 1'b0 }},      inst[14:10]};   // UI5 can merge into UI12
        SI12:   immediate_number = { {20{ inst[21] }},  inst[21:10]};
        UI12:   immediate_number = { {20{ 1'b0 }},      inst[21:10]};
        SI14:   immediate_number = { {18{ inst[23] }},  inst[23:10],    2'b0};  // only LL.W and SC.W
        SI20:   immediate_number = { inst[24:5],        12'b0};                 // only LU12I.W and PCADDU12I
        OFFS16: immediate_number = { {14{ inst[25] }},  inst[25:10],    2'b0};
        OFFS26: immediate_number = { { 4{ inst[9]}},    inst[9:0],      inst[25:10],    2'b0};
        default:immediate_number = 0;
    endcase
end

endmodule