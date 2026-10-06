#include "Vcore_test.h"
#include "verilated.h"
#include <array>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>
#include <utility>

// Raw arithmetic programs exercise the actual decode/fetch/router/branches/commit.
// Arithmetic runs disable resource requests; compiled renders use filter_master, lut_master and delay_master.
// These tests do not simulate converters, SDRAM or SPI.
struct Instruction { uint32_t word; int reg0 = 1, reg1 = 1, dest = 1, expected = 0; bool depends_on_sample = false; };
static void require(bool ok, const std::string& message) {
    if (!ok) throw std::runtime_error(message);
}
static void tick(Vcore_test& d) {
    // Delayed transaction responder, not a model of the SDRAM controller/pins.
    // Nonzero initial words expose startup muting errors instead of hiding them.
    static std::vector<int16_t> memory(1 << 20, 0x5a5a);
    static int pending = 0, address = 0, value = 0, transactions = 0;
    static bool writing = false;
    static std::vector<std::pair<int,int>> buffers;
    d.clk = 0; d.eval();
    d.delay_mem_read_valid = d.delay_mem_write_ack = 0;
    if (d.reset || d.full_reset) { pending = 0; buffers.clear(); }
    else {
        if (d.command_alloc_delay) {
            const int start = buffers.empty() ? 0 : buffers.back().second;
            const int size = (d.ctrl_data_in >> 24) & 0xfffff;
            buffers.emplace_back(start, start + size);
        }
        if (pending && --pending == 0) {
            if (writing) { memory[address] = value; d.delay_mem_write_ack = 1; }
            else { d.delay_mem_data_in = uint16_t(memory[address]); d.delay_mem_read_valid = 1; }
        }
        if (d.delay_mem_req) {
            require(!pending, "overlapping delay memory transactions");
            address = d.delay_mem_addr; value = d.delay_mem_data_out;
            require(d.delay_mem_handle < buffers.size(), "unallocated delay memory handle");
            const auto bounds = buffers[d.delay_mem_handle];
            require(address >= bounds.first && address < bounds.second,
                    "delay access outside its buffer: " + std::to_string(address));
            writing = d.delay_mem_write;
            pending = 3 + (transactions++ % 9);
        }
    }
    d.eval(); d.clk = 1; d.eval(); d.clk = 0; d.eval();
}
static void wait(Vcore_test& d, int n) { while (n--) tick(d); }
static uint32_t encode(int op, int a, int b, int c, int dest, int shift = 15) {
    return uint32_t(op) | (a << 6) | (b << 11) | (c << 16) | (dest << 21) | (shift << 25);
}
static void program(Vcore_test& d, const std::vector<Instruction>& p) {
    d.reset = 1; wait(d, 4); d.reset = 0;
    for (int i = 0; i < int(p.size()); ++i) {
        d.ctrl_data_in = (uint64_t(i) << 16) | uint16_t(p[i].reg0);
        d.command_reg_0_write = 1; tick(d); d.command_reg_0_write = 0; wait(d, 8);
        d.ctrl_data_in = (uint64_t(i) << 16) | uint16_t(p[i].reg1);
        d.command_reg_1_write = 1; tick(d); d.command_reg_1_write = 0; wait(d, 8);
        d.ctrl_data_in = (uint64_t(i) << 32) | p[i].word;
        d.command_instr_write = 1; tick(d); d.command_instr_write = 0; wait(d, 8);
    }
    require(d.active_blocks == p.size(), "program block count");
    d.reg_writes_commit = 1; tick(d); d.reg_writes_commit = 0; wait(d, 10);
}
static void run(const std::string& name, const std::vector<Instruction>& p, std::ostream* trace) {
    Vcore_test d;
    program(d, p);
    d.enable = 1; wait(d, 4);
    // Multiple samples exercise pending channel-zero injection and ID wraparound.
    for (int sample = 0; sample < 3; ++sample) {
        d.sample_in = 37 + sample;
        d.tick = 1; tick(d); d.tick = 0;
        int received = 0, retired = 0, cycle = 0;
        std::array<int, 3> busy{}, occupied{};
        while (received < int(p.size())) {
            require(cycle < 5000, name + ": processing timeout");
            if (trace && d.debug_fetch) *trace << name << "," << sample << "," << cycle << ",fetch," << int(d.debug_block) << "," << d.debug_args << "\n";
            if (d.write_channel) {
                if (cycle == 0) {
                    require(d.write_dest == 0 && int16_t(d.write_value) == 37 + sample, name + ": input sample injection");
                } else {
                    const auto& ins = p[received];
                    require(d.write_dest == ins.dest, name + ": ordered destination at " + std::to_string(received));
                    require(int16_t(d.write_value) == ins.expected + (ins.depends_on_sample ? sample : 0),
                            name + " sample " + std::to_string(sample) + " instruction " + std::to_string(received) +
                            ": got " + std::to_string(int16_t(d.write_value)) + ", expected " + std::to_string(ins.expected + (ins.depends_on_sample ? sample : 0)));
                    if (trace) *trace << name << ',' << sample << ',' << cycle << ",write," << received << ',' << int16_t(d.write_value) << '\n';
                    ++received;
                }
            }
            if (d.retire) {
                require((d.retire & (d.retire - 1)) == 0, name + ": multiple retirements");
                require(d.next_commit == ((sample * int(p.size()) + retired) % 64), name + ": commit order/ID");
                ++retired;
            }
            for (int stage = 0; stage < 3; ++stage) {
                busy[stage] += bool(d.fetch_busy & (1 << stage));
                occupied[stage] += bool(d.fetch_occupied & (1 << stage));
            }
            if (trace) *trace << name << ',' << sample << ',' << cycle << ",state," << int(d.fetch_busy) << ',' << int(d.fetch_occupied) << '\n';
            tick(d); ++cycle;
        }
        require(retired == int(p.size()), name + ": retirement count");
        require(d.stuck_flags == 0, name + ": stuck flags");
        if (sample == 0) {
            std::cout << name << ',' << cycle << ',' << retired;
            for (auto n : busy) std::cout << ',' << n;
            for (auto n : occupied) std::cout << ',' << n;
            std::cout << '\n';
        }
        // Ignore post-drain watchdogs: the product supplies a periodic sample tick.
        wait(d, 4);
    }
}
static std::vector<Instruction> chain(int arg) {
    std::vector<Instruction> p(96);
    int result = 37;
    for (int i = 0; i < int(p.size()); ++i) {
        int a = 16, b = 17, c = 18;
        if (!i) {
            if (arg == 0) a = 0;
            if (arg == 1) b = 0;
            if (arg == 2) c = 0;
        } else {
            if (arg == 0) a = 1;
            if (arg == 1) b = 1;
            if (arg == 2) c = 1;
        }
        // Multiplication by 1 and addition by 0, except C chain (1*1+C).
        p[i].dest = i == int(p.size()) - 1 ? 0 : 1;
        p[i].word = encode(1, a, b, c, p[i].dest);
        p[i].reg0 = 1; p[i].reg1 = 1;
        result = arg == 2 ? result + 1 : 37;
        p[i].expected = result; p[i].depends_on_sample = true;
    }
    return p;
}
// Consume the production compiler's programming body at the core's control
// strobes. SPI framing and controller/mixer tail handling are outside this test.
static int load_compiled_program(Vcore_test& d, const std::string& path, int blocks = -1) {
    std::ifstream input(path, std::ios::binary);
    require(input.is_open(), "cannot open compiled program: " + path);
    const std::vector<unsigned char> bytes{std::istreambuf_iterator<char>(input), {}};
    size_t cursor = 0;
    auto take = [&](int n) {
        require(cursor + n <= bytes.size(), "truncated programming command");
        uint64_t value = 0;
        while (n--) value = (value << 8) | bytes[cursor++];
        return value;
    };
    d.reset = 1; wait(d, 4); d.reset = 0;
    int instructions = 0;
    std::vector<unsigned> polynomial_counts;
    unsigned polynomial_coefficients = 0;
    d.full_reset = 1; tick(d); d.full_reset = 0;
    int reset_cycles = 0;
    while (d.resetting && reset_cycles++ < 1024) tick(d);
    require(d.ready && !d.resetting, "full reset did not clear program/state");
    bool tail = false;
    while (cursor < bytes.size()) {
        const auto command = take(1);
        if (command == 39) {
            require(cursor == bytes.size(), "tail enable must end programming body");
            tail = true;
            break;
        }
        if (command == 5) {
            const auto size = take(3), delay = take(3);
            require(size > 0 && size < (1 << 20) && delay < size, "delay allocation outside test profile");
            d.ctrl_data_in = (size << 24) | delay;
            d.command_alloc_delay = 1; tick(d); d.command_alloc_delay = 0; wait(d, 10);
            require(!d.debug_delay_invalid, "delay allocation rejected");
            continue;
        }
        if (command == 16) {
            const auto format = take(1), count = take(1), feedback = take(1);
            require(format <= 17 && count > 0 && feedback == 0, "allocation outside polynomial test profile");
            require(polynomial_counts.size() < 16 && polynomial_coefficients + count < 128,
                    "polynomial allocation exceeds test capacity");
            polynomial_counts.push_back(count);
            polynomial_coefficients += count;
            d.ctrl_data_in = (format << 16) | (count << 8) | feedback;
            d.command_alloc_filter = 1; tick(d); d.command_alloc_filter = 0; wait(d, 12);
            continue;
        }
        if (command == 17) {
            const auto handle = take(1), target = take(2), value = take(3);
            require(handle < polynomial_counts.size() && target < polynomial_counts[handle],
                    "coefficient write outside allocated polynomial");
            d.ctrl_data_in = (handle << 40) | (target << 24) | value;
            d.command_filter_coef_write = 1; tick(d); d.command_filter_coef_write = 0; wait(d, 12);
            continue;
        }
        require(command >= 2 && command <= 4, "unsupported programming command");
        const auto block = take(2);
        require(block < 256, "block outside test core");
        if (command == 2) {
            require(block == unsigned(instructions++), "noncontiguous instruction blocks");
            d.ctrl_data_in = (block << 32) | take(4);
            d.command_instr_write = 1;
        } else {
            d.ctrl_data_in = (block << 16) | take(2);
            d.command_reg_0_write = command == 3;
            d.command_reg_1_write = command == 4;
        }
        tick(d);
        d.command_instr_write = d.command_reg_0_write = d.command_reg_1_write = 0;
        wait(d, 8);
    }
    require(tail && instructions > 0 && (blocks < 0 || instructions == blocks) && d.active_blocks == instructions, "compiled fixture program shape");
    d.reg_writes_commit = 1; tick(d); d.reg_writes_commit = 0; wait(d, 10);
    return instructions;
}
// A reusable one-core audio loop. Resource coverage is deliberately explicit:
// arithmetic, scratchpad and actual SVF/LUT/delay masters, without SPI, mixer or SDRAM hardware.
static void apply_polynomial_update(Vcore_test& d, const std::string& path) {
    std::ifstream input(path, std::ios::binary);
    require(input.is_open(), "cannot open coefficient update");
    auto take = [&](int count) {
        uint64_t value = 0;
        while (count--) {
            const int byte = input.get();
            require(byte != EOF, "truncated coefficient update");
            value = (value << 8) | byte;
        }
        return value;
    };
    int commands = 0;
    while (input.peek() != EOF) {
        const auto command = take(1), handle = take(1);
        require(handle < 16, "coefficient update handle outside profile");
        if (command == 18) {
            const auto target = take(2), value = take(3);
            require(target < 128, "coefficient update index outside profile");
            d.ctrl_data_in = (handle << 40) | (target << 24) | value;
            d.command_filter_coef_update = 1; tick(d); d.command_filter_coef_update = 0;
        } else {
            require(command == 19, "unsupported live update command");
            d.ctrl_data_in = handle;
            d.command_filter_coef_commit = 1; tick(d); d.command_filter_coef_commit = 0;
        }
        wait(d, 128); // Settle each bank operation; this harness does not model SPI cadence.
        ++commands;
    }
    require(commands > 0, "empty live update");
    wait(d, 128);
}
static void render_program(const std::string& path, const std::string& input_path,
                           const std::string& output_path,
                           const std::vector<std::pair<size_t, std::string>>& updates = {},
                           const std::string& trace_path = {}) {
    Vcore_test d;
    d.use_internal_resources = 1;
    load_compiled_program(d, path);
    d.enable = 1; wait(d, 4);
    std::ifstream input(input_path, std::ios::binary);
    std::ofstream output(output_path, std::ios::binary);
    require(input.is_open() && output.is_open(), "cannot open audio files");
    std::ofstream trace;
    if (!trace_path.empty()) {
        trace.open(trace_path);
        require(trace.is_open(), "cannot open render trace");
        trace << "frame,cycle,fetch,filter_request,poly_request,poly_ack,poly_state,poly_response,filter_response,write_channel,write_dest\n";
    }
    size_t frames = 0;
    size_t next_update = 0;
    int max_cycles = 0;
    while (true) {
        int lo = input.get(), hi;
        if (lo == EOF) break;
        hi = input.get();
        require(hi != EOF, "truncated PCM16 sample");
        if (next_update < updates.size() && frames == updates[next_update].first) {
            apply_polynomial_update(d, updates[next_update].second);
            ++next_update;
        }
        d.sample_in = uint16_t(lo | hi << 8);
        d.tick = 1; tick(d); d.tick = 0;
        bool written = false;
        int cycles = 0;
        while (!written && cycles < 2551) {
            if (trace.is_open())
                trace << frames << ',' << cycles << ',' << int(d.debug_fetch) << ','
                      << int(d.filter_req_valid) << ',' << int(d.debug_poly_request) << ','
                      << int(d.debug_poly_ack) << ',' << int(d.debug_poly_state) << ','
                      << int(d.debug_poly_response) << ',' << int(d.debug_filter_response) << ','
                      << int(d.write_channel) << ',' << int(d.write_dest) << '\n';
            require(!d.debug_filter_invalid && !d.debug_lut_invalid && !d.debug_delay_invalid && !d.stuck_flags, "audio invalid resource/stuck");
            // Cycle zero is the input injection. Programs must only write c0
            // at their final instruction; intermediate channels hold work.
            if (cycles && d.write_channel && d.write_dest == 0) {
                output.put(char(d.write_value & 255));
                output.put(char(d.write_value >> 8));
                written = true;
            }
            tick(d); ++cycles;
        }
        while (d.debug_delay_busy && cycles < 2551) { tick(d); ++cycles; }
        require(!d.debug_delay_busy, "delay did not drain before next sample");
        require(written, "audio sample budget exceeded at frame " + std::to_string(frames));
        max_cycles = std::max(max_cycles, cycles);
        ++frames;
    }
    require(frames && bool(output), "empty input or output write failure");
    require(!trace.is_open() || bool(trace), "render trace write failure");
    require(next_update == updates.size(), "update frame outside input");
    std::cout << "rendered," << frames << ",max_cycles," << max_cycles << '\n';
}
static void run_readback_program(const std::string& path) {
    Vcore_test d;
    load_compiled_program(d, path, 2);
    d.enable = 1; wait(d, 4);
    // The bare core traverses continuously; its enclosing pipeline supplies
    // sample cadence. Let bank copying and in-flight work finish before checking
    // a changed register value, then observe a bounded steady-state window.
    d.sample_in = 37;
    d.tick = 1; tick(d); d.tick = 0; wait(d, 128);
    const std::array<int, 3> values{8192, -8192, 0};
    for (int sample = 0; sample < int(values.size()); ++sample) {
        if (sample) {
            require(!d.regfile_syncing, "live update while register banks synchronize");
            d.ctrl_data_in = uint16_t(values[sample]); // block zero, register zero
            d.command_reg_0_write = 1; tick(d); d.command_reg_0_write = 0; wait(d, 8);
            d.reg_writes_commit = 1; tick(d); d.reg_writes_commit = 0; wait(d, 128);
        }
        require(!d.regfile_syncing, "register banks failed to synchronize");
        d.ctrl_data_in = 15; // DATA_REQ_MEM, scratchpad address zero
        d.data_req = 1; tick(d); d.data_req = 0;
        int retired = 0, writes = 0, replies = 0;
        int next_commit = d.next_commit;
        for (int cycle = 0; cycle < 128; ++cycle) {
            if (d.write_channel) {
                require(d.write_dest == 1 && int16_t(d.write_value) == values[sample], "compiled mov value");
                ++writes;
            }
            if (d.retire) {
                require((d.retire & (d.retire - 1)) == 0, "compiled multiple retirements");
                require(d.next_commit == next_commit, "compiled commit order");
                next_commit = (next_commit + 1) % 64;
                ++retired;
            }
            if (d.data_return_valid) {
                require(int32_t(d.data_return) == values[sample], "signed scratchpad readback value: " + std::to_string(d.data_return));
                ++replies;
            }
            tick(d);
        }
        require(writes > 0 && replies == 1 && retired > 0, "compiled write/read/retirement count");
        require(!d.stuck_flags, "compiled stuck flags");
        std::cout << "compiled_readback," << sample << ',' << values[sample] << ',' << writes << ',' << retired << '\n';
    }
}
static int32_t wrap18(int64_t value) {
    uint32_t bits = value & ((1u << 18) - 1);
    return bits & (1u << 17) ? int32_t(bits) - (1 << 18) : bits;
}
static int16_t saturate16(int32_t value) {
    return value > 32767 ? 32767 : (value < -32768 ? -32768 : value);
}
static void run_svf_program(const std::string& path) {
    Vcore_test d;
    load_compiled_program(d, path, 4);
    d.use_internal_resources = 1;
    d.enable = 1; wait(d, 4);
    d.sample_in = 16384;
    d.tick = 1; tick(d); d.tick = 0;
    struct State { int32_t low = 0, band = 0; };
    std::array<State, 2> states{};
    std::vector<std::pair<int, int>> expected;
    int reads = 0, updates = 0, frames = 1;
    for (int cycle = 0; reads < 256 && cycle < 100000; ++cycle) {
        require(!d.debug_filter_invalid && !d.stuck_flags, "compiled SVF invalid/stuck");
        if (d.debug_svf_accept) {
            int voice = d.debug_svf_block == 0 ? 0 : 1;
            require(d.debug_svf_block == 0 || d.debug_svf_block == 2, "compiled SVF block");
            require(int16_t(d.debug_svf_audio) == 16384, "compiled SVF audio fetch");
            require(int16_t(d.debug_svf_damping) == 10240 && d.debug_svf_shift == 2,
                    "compiled SVF damping encoding/field");
            require(voice || int16_t(d.debug_svf_cutoff) == 8192, "compiled Q15 cutoff expression");
            if (voice) require(int16_t(d.debug_svf_cutoff) == saturate16(states[0].low),
                               "compiled Q15 cutoff channel dependency");
            int f = std::max(0, int(int16_t(d.debug_svf_cutoff)));
            auto& state = states[voice];
            int32_t low = wrap18(state.low + ((int64_t(f) * state.band) >> 15));
            int32_t high = wrap18(16384 - low - ((int64_t(10240) * state.band) >> 13));
            int32_t band = wrap18(state.band + ((int64_t(f) * high) >> 15));
            state = {low, band};
            expected.emplace_back(voice + 1, saturate16(low));
            ++updates;
        }
        if (d.write_channel && d.write_dest != 0) {
            require(reads < int(expected.size()), "compiled SVF read before update");
            require(d.write_dest == expected[reads].first && int16_t(d.write_value) == expected[reads].second,
                    "compiled SVF low read mismatch at " + std::to_string(reads));
            ++reads;
        }
        d.tick = reads == frames * 2 && frames < 128;
        if (d.tick) ++frames;
        tick(d);
    }
    require(reads == 256 && updates == 256, "compiled SVF update/read timeout: " + std::to_string(updates) + " updates, " + std::to_string(reads) + " reads; request " + std::to_string(d.filter_req_valid));
    std::cout << "compiled_svf," << reads << " stateful updates/reads passed with expression and channel cutoff\n";
}
// Exercise the shipped two-instruction low-pass, including its c0 feedback.
// The WAV has dry audio on the left and RTL output on the right.
static void run_svf_audio_program(const std::string& path, const std::string& wav_path) {
    Vcore_test d;
    load_compiled_program(d, path, 2);
    d.use_internal_resources = 1;
    d.enable = 1; wait(d, 4);
    constexpr int rate = 44100, frames = rate;
    constexpr double pi = 3.14159265358979323846;
    std::ofstream wav(wav_path, std::ios::binary);
    require(wav.is_open(), "cannot open WAV output");
    auto word = [&](uint32_t value, int bytes) {
        while (bytes--) { wav.put(char(value & 255)); value >>= 8; }
    };
    wav.write("RIFF", 4); word(36 + frames * 4, 4); wav.write("WAVEfmt ", 8);
    word(16, 4); word(1, 2); word(2, 2); word(rate, 4); word(rate * 4, 4);
    word(4, 2); word(16, 2); wav.write("data", 4); word(frames * 4, 4);
    int32_t low = 0, band = 0;
    std::array<double, 2> real{}, imaginary{};
    int max_cycles = 0;
    for (int frame = 0; frame < frames; ++frame) {
        int16_t audio = std::lround(4096 * (std::sin(2 * pi * 100 * frame / rate) +
                                         std::sin(2 * pi * 8000 * frame / rate)));
        d.sample_in = uint16_t(audio);
        d.tick = 1; tick(d); d.tick = 0;
        bool updated = false, written = false;
        int cycles = 0;
        int16_t output = 0;
        while (!written && cycles < 5000) {
            require(!d.debug_filter_invalid && !d.stuck_flags, "SVF audio invalid/stuck");
            if (d.debug_svf_accept) {
                require(!updated && d.debug_svf_block == 0, "SVF audio update order");
                require(int16_t(d.debug_svf_audio) == audio, "SVF audio input fetch");
                int f = std::max(0, int(int16_t(d.debug_svf_cutoff)));
                int damping = int16_t(d.debug_svf_damping);
                require(f == std::lround(32768 * 2 * std::sin(pi * 1000 / rate)),
                        "SVF audio cutoff encoding");
                require(d.debug_svf_shift <= 15, "SVF audio damping field");
                low = wrap18(low + ((int64_t(f) * band) >> 15));
                int32_t high = wrap18(audio - low - ((int64_t(damping) * band) >> (15 - d.debug_svf_shift)));
                band = wrap18(band + ((int64_t(f) * high) >> 15));
                updated = true;
            }
            if (updated && d.write_channel) {
                require(d.write_dest == 0, "SVF audio output destination");
                output = int16_t(d.write_value);
                require(output == saturate16(low), "SVF audio reference mismatch at " + std::to_string(frame));
                written = true;
            }
            tick(d); ++cycles;
        }
        require(written, "SVF audio output timeout");
        max_cycles = std::max(max_cycles, cycles);
        word(uint16_t(audio), 2); word(uint16_t(output), 2);
        // Ignore initial settling in the two-tone amplitude measurement.
        if (frame >= rate / 10) {
            for (int tone = 0; tone < 2; ++tone) {
                double phase = 2 * pi * (tone ? 8000 : 100) * frame / rate;
                real[tone] += output * std::cos(phase);
                imaginary[tone] += output * std::sin(phase);
            }
        }
    }
    require(bool(wav), "WAV write failed");
    auto gain = [&](int tone) { return 2 * std::hypot(real[tone], imaginary[tone]) / (0.9 * rate * 4096); };
    require(gain(0) > 0.95 && gain(0) < 1.05 && gain(1) < 0.03, "SVF audio low-pass response");
    std::cout << "compiled_svf_audio," << frames << " exact samples; 100 Hz gain " << gain(0)
              << ", 8 kHz gain " << gain(1) << ", max " << max_cycles << " cycles/sample; " << wav_path << '\n';
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc > 1 && std::string(argv[1]) == "--render-polynomial-update") {
        try {
            require(argc >= 7 && argc % 2 == 1, "usage: --render-polynomial-update PROGRAM.bin INPUT.pcm OUTPUT.pcm UPDATE.bin FRAME [UPDATE.bin FRAME ...]");
            std::vector<std::pair<size_t, std::string>> updates;
            for (int i = 5; i < argc; i += 2) {
                size_t end = 0;
                const std::string frame(argv[i + 1]);
                const auto index = std::stoull(frame, &end);
                require(end == frame.size() && !frame.empty() && frame[0] != '-', "invalid update frame");
                require(updates.empty() || updates.back().first < index, "update frames must increase");
                updates.emplace_back(index, argv[i]);
            }
            render_program(argv[2], argv[3], argv[4], updates);
            return 0;
        } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    }
    if (argc > 1 && std::string(argv[1]) == "--render-program") {
        try {
            require(argc == 5 || argc == 6, "usage: --render-program PROGRAM.bin INPUT.pcm OUTPUT.pcm [TRACE.csv]");
            render_program(argv[2], argv[3], argv[4], {}, argc == 6 ? argv[5] : "");
            return 0;
        } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    }
    if (argc > 1 && std::string(argv[1]) == "--svf-audio-program") {
        try {
            require(argc == 4, "usage: --svf-audio-program FILE OUTPUT.wav");
            run_svf_audio_program(argv[2], argv[3]);
            return 0;
        } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    }
    if (argc > 1 && (std::string(argv[1]) == "--readback-program" || std::string(argv[1]) == "--svf-program")) {
        try {
            require(argc == 3, "usage: --readback-program FILE");
            if (std::string(argv[1]) == "--svf-program") run_svf_program(argv[2]);
            else run_readback_program(argv[2]);
            return 0;
        } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
    }
    std::ofstream trace;
    if (argc > 1) { trace.open(argv[1]); trace << "workload,sample,cycle,event,index,value\n"; }
    try {
        std::cout << "workload,cycles,retired,busy1,busy2,busy3,occupied1,occupied2,occupied3\n";
        run("MADD_A_chain", chain(0), trace.is_open() ? &trace : nullptr);
        run("MADD_B_chain", chain(1), trace.is_open() ? &trace : nullptr);
        run("MADD_C_chain", chain(2), trace.is_open() ? &trace : nullptr);
        auto independent = chain(0);
        for (auto& ins : independent) { ins.word = encode(1, 16, 17, 18, ins.dest); ins.expected = 1; ins.depends_on_sample = false; }
        independent.front().word = encode(1, 0, 17, 18, 1);
        independent.front().expected = 37; independent.front().depends_on_sample = true;
        run("MADD_independent", independent, nullptr);
        auto mixed = independent;
        for (int i = 0; i < int(mixed.size()); ++i) {
            mixed[i].dest = i == int(mixed.size()) - 1 ? 0 : i % 15 + 1;
            mixed[i].word = encode(i % 2 ? 5 : 1, 16, 17, 18, mixed[i].dest);
            mixed[i].reg0 = i % 2 ? -123 : 123;
            mixed[i].expected = 123; mixed[i].depends_on_sample = false;
        }
        mixed.front().word = encode(1, 0, 17, 18, 1); mixed.front().expected = 37; mixed.front().depends_on_sample = true;
        run("MADD_ABS_mixed", mixed, nullptr);
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
