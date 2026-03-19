#!/usr/bin/env python3

import textwrap
import re
import os

SRC_ROOT = "../src"
OUT_ROOT = "./test"

TEST_MODULES = [
    "mixer",
    "health_monitor",
    "control_unit",
    "filter_master",
    "delay_master",
    "multiply_stage"
]

module_re = re.compile(r"\bmodule\s+(\w+)\b")


def find_modules():
    wanted = set(TEST_MODULES)
    found = {}

    for root, _, files in os.walk(SRC_ROOT):
        for f in files:
            if not f.endswith(".v"):
                continue

            path = os.path.join(root, f)

            with open(path) as fh:
                text = fh.read()

            for name in module_re.findall(text):
                if name in wanted:
                    if name in found:
                        print(f"[!] warning: module {name} found more than once")
                        print(f"    first:  {found[name]}")
                        print(f"    second: {path}")
                    else:
                        found[name] = path

    missing = [name for name in TEST_MODULES if name not in found]
    for name in missing:
        print(f"[!] warning: requested module {name} not found under {SRC_ROOT}")

    return [name for name in TEST_MODULES if name in found]


SIM_MAIN_TEMPLATE = textwrap.dedent("""\
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "V{module}.h"
#include "test_framework.h"

std::vector<Test>& get_tests()
{{
    static std::vector<Test> tests;
    return tests;
}}

static vluint64_t sim_time = 0;
static VerilatedVcdC* g_current_tfp = nullptr;
static const char* g_current_test_name = nullptr;

double sc_time_stamp() {{ return sim_time; }}

void settle(V{module}* dut, VerilatedVcdC* tfp)
{{
    dut->eval();
}}

void tick(V{module}* dut, VerilatedVcdC* tfp)
{{
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);

    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);
}}

void test_fail_eq(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  long long expected,
                  const char* file,
                  int line)
{{
    printf("FAIL at %s:%d: %s != %s (got %lld expected %lld)\\n",
           file, line, expr_a, expr_b, got, expected);

#ifdef TRACE
    if (g_current_tfp) {{
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }}

    if (g_current_test_name) {{
        printf("Trace saved to %s.vcd\\n", g_current_test_name);
    }}
#endif

    exit(1);
}}

void test_fail_ne(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  const char* file,
                  int line)
{{
    printf("FAIL at %s:%d: %s == %s (both %lld, expected different)\\n",
           file, line, expr_a, expr_b, got);

#ifdef TRACE
    if (g_current_tfp) {{
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }}

    if (g_current_test_name) {{
        printf("Trace saved to %s.vcd\\n", g_current_test_name);
    }}
#endif

    exit(1);
}}

void test_fail_u(const char* expr_a,
                 const char* expr_b,
                 unsigned long long got,
                 unsigned long long expected,
                 unsigned width,
                 const char* file,
                 int line)
{{
    printf("FAIL at %s:%d: %s != %s (got %llu expected %llu, width=%u)\\n",
           file, line, expr_a, expr_b, got, expected, width);

#ifdef TRACE
    if (g_current_tfp) {{
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }}

    if (g_current_test_name) {{
        printf("Trace saved to %s.vcd\\n", g_current_test_name);
    }}
#endif

    exit(1);
}}

void test_fail_s(const char* expr_a,
                 const char* expr_b,
                 long long got,
                 long long expected,
                 unsigned width,
                 const char* file,
                 int line)
{{
    printf("FAIL at %s:%d: %s != %s (got %lld expected %lld, width=%u)\\n",
           file, line, expr_a, expr_b, got, expected, width);

#ifdef TRACE
    if (g_current_tfp) {{
        g_current_tfp->flush();
        g_current_tfp->close();
        delete g_current_tfp;
        g_current_tfp = nullptr;
    }}

    if (g_current_test_name) {{
        printf("Trace saved to %s.vcd\\n", g_current_test_name);
    }}
#endif

    exit(1);
}}

int main(int argc, char** argv)
{{
    Verilated::commandArgs(argc, argv);

    V{module}* dut = new V{module};

    dut->clk = 0;
    dut->reset = 0;

    VerilatedVcdC* tfp = nullptr;

#ifdef TRACE
    Verilated::traceEverOn(true);
#endif

    auto& tests = get_tests();

    for (auto& t : tests) {{
        printf("=== %s ===\\n", t.name);
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
        if (tfp) {{
            tfp->flush();
            tfp->close();
            delete tfp;
            tfp = nullptr;
        }}
        g_current_tfp = nullptr;
#endif
        g_current_test_name = nullptr;
    }}

    printf("All tests passed.\\n");

    delete dut;
    return 0;
}}
""")


