// 2-radix non-restoring division
// TODO: support flush
module Div(
    input clk, rst_n,
    input logic [31:0] dividend,
    input logic [31:0] divisor,
    input logic en, is_signed,
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic done
);

    logic [31:0] dividend_abs, divisor_abs;
    assign dividend_abs = dividend[31] ? -dividend : dividend;
    assign divisor_abs = divisor[31] ? -divisor : divisor;

    logic dividend_neg_r, divisor_neg_r, is_signed_r;

    logic [63:0] r;
    logic [31:0] d, q; // 0 for -1 in q

    logic [31:0] q_standrd;
    assign q_standrd = q - ~q;

    logic [31:0] quotient_abs, remainder_abs;
    always_comb begin
        if(r[63]) begin
            // r < 0
            remainder_abs = r[63:32] + d;
            quotient_abs = q_standrd - 1;
        end else begin
            // r >= 0
            remainder_abs = r[63:32];
            quotient_abs = q_standrd;
        end
    end

    typedef enum logic [1:0] {
        S_IDLE = 2'b00,
        S_INIT = 2'b01,
        S_DIV  = 2'b10,
        S_DONE = 2'b11
    } type_State;
    
    type_State state, next;
    logic [31:0] cnt, cnt_next;

    initial begin
        state = S_IDLE;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next;
            cnt <= cnt_next;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            done <= 1'b0;
        end else begin
            unique case(next)
            S_IDLE: begin
                done <= 1'b0;
            end
            S_INIT: begin
                done <= 1'b0;
                q <= 32'b0;

                dividend_neg_r <= dividend[31];
                divisor_neg_r <= divisor[31];
                is_signed_r <= is_signed;

                if(is_signed) begin
                    r <= {32'b0, dividend_abs};
                    d <= divisor_abs;
                end else begin
                    r <= {32'b0, dividend};
                    d <= divisor;
                end
            end
            S_DIV: begin            // repeat 32 times
                done <= 1'b0;
                if(r[63]) begin
                    // r < 0
                    r <= {r[62:0], 1'b0} + {d, 32'b0};
                    q <= {q[30:0], 1'b0};
                end else begin
                    // r >= 0
                    r <= {r[62:0], 1'b0} - {d, 32'b0};
                    q <= {q[30:0], 1'b1};
                end
            end
            S_DONE: begin
                done <= 1'b1;
                if(is_signed_r) begin
                    unique case({dividend_neg_r, divisor_neg_r})
                    2'b00:  begin
                        remainder <= remainder_abs;
                        quotient <= quotient_abs;
                    end
                    2'b11: begin
                        remainder <= -remainder_abs;
                        quotient <= quotient_abs;
                    end
                    2'b10: begin
                        remainder <= -remainder_abs;
                        quotient <= -quotient_abs;
                    end
                    2'b01: begin
                        remainder <= remainder_abs;
                        quotient <= -quotient_abs;
                    end
                    endcase
                end else begin
                    remainder <= remainder_abs;
                    quotient <= quotient_abs;
                end
            end
            // full case
            endcase
        end
    end

    always_comb begin
        next = state;
        cnt_next = cnt;
        unique case(state)
            S_IDLE: begin
                if(en)          next = S_INIT;
            end
            S_INIT: begin
                                next = S_DIV;
                                cnt_next = {1'b1, 31'b0};
            end
            S_DIV: begin
                if(cnt[0])      next = S_DONE;
                                cnt_next = cnt >> 1;
            end
            S_DONE: begin
                if(en)          next = S_INIT;
                else            next = S_IDLE;
            end
            // full case
        endcase
    end

endmodule
