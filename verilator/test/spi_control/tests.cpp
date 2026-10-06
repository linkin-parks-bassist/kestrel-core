#include "Vtest_spi_control.h"
#include "verilated.h"
#include <vector>
#include <iostream>
#include <stdexcept>
#include <fstream>
#include <iterator>
#include <string>

struct Event { int kind, pipeline; uint64_t payload; };
static std::vector<Event> events;
static std::vector<int> received;
static void check(bool ok) { if (!ok) throw std::runtime_error("SPI/controller mismatch"); }
static void tick(Vtest_spi_control& d) {
    d.clk=0; d.eval(); d.clk=1; d.eval();
    if (d.byte_valid) received.push_back(d.received);
    const int strobes[]{d.alloc,d.write_coef,d.update_coef,d.commit_coef};
    for (int k=0;k<4;++k) if (strobes[k]) events.push_back({k,strobes[k],d.control});
    d.clk=0; d.eval();
}
static void wait(Vtest_spi_control& d, int n) { while(n--) tick(d); }
// Mode zero at 10 MHz / 112.5 MHz: eight half periods occupy 45 system clocks.
static void send(Vtest_spi_control& d, const std::vector<int>& bytes, bool separate, int phase) {
    const int half_periods[]{5,6,6,5,6,6,5,6};
    int edge=phase;
    d.cs=0; wait(d,5);
    for (int b:bytes) {
        for (int bit=7;bit>=0;--bit) {
            d.mosi=(b>>bit)&1; d.sck=0; wait(d,half_periods[edge++%8]);
            d.sck=1; wait(d,half_periods[edge++%8]);
        }
        d.sck=0;
        if (separate) { d.cs=1; wait(d,5); d.cs=0; wait(d,5); }
    }
    d.cs=1; wait(d,12);
}
static std::vector<int> coef(int opcode,int handle,int index,int value) {
    return {opcode,handle,index>>8,index&255,(value>>16)&255,(value>>8)&255,value&255};
}
static int evaluate(Vtest_spi_control& d,int handle) {
    d.handle=handle; d.audio=16384; d.request_pipeline=d.current_pipeline;
    d.request=1; tick(d); d.request=0;
    int n=0;
    while (!d.result_valid && n++<256) { check(!d.result_invalid); tick(d); }
    check(d.result_valid && !d.result_invalid);
    int result=int16_t(d.result); wait(d,12); return result;
}
static void probe(Vtest_spi_control& d,int expected) {
    int curve=evaluate(d,0), constant=evaluate(d,1);
    check(constant==-8192);
    if (curve+constant!=expected) {
        std::cerr<<"curve="<<curve<<" constant="<<constant<<" expected sum="<<expected<<'\n';
        check(false);
    }
}
static std::vector<int> read_body(const char* path,bool update) {
    std::ifstream file(path,std::ios::binary);
    if (!file) throw std::runtime_error(std::string("cannot open ")+path);
    std::vector<int> bytes;
    for (unsigned char b:std::vector<char>(std::istreambuf_iterator<char>(file),{})) bytes.push_back(b);
    check(!bytes.empty());
    size_t offset=0;
    while(offset<bytes.size()) {
        int opcode=bytes[offset++],length=-1;
        if(update) {
            if(opcode==18) length=6;
            if(opcode==19) length=1;
        } else {
            if(opcode==2 || opcode==17) length=6;
            if(opcode==3 || opcode==4) length=4;
            if(opcode==16) length=3;
            if(opcode==39) length=0;
        }
        check(length>=0 && offset+length<=bytes.size()); offset+=length;
    }
    if(update) check(bytes.size()>=2 && bytes[bytes.size()-2]==19 && bytes.back()==0);
    else check(bytes.back()==39);
    return bytes;
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        // Optional fixture-specific replay: PROGRAM.bin [UPDATE.bin EXPECTED_SUM ...].
        check(argc==1 || (argc>=4 && argc%2==0));
        if(argc>1) {
            auto program=read_body(argv[1],false);
            std::vector<std::vector<int>> updates;
            std::vector<int> sums;
            for(int i=2;i<argc;i+=2) {
                updates.push_back(read_body(argv[i],true));
                size_t used=0; int sum=std::stoi(argv[i+1],&used);
                check(used==std::string(argv[i+1]).size()); sums.push_back(sum);
            }
            for(bool separate:{false,true}) for(int phase=0;phase<8;++phase) {
                Vtest_spi_control d; d.cs=1; d.sck=0; d.mosi=0; d.request=0;
                d.reset=1; wait(d,8); d.reset=0; wait(d,12);
                events.clear(); received.clear();
                std::vector<int> framed{1}; framed.insert(framed.end(),program.begin(),program.end());
                framed.push_back(10); send(d,framed,separate,phase); check(received==framed);
                wait(d,326560); check(d.current_pipeline==1); probe(d,-1024);
                int previous=-1024;
                for(size_t i=0;i<updates.size();++i) {
                    auto writes=updates[i]; writes.resize(writes.size()-2);
                    received.clear(); send(d,writes,separate,phase); check(received==writes);
                    probe(d,previous);
                    received.clear(); send(d,{19,0},separate,phase); check(received==std::vector<int>({19,0}));
                    probe(d,sums[i]); previous=sums[i];
                }
                check(!(d.status&0x54));
            }
            std::cout<<"Compiled polynomial SPI replay: all phases/CS patterns and repeated update bodies exact\n";
            return 0;
        }
        for (bool separate:{false,true}) for (int phase=0;phase<8;++phase) {
            Vtest_spi_control d; d.cs=1; d.sck=0; d.mosi=0; d.request=0;
            d.reset=1; wait(d,8); d.reset=0; wait(d,12);
            events.clear(); received.clear();
            const std::vector<int> bytes{
                1,16,0x7e,3,0,
                17,0x7e,0,2,3,0xc0,0,
                18,0x7e,0,2,0,0x40,0,
                19,0x7e,
                18,0x7e,0,1,3,0x80,0,
                19,0x7e};
            send(d,bytes,separate,phase);
            check(received==bytes); check(events.size()==6);
            const Event expected[]{
                {0,2,0x7e0300}, {1,2,0x7e000203c000ULL},
                {2,1,0x7e0002004000ULL}, {3,1,0x7e},
                {2,1,0x7e0001038000ULL}, {3,1,0x7e}};
            for (int i=0;i<6;++i) {
                check(events[i].kind==expected[i].kind);
                check(events[i].pipeline==expected[i].pipeline);
                check(events[i].payload==expected[i].payload);
            }
            check(!(d.status&0x54));
        }
        for (bool separate:{false,true}) for (int phase=0;phase<8;++phase) {
            Vtest_spi_control d; d.cs=1; d.sck=0; d.mosi=0; d.request=0;
            d.reset=1; wait(d,8); d.reset=0; wait(d,12);
            events.clear(); received.clear();
            send(d,{1,16,0,3,0,16,0,1,0},separate,phase);
            send(d,coef(17,0,0,16384),separate,phase);
            send(d,coef(17,0,1,32768),separate,phase);
            send(d,coef(17,0,2,-16384),separate,phase);
            send(d,coef(17,1,0,-32768),separate,phase);
            send(d,{10},separate,phase);
            // Keep the production warmup intact; this fixture acknowledges swap immediately.
            wait(d,326560); check(d.current_pipeline==1); probe(d,-1024);
            const int shapes[]{65536,-65536,0,65536};
            const int expected[]{8192,-16384,-4096,8192};
            int previous=-1024;
            for (int i=0;i<4;++i) {
                send(d,coef(18,0,0,shapes[i]),separate,phase);
                send(d,coef(18,0,1,32768),separate,phase);
                send(d,coef(18,0,2,-shapes[i]),separate,phase);
                probe(d,previous); // staged writes must not change the active bank
                send(d,{19,0},separate,phase);
                probe(d,expected[i]); previous=expected[i];
            }
            check(!(d.status&0x54));
        }
        std::cout<<"SPI/controller/filter: eight phases, two CS patterns, signed routing and repeated numerical bank commits passed\n";
    } catch (const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
