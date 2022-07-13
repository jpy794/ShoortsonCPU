#include "VDivU.h"
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

    std::unique_ptr<VDivU> divu{new VDivU};

    VerilatedVcdC* tfp = new VerilatedVcdC;
    divu->trace(tfp, 99);  // Trace 99 levels of hierarchy
    tfp->open("DivU.vcd");

    uint32_t n, d;

    divu->rst_n = 0;
    divu->en = 0;
    // reset
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        divu->clk = !divu->clk;
        // change input at negedge
        if(!divu->clk) {
            if(contextp->time() > 5) {
                divu->rst_n = 1;
                break;
            }
        }
        divu->eval();
        tfp->dump(contextp->time());
    }
    // test
    bool first_test = true;
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        divu->clk = !divu->clk;
        // change input at negedge
        if(!divu->clk) {
            divu->en = 0;
            if(divu->done || first_test) {
                if(!first_test) {
                    VL_PRINTF("n: %u, d: %u, q: %u, r: %u", n, d, divu->quotient, divu->remainder);
                    if(divu->quotient == n / d && divu->remainder == n % d) {
                        VL_PRINTF("\t[pass]\n");
                    } else {
                        VL_PRINTF("\t[fail]\n");
                        exit(-1);
                    }
                }
                first_test = false;

                n = rand() % UINT32_MAX;
                d = rand() % UINT32_MAX;

                divu->en = 1;
                divu->dividend = n;
                divu->divisor = d;
            }
        }
        divu->eval();
        tfp->dump(contextp->time());
    }
    divu->final();
    tfp->close();
    exit(0);
}