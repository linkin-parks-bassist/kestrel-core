#include "Vtest_svf.h"
#include "verilated.h"
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <iostream>

static void tick(Vtest_svf &unit)
{
    unit.clk = 0; unit.eval();
    unit.clk = 1; unit.eval();
    unit.clk = 0; unit.eval();
}

static int32_t wrap18(int64_t value)
{
    uint32_t bits = value & ((1u << 18) - 1);
    return bits & (1u << 17) ? int32_t(bits) - (1 << 18) : bits;
}

static int16_t saturate(int32_t value)
{
    return std::clamp(value, -32768, 32767);
}

struct State { int32_t low = 0, band = 0; };

static void sample(Vtest_svf &unit, State &state, int block, int16_t audio,
                   int16_t cutoff, int16_t damping, int shift)
{
    int32_t f = std::max(0, int(cutoff));
    int32_t low = wrap18(state.low + ((int64_t(f) * state.band) >> 15));
    int32_t high = wrap18(audio - low - ((int64_t(damping) * state.band) >> (15 - shift)));
    int32_t band = wrap18(state.band + ((int64_t(f) * high) >> 15));
    unit.block = block; unit.audio = uint16_t(audio);
    unit.cutoff = uint16_t(cutoff); unit.damping = uint16_t(damping);
    unit.shift = shift; unit.valid = 1;
    tick(unit); unit.valid = 0;
    int cycles = 0;
    while (!unit.ack && ++cycles < 64) tick(unit);
    if (!unit.ack) { std::cerr << "No SVF acknowledgement\n"; std::exit(1); }
    while (!unit.band_valid && ++cycles < 64) tick(unit);
    if (!unit.band_valid || int16_t(unit.low) != saturate(low) ||
        int16_t(unit.high) != saturate(high) || int16_t(unit.band) != saturate(band)) {
        std::cerr << "SVF mismatch: block " << block << " cutoff " << cutoff
                  << " damping " << damping << " shift " << shift
                  << "; expected " << saturate(low) << ',' << saturate(high) << ',' << saturate(band)
                  << "; got " << int16_t(unit.low) << ',' << int16_t(unit.high) << ',' << int16_t(unit.band) << '\n';
        std::exit(1);
    }
    state = {low, band};
    tick(unit);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    const int16_t cutoffs[] = {0, -8192, 8192, 16384, 32767};
    const int16_t damping_words[] = {4096, 24576, -4096};
    const int shifts[] = {0, 1, 0};
    int samples = 0;
    for (int16_t cutoff : cutoffs) {
        for (int mode = 0; mode < 3; mode++) {
            Vtest_svf unit;
            unit.reset = 1; for (int i = 0; i < 4; i++) tick(unit);
            unit.reset = 0;
            State states[2];
            for (int n = 0; n < 128; n++) {
                for (int voice = 0; voice < 2; voice++) {
                    int16_t input = n == 0 ? (voice ? -16384 : 16384) :
                        (n % 3 == 0 ? (voice ? -997 : 997) : 0);
                    sample(unit, states[voice], voice ? 4 : 1, input,
                           cutoff, damping_words[mode], shifts[mode]);
                    samples++;
                }
            }
        }
    }
    std::cout << "SVF signed-Q15 recurrence: " << samples
              << " samples passed, including private state slots and cutoff endpoints\n";
}
