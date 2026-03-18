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

#include <vector>
#include <functional>
#include <cstdio>

struct Test {{
    const char* name;
    std::function<void(V{module}*, VerilatedVcdC*)> fn;
}};

extern std::vector<Test>& get_tests();

static vluint64_t sim_time = 0;
double sc_time_stamp() {{ return sim_time; }}

void tick(V{module}* dut, VerilatedVcdC* tfp)
{{
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);

    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);
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

#ifdef TRACE
        tfp = new VerilatedVcdC;

        char fname[256];
        snprintf(fname, sizeof(fname), "%s.vcd", t.name);

        dut->trace(tfp, 99);
        tfp->open(fname);
#endif

        sim_time = 0;

        dut->reset = 1;
        for (int i = 0; i < 5; i++) tick(dut, tfp);
        dut->reset = 0;

        t.fn(dut, tfp);

#ifdef TRACE
        tfp->close();
        delete tfp;
        tfp = nullptr;
#endif
    }}

    printf("All tests passed.\\n");

    delete dut;
    return 0;
}}
""")

TESTS_TEMPLATE = textwrap.dedent("""\
#include <vector>
#include <functional>
#include <cstdio>
#include <cstdlib>

#include "V{module}.h"
#include <verilated_vcd_c.h>

struct Test {{
    const char* name;
    std::function<void(V{module}*, VerilatedVcdC*)> fn;
}};

std::vector<Test>& get_tests()
{{
    static std::vector<Test> tests;
    return tests;
}}

#define TEST(name) \\
    void name(V{module}*, VerilatedVcdC*); \\
    struct name##_registrar {{ \\
        name##_registrar() {{ \\
            get_tests().push_back({{#name, name}}); \\
        }} \\
    }} name##_registrar_instance; \\
    void name(V{module}* dut, VerilatedVcdC* tfp)

#define EXPECT_EQ(a,b) \\
    if ((a)!=(b)) {{ \\
        printf("FAIL: %s != %s (got %d expected %d)\\n", #a, #b, (int)(a), (int)(b)); \\
        exit(1); \\
    }}

extern void tick(V{module}* dut, VerilatedVcdC* tfp);

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
        tests = os.path.join(out_dir, "tests.cpp")
        run_sh = os.path.join(out_dir, "run.sh")

        write_file(sim_main, SIM_MAIN_TEMPLATE.format(module=name))
        print(f"[+] regenerated sim_main.cpp for {name}")

        if not os.path.exists(tests):
            write_file(tests, TESTS_TEMPLATE.format(module=name))
            print(f"[+] created tests.cpp for {name}")
        else:
            print(f"[=] preserved tests.cpp for {name}")

        write_file(run_sh, RUN_SH_TEMPLATE.format(module=name), executable=True)
        print(f"[+] regenerated run.sh for {name}")


if __name__ == "__main__":
    main()
