// c = (a[31:16] * b[31:16] << 32) + (a[15:0] * b[31:16] << 16) +
//     (a[31:16] * b[15:0] << 16) + (a[15:0] * b[15:0])
module Mul (
    input logic clk, rst_n,
    input logic is_flush,
    input logic is_stall,
    input logic [31:0] a, b,
    input logic en, is_signed,
    output logic [63:0] out,
    output logic done
);
    logic [31:0] a_abs, b_abs;
    assign a_abs = (is_signed & a[31]) ? -a : a;
    assign b_abs = (is_signed & b[31]) ? -b : b;

    logic neg_r, is_signed_r;

    logic [63:0] out_abs;
    logic [31:0] p [4];
    
    assign out_abs = {p[0], 32'b0} + {16'b0, p[1], 16'b0} + {16'b0, p[2], 16'b0} + {32'b0, p[3]};

    typedef enum logic [2:0] {
        S_IDLE = 3'b100,
        S_MUL  = 3'b010,
        S_DONE = 3'b001
    } type_State;
    
    type_State state, next;

    initial begin
        state = S_IDLE;
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next;
        end
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            done <= 1'b0;
        end else begin
            unique case(next)
            S_IDLE: begin
                done <= 1'b0;
            end
            S_MUL: begin
                done <= 1'b0;
                p[0] <= a_abs[31:16] * b_abs[31:16];
                p[1] <= a_abs[15:0] * b_abs[31:16];
                p[2] <= a_abs[31:16] * b_abs[15:0];
                p[3] <= a_abs[15:0] * b_abs[15:0];
                neg_r <= (a[31] ^ b[31]);
                is_signed_r <= is_signed;
            end
            S_DONE: begin
                done <= 1'b1;
                if(is_signed_r & neg_r) out <= -out_abs;
                else                    out <= out_abs;
            end
          //  default: //$stop;

            endcase
        end
    end

    always_comb begin
        next = state;
        if(is_flush) begin
            next = S_IDLE;
        end else begin
            unique case(state)
                S_IDLE: begin
                    if(en) next = S_MUL;
                end
                S_MUL: begin
                    next = S_DONE;
                end
                S_DONE: begin
                    if(~is_stall) begin
                        if(en) next = S_MUL;
                        else   next = S_IDLE;
                    end
                end
                default: ;
            endcase
        end
    end
endmodule
