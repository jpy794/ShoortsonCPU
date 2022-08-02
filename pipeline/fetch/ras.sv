`include "cpu_defs.svh"

module RAS(
    output virt_t ra,
    output logic ra_valid,
    input logic pop,        // pop can only be set when ra_valid
    input virt_t npc,
    input logic push,       // pop and push cannot be set at the same time
    input logic clk, rst_n
);
    
    virt_t ra_stack [RA_STACK_SIZE];
    logic [RA_STACK_IDX_WID-1 : 0] ra_stack_top, ra_stack_base;     // stack empty: top == base

    assign ra = ra_stack[ra_stack_top - 1];
    assign ra_valid = (ra_stack_top != ra_stack_base);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            ra_stack_top <= '0;
            ra_stack_base <= '0;
        end
        else begin
            if (push) begin
                ra_stack_top <= ra_stack_top + 1;
                if (ra_stack_top == ra_stack_base - 1) begin
                    ra_stack_base <= ra_stack_base + 1;
                end
            end
            else if (pop & ra_valid) begin
                ra_stack_top <= ra_stack_top - 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (push) begin
            ra_stack[ra_stack_top] <= npc;
        end
    end

endmodule