#include "Vtest_spi_engine.h"
#include "verilated.h"
#include <vector>
#include <fstream>
#include <iterator>
#include <iostream>
#include <stdexcept>
#include <string>
#include <algorithm>

static uint64_t cycles;
static int phase;
static bool separate;
static bool readback;
static bool monitor_audio;
static int expected_audio;
static std::ofstream* register_trace;
static uint64_t stream_start;
static std::vector<uint16_t> ram(1<<20);
static int ram_wait;
static bool ram_pending_read;
static uint16_t ram_pending_data;
static uint64_t b_executions;
static void check(bool ok) { if(!ok) throw std::runtime_error("SPI engine mismatch/timeout"); }
static void tick(Vtest_spi_engine& d) {
    if(d.reset) {
        ram_wait=0; ram_pending_read=false;
        b_executions=0;
        std::fill(ram.begin(),ram.end(),0);
    }
    d.ram_valid=ram_wait==1 && ram_pending_read;
    d.ram_read_data=ram_pending_data;
    d.ram_busy=ram_wait!=0;
    d.sample_valid=!d.reset && cycles%2551==0;
    d.clk=0; d.eval();
    if(!d.reset && d.b_issued && d.b_issued_block==0) ++b_executions;
    if(!d.reset && (d.ram_read || d.ram_write || d.ram_refresh)) {
        check(ram_wait==0 && int(d.ram_read)+int(d.ram_write)+int(d.ram_refresh)==1);
        check(d.ram_addr<ram.size());
        ram_pending_read=d.ram_read;
        ram_pending_data=ram[d.ram_addr];
        if(d.ram_write) ram[d.ram_addr]=d.ram_write_data;
        ram_wait=d.ram_refresh?11:7;
    } else if(ram_wait) --ram_wait;
    if(register_trace && d.issued)
        *register_trace<<(cycles-stream_start)/2551<<','<<int(d.issued_block)<<','
                       <<int16_t(d.issued_reg0)<<','<<int16_t(d.issued_reg1)<<'\n';
    d.clk=1; d.eval(); d.clk=0; d.eval(); ++cycles;
    check(!d.error && d.fifo_count<32 && (readback || !(d.status&0x54)));
    if(monitor_audio) check(int16_t(d.sample_out)==expected_audio);
}
static void wait(Vtest_spi_engine& d,int n) { while(n--) tick(d); }
static std::vector<unsigned char> send(Vtest_spi_engine& d,const std::vector<unsigned char>& bytes) {
    const int half[]{5,6,6,5,6,6,5,6}; int edge=phase;
    std::vector<unsigned char> received;
    d.cs=0; wait(d,5);
    for(int b:bytes) {
        unsigned char reply=0;
        for(int bit=7;bit>=0;--bit) {
            d.mosi=(b>>bit)&1; d.sck=0; wait(d,half[edge++%8]);
            d.sck=1; wait(d,half[edge++%8]);
            reply=(reply<<1)|d.miso;
        }
        received.push_back(reply);
        d.sck=0;
        if(separate) { d.cs=1; wait(d,5); d.cs=0; wait(d,5); }
    }
    d.sck=0; d.cs=1; wait(d,12);
    return received;
}
static std::vector<unsigned char> read(const char* path) {
    std::ifstream f(path,std::ios::binary); check(bool(f));
    std::vector<unsigned char> bytes(std::istreambuf_iterator<char>(f),{});
    check(!bytes.empty()); return bytes;
}
static void read32_word(Vtest_spi_engine& d,int address) {
    bool previous=readback; readback=true;
    send(d,{40,0,0,static_cast<unsigned char>(address)});
    unsigned char flags=0;
    for(int poll=0;poll<16 && !(flags&0x20);++poll)
        flags=send(d,{37})[0];
    check((flags&0x75)==0x21);
    check(send(d,{20})[0]&0x20);
    uint32_t value=0;
    for(int byte=0;byte<4;++byte) value=(value<<8)|send(d,{20})[0];
    uint32_t expected=address==0?0x4b455354u:6u;
    if(value!=expected) {
        std::cerr<<"read32 address="<<address<<" value="<<std::hex<<value
                 <<" expected="<<expected<<std::dec<<'\n'; check(false);
    }
    // Match the Interface's per-byte READOUT and final error-clear sequence.
    send(d,{37});
    check((send(d,{37})[0]&0x75)==1);
    readback=previous;
}
static void read32_cases(const std::vector<unsigned char>& program) {
    readback=true;
    int words=0;
    for(bool pattern:{false,true}) for(phase=0;phase<8;++phase) {
        separate=pattern; cycles=phase*127;
        monitor_audio=false;
        Vtest_spi_engine d; d.cs=1; d.sck=0; d.mosi=0; d.sample_in=program.empty()?0:16384;
        d.reset=1; wait(d,8); d.reset=0; wait(d,2048);
        if(!program.empty()) {
            send(d,{11,4,0,12,4,0});
            auto framed=program; framed.insert(framed.begin(),1); framed.push_back(10);
            send(d,framed);
            int n=0; while(!d.current_pipeline && n++<4096*2551) tick(d);
            check(d.current_pipeline==1);
            wait(d,2551*16);
            check(int16_t(d.sample_out)==expected_audio);
            monitor_audio=true;
        }
        for(int repeat=0;repeat<3;++repeat) for(int address:{0,4}) {
            read32_word(d,address);
            ++words;
        }
    }
    std::cout<<"SPI/full engine read32: "<<words
             <<" exact magic/capability words, eight phases/two request CS patterns"
             <<(program.empty()?"":"; constant audio preserved every cycle")<<'\n';
}
static void settled(Vtest_spi_engine& d,int expected) {
    wait(d,2551*8);
    for(int i=0;i<8;++i) {
        wait(d,2551);
        if(int16_t(d.sample_out)!=expected) {
            std::cerr<<"sample="<<int16_t(d.sample_out)<<" expected="<<expected
                     <<" pipeline="<<int(d.current_pipeline)<<" status="<<int(d.status)<<'\n';
            check(false);
        }
    }
}
static int reference(int input,int coefficient) {
    int squared=int16_t((int64_t(input)*input)>>15);
    int64_t curve=(int64_t(coefficient)*32768+int64_t(32768)*input-
                   int64_t(coefficient)*squared)>>17;
    curve=curve>32767?32767:curve< -32768?-32768:curve;
    int sum=int(curve)-8192; return sum>32767?32767:sum< -32768?-32768:sum;
}
static void endpoints(Vtest_spi_engine& d,int coefficient) {
    for(int input:{-32768,-16384,-1,0,1,8192,16384,32767}) {
        d.sample_in=uint16_t(input); settled(d,reference(input,coefficient));
    }
    d.sample_in=16384;
}
static void stream(Vtest_spi_engine& d,int coefficient) {
    // Sampled preprocessing, core output, postprocessing and engine output.
    constexpr int latency=4;
    std::vector<int> expected;
    uint32_t noise=0x12345678;
    d.sample_in=16384; wait(d,2551*8);
    for(int frame=0;frame<64+latency;++frame) {
        noise=noise*1664525+1013904223;
        int input=frame<64?int16_t(noise>>16):0;
        expected.push_back(reference(input,coefficient));
        while(cycles%2551) tick(d);
        d.sample_in=uint16_t(input); wait(d,2551);
        if(frame>=latency && int16_t(d.sample_out)!=expected[frame-latency]) {
            std::cerr<<"stream frame="<<frame<<" sample="<<int16_t(d.sample_out)
                     <<" expected="<<expected[frame-latency]<<'\n'; check(false);
        }
    }
    d.sample_in=16384;
}
static void render(const char* program_path,const char* input_path,const char* output_path,
                   const std::vector<std::vector<unsigned char>>& updates,
                   const std::vector<size_t>& update_frames, bool read_during_audio) {
    auto program=read(program_path), input=read(input_path);
    check(input.size()%2==0);
    // Validate supported programming bodies before driving the engine.
    size_t offset=0; int last_opcode=0; bool has_delay=false;
    while(offset<program.size()) {
        int opcode=program[offset++], length=-1;
        if(opcode==2 || opcode==17) length=6;
        if(opcode==5) { length=6; has_delay=true; }
        if(opcode==3 || opcode==4) length=4;
        if(opcode==16) length=3;
        if(opcode==39) length=0;
        check(length>=0 && offset+length<=program.size()); offset+=length;
        if(opcode==39) check(offset==program.size());
        last_opcode=opcode;
    }
    check(last_opcode==39);
    check(update_frames.empty() || update_frames.size()==updates.size());
    for(size_t i=0;i<update_frames.size();++i) {
        check(update_frames[i]<input.size()/2 && (i==0 || update_frames[i]>update_frames[i-1]));
        check(updates[i].size()<=24);
    }
    for(const auto& update:updates) {
        offset=0; last_opcode=0;
        while(offset<update.size()) {
            int opcode=update[offset++];
            int length=(opcode==13 || opcode==14)?4:opcode==15?0:-1;
            check(length>=0 && offset+length<=update.size()); offset+=length;
            if(opcode==15) check(offset==update.size());
            last_opcode=opcode;
        }
        check(last_opcode==15);
    }
    Vtest_spi_engine d; d.cs=1; d.sck=0; d.mosi=0; d.sample_in=0;
    cycles=0; phase=0; separate=false;
    d.reset=1; wait(d,8); d.reset=0; wait(d,2048);
    send(d,{11,4,0,12,4,0});
    program.insert(program.begin(),1); program.push_back(10); send(d,program);
    int n=0; while(!d.current_pipeline && n++<4096*2551) tick(d);
    check(d.current_pipeline==1); wait(d,2551*(has_delay?512:16));
    if(update_frames.empty())
        for(const auto& update:updates) { send(d,update); wait(d,2551*16); }
    std::vector<unsigned char> output; const size_t frames=input.size()/2;
    uint64_t warmup_executions=0;
    size_t update_index=0;
    std::ofstream trace;
    if(!update_frames.empty()) {
        trace.open(std::string(output_path)+".registers.csv"); check(bool(trace));
        stream_start=((cycles+2550)/2551)*2551;
        while(cycles<stream_start) tick(d);
        register_trace=&trace;
    }
    for(size_t frame=0;frame<frames+4;++frame) {
        while(cycles%2551) tick(d);
        if(frame==0) warmup_executions=b_executions;
        const uint64_t next_frame=cycles+2551;
        d.sample_in=frame<frames?input[2*frame]|(input[2*frame+1]<<8):0;
        if(update_index<update_frames.size() && frame==update_frames[update_index]) {
            // Inject during execution too; the register trace determines which
            // committed values each instruction actually consumes.
            wait(d,128); send(d,updates[update_index++]);
        }
        if(read_during_audio && frame<frames) {
            wait(d,128); read32_word(d,frame%2?4:0);
        }
        check(cycles<=next_frame);
        while(cycles<next_frame) tick(d);
        if(frame>=4) { output.push_back(d.sample_out&255); output.push_back(d.sample_out>>8); }
    }
    register_trace=nullptr;
    std::ofstream file(output_path,std::ios::binary); check(bool(file));
    file.write(reinterpret_cast<const char*>(output.data()),output.size()); check(bool(file));
    std::ofstream warmup(std::string(output_path)+".warmup"); check(bool(warmup));
    warmup<<warmup_executions<<'\n'; check(bool(warmup));
    std::cout<<"rendered,"<<frames<<",latency_frames,4"
             <<(read_during_audio?",read32_words,"+std::to_string(frames):"")<<'\n';
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if((argc==2 || argc==4) && std::string(argv[1])=="--read32") {
            std::vector<unsigned char> program;
            if(argc==4) {
                program=read(argv[2]);
                size_t used=0; expected_audio=std::stoi(argv[3],&used);
                check(used==std::string(argv[3]).size() && expected_audio>=-32768 && expected_audio<=32767);
            }
            read32_cases(program); return 0;
        }
        if(argc>=5 && (std::string(argv[1])=="--render" || std::string(argv[1])=="--render-live" || std::string(argv[1])=="--render-read32" || std::string(argv[1])=="--render-live-read32")) {
            bool live=std::string(argv[1])=="--render-live" || std::string(argv[1])=="--render-live-read32";
            check(!live || (argc>5 && (argc-5)%2==0));
            std::vector<std::vector<unsigned char>> updates;
            std::vector<size_t> frames;
            for(int i=5;i<argc;i+=live?2:1) {
                updates.push_back(read(argv[i]));
                if(live) {
                    size_t end; auto frame=std::stoull(argv[i+1],&end);
                    check(end==std::string(argv[i+1]).size()); frames.push_back(frame);
                }
            }
            bool with_reads=std::string(argv[1])=="--render-read32" || std::string(argv[1])=="--render-live-read32";
            render(argv[2],argv[3],argv[4],updates,frames,with_reads); return 0;
        }
        check(argc>=4 && argc%2==0);
        for(bool pattern:{false,true}) for(phase=0;phase<8;++phase) {
            separate=pattern; cycles=phase*127;
            Vtest_spi_engine d; d.cs=1; d.sck=0; d.mosi=0; d.sample_in=16384;
            d.reset=1; wait(d,8); d.reset=0; wait(d,2048);
            send(d,{11,4,0,12,4,0});
            auto program=read(argv[1]); program.insert(program.begin(),1); program.push_back(10);
            send(d,program);
            int n=0; while(!d.current_pipeline && n++<4096*2551) tick(d);
            check(d.current_pipeline==1); settled(d,-1024); endpoints(d,16384); stream(d,16384);
            for(int i=2;i<argc;i+=2) {
                int expected=std::stoi(argv[i+1]); check((expected+4096)*16%3==0);
                send(d,read(argv[i])); settled(d,expected);
                endpoints(d,(expected+4096)*16/3);
                stream(d,(expected+4096)*16/3);
            }
        }
        std::cout<<"SPI/full engine: eight phases/two CS patterns, compiled audio and repeated live commits exact\n";
    } catch(const std::exception& e) {
        std::cerr<<e.what()<<" phase="<<phase<<" separate_cs="<<separate<<'\n'; return 1;
    }
}
