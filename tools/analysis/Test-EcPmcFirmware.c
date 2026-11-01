/* Offline execution of the BIOS314 EC PMC4 command path, with emu8051.
 * Build against emu8051 commit 5dc681275151c4a5d7b85ec9ff4ceb1b25abd5a8.
 * Firmware is private input data. All peripheral accesses terminate in RAM.
 * This is not a complete EC, PD-controller, timing or live-flash model.
 */
#include <windows.h>
#include <bcrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu8051.h"

#define ROM_BYTES 262144
#define STOP_PC 0x7ffe
static unsigned char rom[ROM_BYTES], code[65536], xram[65536], upper[128];
static struct em8051 cpu;
static unsigned output_count, input_count, unexpected_accesses, instructions;
static unsigned char output[8];
static int fw_exception;
static int relay_mode, bus_result;
static unsigned bus_calls, bus_write_length, bus_read_length;
static unsigned bus_fail_call, first_register, first_write_length, first_read_length;
static unsigned char bus_write[32], bus_response[20];

static void exception(struct em8051 *c, int n) { (void)c; fw_exception=n+1; }
static unsigned char read_x(struct em8051 *c, unsigned short address) {
    (void)c;
    if (relay_mode) {
        if (address>=0x1000 && (address<0x4000 || address>=0x4030)) unexpected_accesses++;
        return xram[address];
    }
    if (address==0x1532) { xram[0x1530]&=~2; input_count++; }
    else if (address!=0x1530 && address!=0x1125) unexpected_accesses++;
    return xram[address];
}
static void write_x(struct em8051 *c, unsigned short address, unsigned char value) {
    (void)c;
    if (relay_mode) {
        if (address>=0x1000 && (address<0x4000 || address>=0x4030)) unexpected_accesses++;
        xram[address]=value; return;
    }
    if (address==0x1531) {
        if (output_count<sizeof(output)) output[output_count]=value;
        output_count++; xram[0x1530]|=1;
    } else if (address!=0x1125 && (address<0x067b || address>0x067d)) unexpected_accesses++;
    xram[address]=value;
}
static void init(unsigned char seed) {
    memset(&cpu,0,sizeof(cpu)); memset(xram,seed,sizeof(xram)); memset(upper,0,sizeof(upper));
    /* Fixed lower32KiB plus bank selector3's complete upper32KiB window.
     * A bank change is outside this harness and is rejected below. */
    memcpy(code,rom,0x8000); memcpy(code+0x8000,rom+0x18000,0x8000);
    cpu.mCodeMem=code; cpu.mCodeMemMaxIdx=65535;
    cpu.mExtData=xram; cpu.mExtDataMaxIdx=65535; cpu.mUpperData=upper;
    reset(&cpu,false); cpu.except=exception; cpu.xread=read_x; cpu.xwrite=write_x;
    cpu.mSFR[REG_P1]=3; cpu.mSFR[REG_SP]=0x70;
    output_count=input_count=unexpected_accesses=instructions=0; fw_exception=0;
}
static void execute(unsigned pc) {
    cpu.mPC=(unsigned short)pc; cpu.mTickDelay=0;
    push_to_stack(&cpu,STOP_PC&255); push_to_stack(&cpu,STOP_PC>>8);
    for (unsigned steps=0;cpu.mPC!=STOP_PC;steps++) {
        if (steps>=20000 || (cpu.mSFR[REG_P1]&7)!=3 || fw_exception) {
            fprintf(stderr,"Execution boundary: pc=%04x exception=%d\n",cpu.mPC,fw_exception); exit(2);
        }
        /* Explicit PD-bus boundary double, not execution of the bus engine. */
        if (relay_mode && cpu.mPC==0x1ff4) {
            unsigned src=(xram[0x6a2]<<8)|xram[0x6a3];
            unsigned dst=(xram[0x6a5]<<8)|xram[0x6a6];
            if ((cpu.mSFR[REG_PSW]&0x18) || cpu.mLowerData[7]!=4 || cpu.mLowerData[5]!=0x98 || cpu.mLowerData[2]!=0 || ++bus_calls>2) exit(4);
            bus_write_length=cpu.mLowerData[3]; bus_read_length=xram[0x6a4];
            if (bus_write_length>sizeof(bus_write) || bus_read_length>sizeof(bus_response) || src+bus_write_length>65536 || dst+bus_read_length>65536 || xram[0x6a7]) exit(4);
            memcpy(bus_write,xram+src,bus_write_length);
            if (bus_calls==1) { first_register=bus_write[0]; first_write_length=bus_write_length; first_read_length=bus_read_length; }
            int result=bus_result && bus_calls!=bus_fail_call;
            if (result) memcpy(xram+dst,bus_response,bus_read_length);
            cpu.mLowerData[7]=(unsigned char)result;
            unsigned high=cpu.mLowerData[cpu.mSFR[REG_SP]--];
            unsigned low=cpu.mLowerData[cpu.mSFR[REG_SP]--];
            cpu.mPC=(unsigned short)((high<<8)|low); continue;
        }
        if (tick(&cpu)) instructions++;
    }
    if (cpu.mSFR[REG_SP]!=0x70) { fprintf(stderr,"Unbalanced stack\n"); exit(2); }
}
static void input(int is_command, unsigned char value) {
    /* Feed one host byte through the original complete PMC4 service entry. */
    xram[0x1530]=(unsigned char)(2|(is_command?8:0)); xram[0x1532]=value;
    execute(0x9590);
}
static void check(int condition, unsigned line) {
    if (!condition) { fprintf(stderr,"Relay mismatch at line %u, bus calls=%u, writes=%u, reads=%u, pc=%04x\n",line,bus_calls,bus_write_length,bus_read_length,cpu.mPC); exit(5); }
}
#define require(condition) check((condition),__LINE__)
static void relay_init(void) {
    init(0); relay_mode=1; bus_calls=bus_write_length=bus_read_length=bus_fail_call=0;
    memset(bus_write,0,sizeof(bus_write)); memset(bus_response,0,sizeof(bus_response));
    /* A synthetic mailbox location, not a claim about the live EC mapping. */
    xram[0x580]=0x40; xram[0x581]=0;
}
static void test_relay(void) {
    unsigned outgoing=0,incoming=0,ack=0;
    for (unsigned command=0;command<256;command++) for (unsigned pattern=0;pattern<3;pattern++) for (int success=0;success<2;success++) {
        relay_init(); bus_result=success; xram[0x585]=(unsigned char)command;
        for(unsigned i=0;i<40;i++) xram[0x4008+i]=(unsigned char)(pattern==0?0:pattern==1?0xff:i*13+7);
        xram[0x4008]=0; /* The service C89A has consumed the opcode into0585. */
        execute(0xbacf);
        require(bus_calls==1 && bus_write_length==25 && !bus_read_length && !unexpected_accesses);
        require(bus_write[0]==0x98 && bus_write[1]==command && !memcmp(bus_write+2,xram+0x4009,7) && !memcmp(bus_write+9,xram+0x4020,16));
        require(cpu.mLowerData[7]==success && xram[0x585]==(success?0:command)); outgoing++;
    }
    for(unsigned interrupt=0;interrupt<256;interrupt++) for(int outcome=0;outcome<3;outcome++) {
        relay_init(); bus_result=outcome!=0; bus_fail_call=outcome==2?2:0;
        for(unsigned i=0;i<sizeof(bus_response);i++) bus_response[i]=(unsigned char)(interrupt+i*17);
        execute(0xbba3);
        require(first_register==0xbd && first_write_length==1 && first_read_length==1 && !unexpected_accesses);
        if (!outcome || !(interrupt&2)) {
            require(bus_calls==1 && bus_write_length==1 && bus_write[0]==0xbd && bus_read_length==1 && !unexpected_accesses);
            require(cpu.mLowerData[7]==(outcome?2:0));
        } else {
            require(bus_calls==2 && bus_write_length==1 && bus_write[0]==0x84 && bus_read_length==20);
            require(cpu.mLowerData[7]==(outcome==1));
            if(outcome==1) require(!memcmp(xram+0x4004,bus_response,4) && !memcmp(xram+0x4010,bus_response+4,16));
            else { unsigned char zero[16]={0}; require(!memcmp(xram+0x4004,zero,4) && !memcmp(xram+0x4010,zero,16)); }
        }
        incoming++;
    }
    for(int success=0;success<2;success++) {
        relay_init(); bus_result=success; execute(0xbb4f);
        require(bus_calls==1 && bus_write_length==2 && bus_write[0]==0xbc && bus_write[1]==0xfe && bus_read_length==1 && !unexpected_accesses);
        require(cpu.mLowerData[7]==success); ack++;
    }
    printf("{\"scope\":\"Original bank3 relay instructions; 1ff4 PD bus is a RAM double; no controller, timing or live-flash qualification\",\"outgoingCases\":%u,\"interruptCases\":%u,\"ackCases\":%u,\"passed\":%u}\n",outgoing,incoming,ack,outgoing+incoming+ack);
}
static void request(unsigned char command, const unsigned char *params, unsigned count, unsigned char seed) {
    init(seed); input(1,0xff); input(1,command);
    for(unsigned i=0;i<count;i++) input(0,params[i]);
    if (input_count!=count+2 || unexpected_accesses || cpu.mLowerData[0x61]!=0) {
        fprintf(stderr,"Unexpected request path: inputs=%u unexpected=%u remaining=%u\n",input_count,unexpected_accesses,cpu.mLowerData[0x61]); exit(2);
    }
}
static void emit(const char *kind, unsigned table, unsigned field, unsigned selector, unsigned seed) {
    static int comma=0;
    printf("%s{\"kind\":\"%s\",\"table\":%u,\"field\":%u,\"selector\":%u,\"seed\":%u,\"output\":\"",comma?",\n":"",kind,table,field,selector,seed);
    for(unsigned i=0;i<output_count;i++) printf("%02x",output[i]);
    printf("\",\"inputBytesConsumed\":%u,\"unexpectedPeripheralAccesses\":%u,\"instructions\":%u}",input_count,unexpected_accesses,instructions); comma=1;
}
int main(int argc, char **argv) {
    static const unsigned char pin[32]={0x10,0x37,0x21,0x57,0x8b,0x66,0xda,0xed,0x81,0xdc,0xf7,0xa0,0xbe,0xd0,0x67,0x09,0xc0,0x72,0xf9,0xda,0x1d,0xc7,0x5a,0x6d,0x78,0x87,0x32,0x1e,0x6e,0x32,0xb0,0x60};
    unsigned char digest[32], params[3]; unsigned cases=0;
    if(argc!=2 && !(argc==3 && !strcmp(argv[2],"--relay"))) { fprintf(stderr,"Usage: Test-EcPmcFirmware private-EC-image.bin [--relay]\n"); return 2; }
    FILE *f=NULL; if(fopen_s(&f,argv[1],"rb") || !f) return 2;
    size_t length=fread(rom,1,sizeof(rom),f); int extra=fgetc(f); fclose(f);
    if(length!=sizeof(rom) || extra!=EOF || BCryptHash(BCRYPT_SHA256_ALG_HANDLE,NULL,0,rom,sizeof(rom),digest,sizeof(digest))<0 || memcmp(pin,digest,32)) {
        fprintf(stderr,"Firmware input pin mismatch\n"); return 2;
    }
    if(argc==3) { test_relay(); return 0; }
    printf("{\"scope\":\"Original PMC4 service/dispatch/getters and switch helper; all peripherals are RAM doubles; no hardware/timing/live-flash qualification\",\"cases\":[\n");
    for(unsigned seed_index=0;seed_index<3;seed_index++) {
        unsigned seed=(unsigned char[]){0,0x5a,0xff}[seed_index];
        params[0]=0x50; request(0xbb,params,1,(unsigned char)seed);
        if(output_count!=1 || output[0]!=17) return 3;
        emit("capability",0,0x50,0,seed); cases++;
        for(unsigned field=2;field<14;field++) {
            const unsigned char expected[12]={'I','T','8','8','5','3',0,0,0,0,0,0};
            params[0]=5; params[1]=(unsigned char)field; params[2]=1;
            request(0xdd,params,3,(unsigned char)seed);
            if(output_count!=1 || output[0]!=expected[field-2]) return 3;
            emit("identity",5,field,1,seed); cases++;
        }
        const unsigned fields[]={0,1,2,3,4,5,0x1e,0x21,0x33,0xff};
        for(unsigned i=0;i<sizeof(fields)/sizeof(fields[0]);i++) {
            params[0]=6; params[1]=(unsigned char)fields[i]; params[2]=0;
            request(0xdd,params,3,(unsigned char)seed);
            if(output_count!=0) return 3;
            emit("unimplemented-dynamic-table",6,fields[i],0,seed); cases++;
        }
    }
    printf("\n],\"passed\":%u}\n",cases);
    return 0;
}
