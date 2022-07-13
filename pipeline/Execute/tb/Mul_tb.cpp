#include "VMul.h"
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

    std::unique_ptr<VMul> mul{new VMul};

    VerilatedVcdC* tfp = new VerilatedVcdC;
    mul->trace(tfp, 99);  // Trace 99 levels of hierarchy
    tfp->open("Mul.vcd");

    int32_t a, b;

    mul->rst_n = 0;
    mul->en = 0;
    // reset
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        mul->clk = !mul->clk;
        // change input at negedge
        if(!mul->clk) {
            if(contextp->time() > 5) {
                mul->rst_n = 1;
                break;
            }
        }
        mul->eval();
        tfp->dump(contextp->time());
    }
    // test
    mul->is_signed = 1;
    bool first_test = true;
    while (contextp->time() < TIME_LIMIT && !contextp->gotFinish()) {
        contextp->timeInc(1);
        mul->clk = !mul->clk;
        // change input at negedge
        if(!mul->clk) {
            mul->en = 0;
            if(mul->done || first_test) {
                if(!first_test) {
                    VL_PRINTF("a: %d, b: %d, out: %lld", a, b, mul->out);
                    if(mul->out == (int64_t)a * (int64_t)b) {
                        VL_PRINTF("\t[pass]\n");
                    } else {
                        VL_PRINTF("\t[fail]\n");
                        VL_PRINTF("correct out: %lld\n", (int64_t)a * (int64_t)b);
                        mul->final();
                        tfp->close();
                        exit(-1);
                    }
                }
                first_test = false;

                rand() % 2 ? a = rand() % INT32_MAX : a = -(rand() % INT32_MAX);
                rand() % 2 ? b = rand() % INT32_MAX : b = -(rand() % INT32_MAX);

                mul->en = 1;
                mul->a = a;
                mul->b = b;
            }
        }
        mul->eval();
        tfp->dump(contextp->time());
    }
    mul->final();
    tfp->close();
    exit(0);
}