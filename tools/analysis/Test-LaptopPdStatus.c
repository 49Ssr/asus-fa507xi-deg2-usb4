/* BIOS314 status/power consumers and PMC4 getters. Original instructions;
 * all bus and peripheral responses are RAM fixtures. No hardware backend. */
#define main prior_firmware_main
#include "Test-EcPmcFirmware.c"
#undef main

static unsigned transactions, ack_count, power_reads, fail_reg;
static unsigned char status_a, status_b, event_byte, pdo[4], ack_byte;
static unsigned char data_read(struct em8051 *c, unsigned short a) {
    (void)c;
    if (a==0x1532) { xram[0x1530]&=~2; input_count++; }
    if (a>=0x1000 && a!=0x160a && a!=0x1530 && a!=0x1532 && a!=0x1125)
        unexpected_accesses++;
    return xram[a];
}
static void data_write(struct em8051 *c, unsigned short a, unsigned char v) {
    (void)c;
    if (a==0x1531) { require(output_count<sizeof(output));output[output_count++]=v; }
    else if (a>=0x1000 && a!=0x1125) unexpected_accesses++;
    xram[a]=v;
}
static void run_path(unsigned entry) {
    cpu.mPC=(unsigned short)entry;cpu.mTickDelay=0;
    push_to_stack(&cpu,STOP_PC&255);push_to_stack(&cpu,STOP_PC>>8);
    for (unsigned steps=0;cpu.mPC!=STOP_PC;steps++) {
        require(steps<20000 && !fw_exception && (cpu.mSFR[REG_P1]&7)==3);
        if (cpu.mPC==0x1ff4) {
            unsigned src=(xram[0x6a2]<<8)|xram[0x6a3];
            unsigned dst=(xram[0x6a5]<<8)|xram[0x6a6];
            unsigned n=xram[0x6a4],sel=xram[src],w=cpu.mLowerData[3];
            require(++transactions<=5 && cpu.mLowerData[7]==4 && cpu.mLowerData[5]==0x98);
            require(!cpu.mLowerData[2] && !xram[0x6a7] && dst+n<=65536);
            if (sel==0xbc) {require(w==2 && n==0);ack_count++;ack_byte=xram[src+1];}
            else {
                require(w==1 && (sel==0xbd || sel==0xb0 || sel==0xb1 || sel==0xcc));
                require(n==(sel==0xcc?4u:1u));
                if (sel==0xcc) power_reads++;
                if (sel!=fail_reg) {
                    if(sel==0xcc)memcpy(xram+dst,pdo,4);
                    else xram[dst]=sel==0xbd?event_byte:(sel==0xb0?status_a:status_b);
                }
            }
            cpu.mLowerData[7]=(unsigned char)(sel!=fail_reg);
            return_from_double();continue;
        }
        tick(&cpu);
    }
    require(cpu.mSFR[REG_SP]==0x70 && !unexpected_accesses);
}
static void setup(void) {
    init(0);relay_mode=service_mode=engine_mode=0;cpu.xread=data_read;cpu.xwrite=data_write;
    transactions=ack_count=power_reads=fail_reg=0;status_a=status_b=ack_byte=0;event_byte=2;
    xram[0x308]=8;xram[0x160a]=2;cpu.mLowerData[7]=1;
    pdo[0]=0;pdo[1]=1;pdo[2]=0x91;pdo[3]=0x2c; /* 5 V, 3 A fixed PDO */
}
static unsigned mapped(unsigned b,unsigned old) {
    return !(b&1)?0:((old&~0x49)|0x80|((b&2)?0x40:0)|((b&4)?1:0)|((b&16)?8:0));
}
static void host_byte(int command,unsigned char value) {
    xram[0x1530]=(unsigned char)(2|(command?8:0));xram[0x1532]=value;run_path(0x9590);
}
static void getter(unsigned field) {
    host_byte(1,0xff);host_byte(1,0xdd);host_byte(0,5);host_byte(0,(unsigned char)field);host_byte(0,1);
}
int main(int argc,char **argv) {
    const unsigned char pin[32]={0x10,0x37,0x21,0x57,0x8b,0x66,0xda,0xed,0x81,0xdc,0xf7,0xa0,0xbe,0xd0,0x67,0x09,0xc0,0x72,0xf9,0xda,0x1d,0xc7,0x5a,0x6d,0x78,0x87,0x32,0x1e,0x6e,0x32,0xb0,0x60};
    unsigned char digest[32];FILE *f=NULL;
    if(argc!=2 || fopen_s(&f,argv[1],"rb") || !f)return 2;
    size_t n=fread(rom,1,sizeof(rom),f);int extra=fgetc(f);fclose(f);
    if(n!=sizeof(rom)||extra!=EOF||BCryptHash(BCRYPT_SHA256_ALG_HANDLE,NULL,0,rom,sizeof(rom),digest,sizeof(digest))<0||memcmp(pin,digest,32))return 2;
    unsigned maps=0,failures=0,getters=0,power_cases=0;
    for(unsigned port=0;port<2;port++)for(unsigned seed=0;seed<2;seed++)for(unsigned b=0;b<256;b++) {
        setup();unsigned old=seed?0x36:0;xram[0x730]=xram[0x794]=(unsigned char)old;
        if(port)status_b=(unsigned char)b;else status_a=(unsigned char)b;
        run_path(0xbc3c);
        require(xram[port?0x794:0x730]==mapped(b,old));
        require(xram[port?0x730:0x794]==0 && !ack_count);
        require(power_reads==(unsigned)(port && (mapped(b,old)&0xc8)==0xc0));maps++;
    }
    for(unsigned port=0;port<2;port++) {
        setup();fail_reg=port?0xb1:0xb0;xram[port?0x794:0x730]=0xc0;run_path(0xbc3c);
        require(xram[port?0x794:0x730]==0xc0);require(power_reads==port);failures++;
    }
    for(unsigned volts=5;volts<=20;volts+=5) {
        setup();status_b=3;unsigned word=((volts*1000/50)<<10)|300;
        for(unsigned i=0;i<4;i++)pdo[i]=(unsigned char)(word>>(24-i*8));
        run_path(0xbc3c);
        require(power_reads==1 && ((xram[0x5c0]<<8)|xram[0x5c1])==volts*1000);
        require(((xram[0x5c2]<<8)|xram[0x5c3])==3000 && xram[0x5bf]==volts*3);power_cases++;
        transactions=0;getter(0x20);require(output_count==1 && output[0]==2 && !transactions);getters++;
    }
    for(unsigned field=0x12;field<=0x1f;field++) {
        setup();xram[0x5bf]=60;getter(field);require(output_count==1 && output[0]==0 && !transactions);getters++;
    }
    setup();getter(0x20);require(output_count==1 && output[0]==0 && !transactions);getters++;
    setup();status_b=3;fail_reg=0xcc;xram[0x5bf]=60;run_path(0xbc3c);
    require(power_reads==1 && xram[0x5bf]==60);failures++;
    setup();event_byte=1;run_path(0xbc3c);require(ack_count==1 && ack_byte==0xfd);
    setup();event_byte=0;xram[0x160a]=0;run_path(0xbc3c);require(ack_count==1 && ack_byte==0xff);
    setup();xram[0x308]=0;run_path(0xbc3c);require(!transactions);
    printf("{\"statusMappingCases\":%u,\"failureCases\":%u,\"fixedPdoCases\":%u,\"getterCases\":%u,\"eventAcknowledgementCases\":2,\"disabledGateCases\":1,\"rawStatusBitsRetained\":[0,1,2,4],\"getter20IsPowerPresence\":true,\"hardwareRequests\":0}\n",maps,failures,power_cases,getters);
    return 0;
}
