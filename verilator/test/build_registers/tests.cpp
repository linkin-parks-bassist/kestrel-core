#include "Vbuild_registers.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
#ifndef EXPECT_FLAGS
#define EXPECT_FLAGS 6
#endif
static void tick(Vbuild_registers& d) { d.clk=0; d.eval(); d.clk=1; d.eval(); }
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    Vbuild_registers d;
    d.reset=1; tick(d); d.reset=0;
    for(auto address: {0,4,8,1}) {
        d.read_addr=address; d.read_req=1; tick(d);
        if(d.read_valid != (address==0 || address==4)) return 1;
        if(address==0 && d.read_data!=0x4b455354) return 1;
        if(address==4 && d.read_data!=EXPECT_FLAGS) return 1;
        d.read_req=0; tick(d); if(d.read_valid) return 1;
    }
    std::cout<<"Build registers: magic, flags="<<EXPECT_FLAGS<<", pulse and unmapped reads passed\n";
}
