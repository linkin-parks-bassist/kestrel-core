#pragma once

#include <vector>
#include <functional>
#include <cstdio>
#include <cstdlib>
#include <cstdint>

#include "Vpostprocessing_stage.h"
#include <verilated_vcd_c.h>

struct Test {
    const char* name;
    std::function<void(Vpostprocessing_stage*, VerilatedVcdC*)> fn;
};

std::vector<Test>& get_tests();

static inline uint64_t mask_u(unsigned width)
{
    return (width >= 64) ? ~0ULL : ((1ULL << width) - 1);
}

static inline uint64_t bits_u(uint64_t x, unsigned width)
{
    return x & mask_u(width);
}

static inline int64_t bits_s(uint64_t x, unsigned width)
{
    x &= mask_u(width);

    if (width == 0)
        return 0;

    uint64_t sign_bit = 1ULL << (width - 1);
    if (x & sign_bit)
        x |= ~mask_u(width);

    return (int64_t)x;
}

#define TEST(name) \
    void name(Vpostprocessing_stage*, VerilatedVcdC*); \
    struct name##_registrar { \
        name##_registrar() { \
            get_tests().push_back({#name, name}); \
        } \
    } name##_registrar_instance; \
    void name(Vpostprocessing_stage* dut, VerilatedVcdC* tfp)

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

#define EXPECT_EQ(a,b) \
    do { \
        long long _a = (long long)(a); \
        long long _b = (long long)(b); \
        if (_a != _b) { \
            test_fail_eq(#a, #b, _a, _b, __FILE__, __LINE__); \
        } \
    } while (0)

#define EXPECT_NE(a,b) \
    do { \
        long long _a = (long long)(a); \
        long long _b = (long long)(b); \
        if (_a == _b) { \
            (void)_b; \
            test_fail_ne(#a, #b, _a, __FILE__, __LINE__); \
        } \
    } while (0)

#define EXPECT_U(width, actual, expected) \
    do { \
        unsigned long long _a = (unsigned long long)bits_u((uint64_t)(actual), (width)); \
        unsigned long long _e = (unsigned long long)bits_u((uint64_t)(expected), (width)); \
        if (_a != _e) { \
            test_fail_u(#actual, #expected, _a, _e, (unsigned)(width), __FILE__, __LINE__); \
        } \
    } while (0)

#define EXPECT_S(width, actual, expected) \
    do { \
        long long _a = (long long)bits_s((uint64_t)(actual), (width)); \
        long long _e = (long long)(expected); \
        if (_a != _e) { \
            test_fail_s(#actual, #expected, _a, _e, (unsigned)(width), __FILE__, __LINE__); \
        } \
    } while (0)

extern void settle(Vpostprocessing_stage* dut, VerilatedVcdC* tfp);
extern void tick(Vpostprocessing_stage* dut, VerilatedVcdC* tfp);