TEST_FRAMEWORK_TEMPLATE = textwrap.dedent("""\
#pragma once

#include <vector>
#include <functional>
#include <cstdio>
#include <cstdlib>
#include <cstdint>

#include "V{module}.h"
#include <verilated_vcd_c.h>

struct Test {{
    const char* name;
    std::function<void(V{module}*, VerilatedVcdC*)> fn;
}};

std::vector<Test>& get_tests();

static inline uint64_t mask_u(unsigned width)
{{
    return (width >= 64) ? ~0ULL : ((1ULL << width) - 1);
}}

static inline uint64_t bits_u(uint64_t x, unsigned width)
{{
    return x & mask_u(width);
}}

static inline int64_t bits_s(uint64_t x, unsigned width)
{{
    x &= mask_u(width);

    if (width == 0)
        return 0;

    uint64_t sign_bit = 1ULL << (width - 1);
    if (x & sign_bit)
        x |= ~mask_u(width);

    return (int64_t)x;
}}

#define TEST(name) \\
    void name(V{module}*, VerilatedVcdC*); \\
    struct name##_registrar {{ \\
        name##_registrar() {{ \\
            get_tests().push_back({{#name, name}}); \\
        }} \\
    }} name##_registrar_instance; \\
    void name(V{module}* dut, VerilatedVcdC* tfp)

void test_fail_eq(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  long long expected,
                  const char* file,
                  int line);

void test_fail_ne(const char* expr_a,
                  const char* expr_b,
                  long long got,
                  const char* file,
                  int line);

void test_fail_u(const char* expr_a,
                 const char* expr_b,
                 unsigned long long got,
                 unsigned long long expected,
                 unsigned width,
                 const char* file,
                 int line);

void test_fail_s(const char* expr_a,
                 const char* expr_b,
                 long long got,
                 long long expected,
                 unsigned width,
                 const char* file,
                 int line);

#define EXPECT_EQ(a,b) \\
    do {{ \\
        long long _a = (long long)(a); \\
        long long _b = (long long)(b); \\
        if (_a != _b) {{ \\
            test_fail_eq(#a, #b, _a, _b, __FILE__, __LINE__); \\
        }} \\
    }} while (0)

#define EXPECT_NE(a,b) \\
    do {{ \\
        long long _a = (long long)(a); \\
        long long _b = (long long)(b); \\
        if (_a == _b) {{ \\
            (void)_b; \\
            test_fail_ne(#a, #b, _a, __FILE__, __LINE__); \\
        }} \\
    }} while (0)

#define EXPECT_U(width, actual, expected) \\
    do {{ \\
        unsigned long long _a = (unsigned long long)bits_u((uint64_t)(actual), (width)); \\
        unsigned long long _e = (unsigned long long)bits_u((uint64_t)(expected), (width)); \\
        if (_a != _e) {{ \\
            test_fail_u(#actual, #expected, _a, _e, (unsigned)(width), __FILE__, __LINE__); \\
        }} \\
    }} while (0)

#define EXPECT_S(width, actual, expected) \\
    do {{ \\
        long long _a = (long long)bits_s((uint64_t)(actual), (width)); \\
        long long _e = (long long)(expected); \\
        if (_a != _e) {{ \\
            test_fail_s(#actual, #expected, _a, _e, (unsigned)(width), __FILE__, __LINE__); \\
        }} \\
    }} while (0)

extern void settle(V{module}* dut, VerilatedVcdC* tfp);
extern void tick(V{module}* dut, VerilatedVcdC* tfp);
""")


TESTS_TEMPLATE = textwrap.dedent("""\
#include "test_framework.h"

TEST(example)
{{
    // replace me
    dut->eval();
}}
""")


RUN_SH_TEMPLATE = textwrap.dedent("""\
#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \\
    --top-module {module} \\
    --cc ../../../src/*.v \\
    -I../../../src -I../../../include \\
    --exe sim_main.cpp tests.cpp \\
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \\
    -LDFLAGS "-lm"

make -C obj_dir -f V{module}.mk

./obj_dir/V{module}
""")


def write_file(path, content, executable=False):
    with open(path, "w") as f:
        f.write(content)

    if executable:
        os.chmod(path, 0o755)


def ensure_tests_include(path):
    if not os.path.exists(path):
        return

    with open(path) as f:
        text = f.read()

    include_line = '#include "test_framework.h"'

    if include_line in text:
        return

    stripped = text.lstrip()

    if stripped.startswith("#include"):
        lines = text.splitlines()
        insert_at = 0
        while insert_at < len(lines) and lines[insert_at].startswith("#include"):
            insert_at += 1
        lines.insert(insert_at, include_line)
        new_text = "\n".join(lines)
        if text.endswith("\n"):
            new_text += "\n"
    else:
        new_text = include_line + "\n\n" + text

    with open(path, "w") as f:
        f.write(new_text)

    print(f"[+] inserted test_framework.h include into {path}")


def main():
    os.makedirs(OUT_ROOT, exist_ok=True)

    modules = find_modules()

    if not modules:
        print("No modules found.")
        return

    for name in modules:
        out_dir = os.path.join(OUT_ROOT, name)
        os.makedirs(out_dir, exist_ok=True)

        sim_main = os.path.join(out_dir, "sim_main.cpp")
        framework = os.path.join(out_dir, "test_framework.h")
        tests = os.path.join(out_dir, "tests.cpp")
        run_sh = os.path.join(out_dir, "run.sh")

        write_file(sim_main, SIM_MAIN_TEMPLATE.format(module=name))
        print(f"[+] regenerated sim_main.cpp for {name}")

        write_file(framework, TEST_FRAMEWORK_TEMPLATE.format(module=name))
        print(f"[+] regenerated test_framework.h for {name}")

        if not os.path.exists(tests):
            write_file(tests, TESTS_TEMPLATE.format(module=name))
            print(f"[+] created tests.cpp for {name}")
        else:
            ensure_tests_include(tests)
            print(f"[=] preserved tests.cpp for {name}")

        write_file(run_sh, RUN_SH_TEMPLATE.format(module=name), executable=True)
        print(f"[+] regenerated run.sh for {name}")


if __name__ == "__main__":
    main()
