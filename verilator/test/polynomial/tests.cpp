#include "Vtest_polynomial.h"
#include "verilated.h"
#include <array>
#include <iostream>
#include <stdexcept>
static void tick(Vtest_polynomial& d) { d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); }
static void wait(Vtest_polynomial& d, int n=12) { while(n--) tick(d); }
static void check(bool ok) { if(!ok) throw std::runtime_error("polynomial mismatch/timeout"); }
static void coefficient(Vtest_polynomial& d, int handle, int index, int value, bool update=false) {
    d.control=(uint64_t(handle)<<40)|(uint64_t(index)<<24)|(value&0x3ffff);
    d.coef_write=!update; d.coef_update=update; tick(d);
    d.coef_write=d.coef_update=0; wait(d);
}
static int reference(int input, const std::array<int,3>& coefficients, int count) {
    int power=32768;
    int64_t sum=0;
    for(int i=0;i<count;++i) {
        sum+=int64_t(coefficients[i])*power;
        power=int16_t((int64_t(input)*power)>>15);
    }
    sum>>=17;
    return sum>32767 ? 32767 : sum< -32768 ? -32768 : sum;
}
static void evaluate(Vtest_polynomial& d, int handle, int input, int expected) {
    d.handle=handle; d.audio=uint16_t(input); d.request=1; tick(d); d.request=0;
    int cycles=0;
    while(!d.valid && cycles++<256) { check(!d.invalid); tick(d); }
    if (!d.valid || int16_t(d.result)!=expected) {
        std::cerr<<"handle="<<handle<<" input="<<input<<" result="<<int16_t(d.result)
                 <<" expected="<<expected<<" cycles="<<cycles<<" valid="<<int(d.valid)<<'\n';
        check(false);
    }
    wait(d);
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Vtest_polynomial d; d.reset=1; wait(d,4); d.reset=0; wait(d);
        const std::array<int,3> quadratic{16384,32768,-16384}, constant{-32768,0,0};
        for(int h=0;h<2;++h) {
            d.control=uint64_t(h ? 1:3)<<8; d.alloc=1; tick(d); d.alloc=0; wait(d);
            const auto& coeff=h ? constant:quadratic;
            for(int i=0;i<(h ? 1:3);++i) coefficient(d,h,i,coeff[i]);
        }
        for(int repeat=0;repeat<4;++repeat)
            for(int x: {-32768,-16384,0,16384,32767}) {
                evaluate(d,0,x,reference(x,quadratic,3));
                evaluate(d,1,x,-8192);
            }
        std::array<int,3> replacement{32768,16384,0};
        for(int i=0;i<3;++i) coefficient(d,0,i,replacement[i],true);
        evaluate(d,0,16384,reference(16384,quadratic,3));
        d.control=0; d.coef_commit=1; tick(d); d.coef_commit=0; wait(d);
        evaluate(d,0,16384,reference(16384,replacement,3));
        evaluate(d,1,16384,-8192);
        std::cout<<"Polynomial: signed quadratic, constant, private handles and bank updates passed\n";
    } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
