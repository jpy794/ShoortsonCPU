#include "VDiv.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <memory>
#include <random>

const uint64_t TIME_LIMIT = 200000;

int main(int argc, char **argv, char **env)
{
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    Verilated::traceEverOn(true);
    contextp->commandArgs(argc, argv);

    std::unique_ptr<VDiv> div{new VDiv};

    VerilatedVcdC* tfp = new VerilatedVcdC;
    div->trace(tfp, 99);  // Trace 99 levels of hierarchy
    tfp->open("Div.vcd");

    int32_t n, d;

    div->rst_n = 0;
    div->en = 0;
    // reset
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        div->clk = !div->clk;
        // change input at negedge
        if(!div->clk) {
            if(contextp->time() > 5) {
                div->rst_n = 1;
                break;
            }
        }
        div->eval();
        tfp->dump(contextp->time());
    }
    // test
    div->is_signed = 1;
    bool first_test = true;
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        div->clk = !div->clk;
        // change input at negedge
        if(!div->clk) {
            div->en = 0;
            if(div->done || first_test) {
                if(!first_test) {
                    VL_PRINTF("n: %d, d: %d, q: %d, r: %d", n, d, div->quotient, div->remainder);
                    if(div->quotient == n / d && div->remainder == n % d) {
                        VL_PRINTF("\t[pass]\n");
                    } else {
                        VL_PRINTF("\t[fail]\n");
                        exit(-1);
                    }
                }
                first_test = false;

                rand() % 2 ? n = rand() % INT32_MAX : n = -(rand() % INT32_MAX);
                rand() % 2 ? d = rand() % INT32_MAX : d = -(rand() % INT32_MAX);

                div->en = 1;
                div->dividend = n;
                div->divisor = d;
            }
        }
        div->eval();
        tfp->dump(contextp->time());
    }
    div->final();
    tfp->close();
    exit(0);
}