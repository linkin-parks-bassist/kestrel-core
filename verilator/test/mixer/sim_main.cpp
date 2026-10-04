#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vpostprocessing_stage.h"
#include "test_framework.h"

std::vector<Test>& get_tests()
{
    static std::vector<Test> tests;
    return tests;
}

static vluint64_t sim_time = 0;
static VerilatedVcdC* g_current_tfp = nullptr;
static const char* g_current_test_name = nullptr;

double sc_time_stamp() { return sim_time; }

void settle(Vpostprocessing_stage* dut, VerilatedVcdC* tfp)
{
    dut->eval();
}

void tick(Vpostprocessing_stage* dut, VerilatedVcdC* tfp)
{
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);

    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);
}

void test_fail_eq(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  long long expected,
                  const char* file,
                  int line)
{
    printf("FAIL at %s:%d: %s != %s (got %lld expected %lld)\n",
           file, line, expr_a, expr_b, got, expected);

#ifdef TRACE
    if (g_current_tfp) {
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }

    if (g_current_test_name) {
        printf("Trace saved to %s.vcd\n", g_current_test_name);
    }
#endif

    exit(1);
}

void test_fail_ne(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  const char* file,
                  int line)
{
    printf("FAIL at %s:%d: %s == %s (both %lld, expected different)\n",
           file, line, expr_a, expr_b, got);

#ifdef TRACE
    if (g_current_tfp) {
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }

    if (g_current_test_name) {
        printf("Trace saved to %s.vcd\n", g_current_test_name);
    }
#endif

    exit(1);
}

void test_fail_u(const char* expr_a,
                 const char* expr_b,
                 unsigned long long got,
                 unsigned long long expected,
                 unsigned width,
                 const char* file,
                 int line)
{
    printf("FAIL at %s:%d: %s != %s (got %llu expected %llu, width=%u)\n",
           file, line, expr_a, expr_b, got, expected, width);

#ifdef TRACE
    if (g_current_tfp) {
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }

    if (g_current_test_name) {
        printf("Trace saved to %s.vcd\n", g_current_test_name);
    }
#endif

    exit(1);
}

void test_fail_s(const char* expr_a,
                 const char* expr_b,
                 long long got,
                 long long expected,
                 unsigned width,
                 const char* file,
                 int line)
{
    printf("FAIL at %s:%d: %s != %s (got %lld expected %lld, width=%u)\n",
           file, line, expr_a, expr_b, got, expected, width);

#ifdef TRACE
    if (g_current_tfp) {
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }

    if (g_current_test_name) {
        printf("Trace saved to %s.vcd\n", g_current_test_name);
    }
#endif

    exit(1);
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);

    Vpostprocessing_stage* dut = new Vpostprocessing_stage;

    dut->clk = 0;
    dut->reset = 0;

    VerilatedVcdC* tfp = nullptr;

#ifdef TRACE
    Verilated::traceEverOn(true);
#endif

    auto& tests = get_tests();

    for (auto& t : tests) {
        printf("=== %s ===\n", t.name);
        g_current_test_name = t.name;

#ifdef TRACE
        tfp = new VerilatedVcdC;
        g_current_tfp = tfp;

        char fname[256];
        snprintf(fname, sizeof(fname), "%s.vcd", t.name);

        dut->trace(tfp, 99);
        tfp->open(fname);
#endif

        sim_time = 0;

        dut->reset = 1;
        for (int i = 0; i < 5; i++) tick(dut, tfp);
        dut->reset = 0;
        settle(dut, tfp);

        t.fn(dut, tfp);

#ifdef TRACE
        if (tfp) {
            tfp->flush();
            tfp->close();
            delete tfp;
            tfp = nullptr;
        }
        g_current_tfp = nullptr;
#endif
        g_current_test_name = nullptr;
    }

    printf("All tests passed.\n");

    delete dut;
    return 0;
}
