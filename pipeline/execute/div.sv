// 2-radix non-restoring division
// TODO: support flush
module Div(
    input clk, rst_n,
    input logic is_flush,
    input logic is_stall,
    input logic [31:0] dividend,
    input logic [31:0] divisor,
    input logic en, is_signed,
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic done
);

    logic [32:0] dividend_abs, divisor_abs;
    assign dividend_abs = dividend[31] ? -{dividend[31], dividend} : {dividend[31], dividend};
    assign divisor_abs = divisor[31] ? -{divisor[31], divisor} : {divisor[31], divisor};

    logic [32:0] a, m, m_neg, q;
    logic [32:0] a_next, q_next, m_next, m_neg_next;

    logic [31:0] quotient_abs, remainder_abs;
    assign quotient_abs = q[31:0];
    assign remainder_abs = a[32] ? a[31:0] + m[31:0] : a[31:0];

    typedef enum logic [1:0] {
        S_IDLE = 2'b00,
        S_INIT = 2'b01,
        S_DIV  = 2'b10,
        S_DONE = 2'b11
    } type_State;
    
    type_State state, next;
    logic [31:0] cnt, cnt_next;

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next;
            cnt <= cnt_next;
            m <= m_next;
            m_neg <= m_neg_next;
            a <= a_next;
            q <= q_next;
        end
    end

    always_comb begin
        next = state;
        cnt_next = (cnt >> 1);
        done = 1'b0;
        m_next = m;
        a_next = a;
        q_next = q;
        m_neg_next = m_neg;

        remainder = remainder_abs;
        quotient = quotient_abs;
        unique case(state)
            S_IDLE: begin
                if(en) begin
                    next = S_DIV;
                    cnt_next = {1'b1, 31'b0};
                    a_next = 33'b0;
                    q_next = is_signed ? dividend_abs : {1'b0, dividend};
                    m_next = is_signed ? divisor_abs : {1'b0, divisor};
                    m_neg_next = -m_next;
                end
            end
            S_DIV: begin
                a_next = {a[31:0], q[31]} + (a[32] ? m : m_neg);
                q_next = {q[31:0], ~a_next[32]};

                if(cnt[0]) next = S_DONE;
            end
            S_DONE: begin
                done = 1'b1;
                if(is_signed) begin
                    unique case({dividend[31], divisor[31]})
                        2'b00:  begin
                            remainder = remainder_abs;
                            quotient = quotient_abs;
                        end
                        2'b11: begin
                            remainder = -remainder_abs;
                            quotient = quotient_abs;
                        end
                        2'b10: begin
                            remainder = -remainder_abs;
                            quotient = -quotient_abs;
                        end
                        2'b01: begin
                            remainder = remainder_abs;
                            quotient = -quotient_abs;
                        end
                    endcase
                end else begin
                    remainder = remainder_abs;
                    quotient = quotient_abs;
                end
                
                if(~is_stall) next = S_IDLE;
            end
            default: ;
        endcase
    end

endmodule
