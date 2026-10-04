#include "Voperand_fetch_test.h"
#include "verilated.h"
#include <array>
#include <deque>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

// An ordered, fixed-latency execution/writeback sink isolates fetch costs.
// This is not a model of the complete execution pipeline.
struct Instruction {
    std::array<int, 3> src{0, 0, 0};
    std::array<bool, 3> reg{true, true, true};
    std::array<bool, 3> needed{true, false, false};
    int dest = 1;
    bool writes_channel = true, writes_accumulator = false, accumulator_needed = false;
    int reg0 = 0, reg1 = 0;
};
struct Writeback { int due, dest, value; bool accumulator; };
struct Metrics {
    int cycles = 0, retired = 0;
    std::array<int, 3> busy{}, occupied{};
};
static void require(bool ok, const std::string& message) {
    if (!ok) throw std::runtime_error(message);
}
static void tick(Voperand_fetch_test& dut) {
    dut.clk = 0; dut.eval();
    dut.clk = 1; dut.eval();
    dut.clk = 0; dut.eval();
}
static int register_value(const Instruction& ins, int src) {
    switch (src) {
        case 0: return ins.reg0;
        case 1: return ins.reg1;
        case 3: return 16384;
        case 4: return -32768;
        case 5: return 23170;
        default: return 0;
    }
}
static void drive(Voperand_fetch_test& d, const Instruction& ins, int index) {
    d.block_in = index % 256;
    d.register_0_in = ins.reg0; d.register_1_in = ins.reg1;
    d.src_a_in = ins.src[0]; d.src_b_in = ins.src[1]; d.src_c_in = ins.src[2];
    d.src_a_reg_in = ins.reg[0]; d.src_b_reg_in = ins.reg[1]; d.src_c_reg_in = ins.reg[2];
    d.arg_a_needed_in = ins.needed[0]; d.arg_b_needed_in = ins.needed[1]; d.arg_c_needed_in = ins.needed[2];
    d.dest_in = ins.dest;
    d.writes_channel_in = ins.writes_channel;
    d.writes_accumulator_in = ins.writes_accumulator;
    d.accumulator_needed_in = ins.accumulator_needed;
    d.operation_in = index % 32; d.misc_op_in = index % 8;
    d.shift_in = index % 32; d.shift_disable_in = index % 2;
    d.saturate_disable_in = (index / 2) % 2; d.signedness_in = (index / 4) % 2;
    d.res_addr_in = index % 256; d.writes_external_in = (index / 8) % 2;
    d.commit_flag_in = 1; d.branch_in = index % 4; d.flags_in = index % 16;
}
static Metrics run(const std::string& name, const std::vector<Instruction>& program,
                   int latency, bool backpressure = false, bool pause = false,
                   std::ostream* trace = nullptr) {
    Voperand_fetch_test d;
    d.enable = 1; d.reset = 1; d.in_valid = 0; d.out_ready = 1;
    // Keep last-block injection out of ordinary workloads; tested separately below.
    d.n_blocks_running = 256;
    d.channel_write_enable = 0; d.accumulator_write_enable = 0; d.sample_tick = 0;
    tick(d); tick(d); d.reset = 0;
    std::array<int, 16> channels{};
    std::deque<Writeback> writes;
    Metrics m;
    int sent = 0, received = 0, next_id = 0;
    int pending_accumulator = 0;
    while (received < int(program.size()) || !writes.empty()) {
        require(m.cycles < 20000, name + ": timeout");
        int cycle = m.cycles++;
        d.enable = !pause || cycle % 13 < 9;
        d.out_ready = !backpressure || cycle % 19 < 7;
        d.channel_write_enable = 0; d.accumulator_write_enable = 0;
        if (d.enable && !writes.empty() && writes.front().due <= cycle) {
            const auto w = writes.front(); writes.pop_front();
            if (w.accumulator) { d.accumulator_write_enable = 1; --pending_accumulator; }
            else { d.channel_write_enable = 1; d.channel_write_addr = w.dest; d.channel_write_val = w.value; }
            if (trace) *trace << name << ',' << cycle << ",commit," << w.dest << ',' << w.value << '\n';
            ++m.retired;
        }
        d.in_valid = sent < int(program.size());
        if (d.in_valid) drive(d, program[sent], sent);
        d.eval();
        for (int stage = 0; stage < 3; ++stage) {
            m.busy[stage] += bool(d.stage_busy & (1 << stage)) && d.enable;
            m.occupied[stage] += bool((d.stage_busy | d.stage_valid) & (1 << stage)) && d.enable;
        }
        bool take_in = d.enable && d.in_valid && d.in_ready;
        if (trace && take_in) *trace << name << ',' << cycle << ",accept," << sent << ",0\n";
        if (d.enable && d.out_valid && d.out_ready) {
            require(received < int(program.size()), name + ": duplicate output");
            const auto& ins = program[received];
            auto eq = [&](int actual, int expected, const char* field) {
                require(actual == expected, name + " instruction " + std::to_string(received) +
                        " " + field + ": got " + std::to_string(actual) +
                        ", expected " + std::to_string(expected));
            };
            eq(d.block_out, received % 256, "block/order");
            eq(int16_t(d.register_0_out), ins.reg0, "register0");
            eq(int16_t(d.register_1_out), ins.reg1, "register1");
            eq(d.dest_out, ins.dest, "dest");
            eq(d.operation_out, received % 32, "operation");
            eq(d.misc_op_out, received % 8, "misc_op");
            eq(d.shift_out, received % 32, "shift");
            eq(d.shift_disable_out, received % 2, "shift_disable");
            eq(d.saturate_disable_out, (received / 2) % 2, "saturate_disable");
            eq(d.signedness_out, (received / 4) % 2, "signedness");
            eq(d.res_addr_out, received % 256, "res_addr");
            eq(d.writes_external_out, (received / 8) % 2, "writes_external");
            eq(d.commit_flag_out, 1, "commit_flag");
            eq(d.branch_out, received % 4, "branch");
            eq(d.flags_out, received % 16, "flags");
            if (ins.accumulator_needed)
                require(pending_accumulator == 0, name + ": accumulator read before prior writeback");
            std::array<int, 3> actual{int16_t(d.arg_a_out), int16_t(d.arg_b_out), int16_t(d.arg_c_out)};
            int result = 0;
            for (int arg = 0; arg < 3; ++arg) if (ins.needed[arg]) {
                int expected = ins.reg[arg] ? register_value(ins, ins.src[arg]) : channels[ins.src[arg]];
                eq(actual[arg], expected, arg == 0 ? "arg A" : arg == 1 ? "arg B" : "arg C");
                result += expected;
            }
            result = int16_t(result);
            if (ins.writes_channel || ins.writes_accumulator) {
                eq(d.commit_id_out, next_id++ % 64, "commit ID");
                if (ins.writes_accumulator) { ++pending_accumulator; }
                else channels[ins.dest] = result;
                writes.push_back({cycle + latency, ins.dest, result, ins.writes_accumulator});
            }
            if (trace) *trace << name << ',' << cycle << ",fetch," << received << ',' << result << '\n';
            ++received;
        }
        tick(d);
        if (take_in) ++sent;
    }
    require(sent == int(program.size()), name + ": input loss");
    return m;
}
static std::vector<Instruction> chain(int arg, int count = 96) {
    std::vector<Instruction> p(count);
    for (int i = 0; i < count; ++i) {
        p[i].reg0 = i + 1; p[i].reg1 = -i - 1;
        p[i].needed = {false, false, false}; p[i].needed[arg] = true;
        if (i) { p[i].reg[arg] = false; p[i].src[arg] = 1; }
    }
    return p;
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    std::ofstream trace_file;
    if (argc > 1) { trace_file.open(argv[1]); trace_file << "workload,cycle,event,index,value\n"; }
    auto report = [&](const std::string& name, const std::vector<Instruction>& p,
                      bool bp = false, bool pause = false) {
        auto m = run(name, p, 8, bp, pause, trace_file.is_open() ? &trace_file : nullptr);
        std::cout << name << "," << m.cycles << "," << m.retired;
        for (int n : m.busy) std::cout << ',' << n;
        for (int n : m.occupied) std::cout << ',' << n;
        std::cout << '\n';
    };
    try {
        std::cout << "workload,cycles,retired,busy1,busy2,busy3,occupied1,occupied2,occupied3\n";
        report("A_chain", chain(0)); report("B_chain", chain(1)); report("C_chain", chain(2));
        auto independent = chain(0);
        for (auto& ins : independent) { ins.reg[0] = true; ins.src[0] = 0; }
        report("independent", independent);
        auto all = independent;
        for (int i = 0; i < int(all.size()); ++i) {
            all[i].needed = {true, true, true}; all[i].src = {0, 1, 3};
            all[i].dest = i % 15 + 1;
        }
        report("registers_and_constants", all);
        auto unused = chain(0);
        for (auto& ins : unused) { ins.reg[1] = ins.reg[2] = false; ins.src[1] = ins.src[2] = 1; }
        report("unused_busy_B_C", unused);
        auto acc = independent;
        for (auto& ins : acc) { ins.writes_channel = false; ins.writes_accumulator = true; ins.accumulator_needed = true; }
        report("accumulator_chain", acc);
        report("A_chain_backpressure", chain(0), true);
        report("registers_backpressure", all, true);
        report("A_chain_paused", chain(0), true, true);
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    return 0;
}
