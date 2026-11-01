/* Original BIOS314 EC instructions, offline only. No hardware backend.
 * emu8051: 5dc681275151c4a5d7b85ec9ff4ceb1b25abd5a8 (MIT).
 * Checks address translation, host-command ownership and the outer UCSI gate.
 * The UCSI worker is a counting double, not an emulated PD controller.
 */
#include <windows.h>
#include <bcrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu8051.h"

static unsigned char rom[262144], code[65536], ram[65536], upper[128];
static struct em8051 cpu;
static unsigned bank, mode, reads, writes, inputs, worker_calls, cpu_fault;
static unsigned last_read, last_write;
#define STOP 0x7ffe

static void fail(const char *why) { fprintf(stderr,"%s pc=%04x bank=%u\n",why,cpu.mPC,bank); exit(3); }
static void fault(struct em8051 *c,int n) { (void)c; cpu_fault=n+1; }
static unsigned char read_ram(struct em8051 *c,unsigned short a) {
    (void)c;
    if (a>=0x1000 && a!=0x221b && !(mode==3 && (a==0x1520 || a==0x1522 || a==0x1125))) fail("Unexpected peripheral read");
    reads++; last_read=a;
    if (mode==3 && a==0x1522) { ram[0x1520]&=~2; inputs++; }
    return ram[a];
}
static void write_ram(struct em8051 *c,unsigned short a,unsigned char v) {
    (void)c;
    if (a>=0x1000 && a!=0x221b && !(mode==3 && a==0x1125)) fail("Unexpected peripheral write");
    writes++; last_write=a; ram[a]=v;
}
static void init(unsigned b,unsigned m) {
    memset(&cpu,0,sizeof(cpu)); memset(ram,0,sizeof(ram)); memset(upper,0,sizeof(upper));
    memcpy(code,rom,0x8000); memcpy(code+0x8000,rom+b*0x8000,0x8000);
    cpu.mCodeMem=code; cpu.mCodeMemMaxIdx=65535; cpu.mExtData=ram; cpu.mExtDataMaxIdx=65535; cpu.mUpperData=upper;
    reset(&cpu,false); cpu.xread=read_ram; cpu.xwrite=write_ram; cpu.except=fault;
    cpu.mSFR[REG_P1]=(unsigned char)b; cpu.mLowerData[8]=(unsigned char)(0x0a+(b-1)*0x14); cpu.mSFR[REG_SP]=0x70;
    bank=b; mode=m; reads=writes=inputs=worker_calls=cpu_fault=0;
}
static void return_double(void) {
    unsigned hi=cpu.mLowerData[cpu.mSFR[REG_SP]--],lo=cpu.mLowerData[cpu.mSFR[REG_SP]--]; cpu.mPC=(unsigned short)((hi<<8)|lo);
}
static void run(unsigned pc,unsigned end,int function) {
    cpu.mPC=(unsigned short)pc;
    if (function) { push_to_stack(&cpu,STOP&255); push_to_stack(&cpu,STOP>>8); }
    for (unsigned steps=0;cpu.mPC!=end;steps++) {
        unsigned selected=cpu.mSFR[REG_P1]&7;
        if (steps>=3000 || cpu_fault) fail("Execution limit or CPU exception");
        if (selected!=bank) {
            if (selected>3 || (selected==0 && cpu.mPC>=0x8000)) fail("Unexpected bank");
            if (selected) memcpy(code+0x8000,rom+selected*0x8000,0x8000);
            bank=selected;
        }
        if (mode==4 && bank==3 && cpu.mPC==0xbc20) { worker_calls++; return_double(); continue; }
        tick(&cpu);
    }
    if (function && cpu.mSFR[REG_SP]!=0x70) fail("Stack imbalance");
}
int main(int argc,char **argv) {
    const unsigned char pin[32]={0x10,0x37,0x21,0x57,0x8b,0x66,0xda,0xed,0x81,0xdc,0xf7,0xa0,0xbe,0xd0,0x67,0x09,0xc0,0x72,0xf9,0xda,0x1d,0xc7,0x5a,0x6d,0x78,0x87,0x32,0x1e,0x6e,0x32,0xb0,0x60};
    unsigned char hash[32]; FILE *f=NULL;
    if (argc!=2 || fopen_s(&f,argv[1],"rb") || !f) return 2;
    size_t n=fread(rom,1,sizeof(rom),f); int extra=fgetc(f); fclose(f);
    if (n!=sizeof(rom) || extra!=EOF || BCryptHash(BCRYPT_SHA256_ALG_HANDLE,NULL,0,rom,sizeof(rom),hash,32)<0 || memcmp(hash,pin,32)) return 2;
    /* The exact standard RD_EC getter, including its original address helper. */
    for (unsigned value=0;value<256;value++) {
        init(1,1); ram[0x030e]=(unsigned char)value; cpu.mLowerData[7]=0x0e;
        run(0xe421,STOP,1);
        if (reads!=1 || last_read!=0x030e || writes || cpu.mLowerData[7]!=value || ram[0x030e]!=value) fail("Read translation");
    }
    /* WR_EC is executed ONLY against RAM here, to identify another writer.
     * No write routine or command is exposed as a live tool. */
    for (unsigned value=0;value<256;value++) {
        init(1,2); cpu.mLowerData[7]=0x0e; cpu.mLowerData[5]=(unsigned char)value;
        run(0xe427,STOP,1);
        if (reads || writes!=1 || last_write!=0x030e || ram[0x030e]!=value) fail("Write translation");
    }
    /* Original PMC3 receiver, bank trampoline, switch and handler. */
    const unsigned commands[]={0x75,0x76};
    for (unsigned j=0;j<2;j++) for (unsigned value=0;value<256;value++) {
        init(1,3); ram[0x030e]=(unsigned char)value; ram[0x1520]=0x0a; ram[0x1522]=(unsigned char)commands[j];
        run(0x0a71,STOP,1);
        unsigned expected=j?(value&0xfd):(value|2);
        if (inputs!=1 || ram[0x030e]!=expected || bank!=1 || (j && ram[0x03a3]!=10)) fail("Host-command flag ownership");
    }
    /* Outer caller: a set bit skips the entire worker that includes C89A. */
    for (unsigned value=0;value<256;value++) {
        init(1,4); ram[0x030e]=(unsigned char)value; run(0xb23c,STOP,1);
        if (worker_calls!=((value&2)?0u:1u) || ram[0x030e]!=value || writes) fail("Outer service gate");
    }
    /* Exact bounded whole-byte restore; does NOT emulate its storage source. */
    for (unsigned value=0;value<256;value++) {
        init(2,5); ram[0x221b]=(unsigned char)value; run(0xc93b,0xc943,0);
        if (ram[0x030e]!=value || reads!=1 || writes!=1) fail("Retained-byte restore");
    }
    for (unsigned value=0;value<256;value++) {
        init(1,6); ram[0x030e]=(unsigned char)value; run(0xa35e,0xa368,0);
        if (ram[0x221b]!=(value&0x40) || ram[0x030e]!=value || writes!=1) fail("Retained-byte save mask");
    }
    puts("{\"scope\":\"Original firmware with RAM-only peripheral state; PMC3 receive and bank trampolines execute; UCSI worker is a counting double; storage loading and physical memory alias untested\",\"groupsPassed\":[\"RD_EC offset0e reads030e without writes\",\"WR_EC can replace030e\",\"PMC3 host75 sets and76 clears only bit1\",\"outer caller suppresses UCSI worker when bit1 set\",\"retained221b whole-byte restore\",\"save path retains only bit6\"],\"liveReads\":0,\"liveWrites\":0}");
    return 0;
}
