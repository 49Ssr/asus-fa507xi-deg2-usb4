/* Offline PMC3 transfer-path test. Original firmware instructions, RAM only.
 * The bus transaction is intercepted; this does not test a physical PD chip. */
#define main existing_harness_main
#include "Test-EcPmcFirmware.c"
#undef main
static unsigned transfers, target, channel, write_len, read_len, replies;
static unsigned char sent[32], reply[40];
static int success;
static unsigned char pmc_read(struct em8051 *c, unsigned short a) {
    (void)c;
    if(a==0x1522) {xram[0x1520]&=~2; input_count++;}
    if(a>=0x1000 && a!=0x1520 && a!=0x1522 && a!=0x1125) unexpected_accesses++;
    return xram[a];
}
static void pmc_write(struct em8051 *c, unsigned short a, unsigned char v) {
    (void)c;
    if(a==0x1521) {require(replies<sizeof(reply));reply[replies++]=v;}
    else if(a>=0x1000 && a!=0x1125) unexpected_accesses++;
    xram[a]=v;
}
static void run(unsigned entry) {
    cpu.mPC=(unsigned short)entry;cpu.mTickDelay=0;
    push_to_stack(&cpu,STOP_PC&255);push_to_stack(&cpu,STOP_PC>>8);
    for(unsigned steps=0;cpu.mPC!=STOP_PC;steps++) {
        require(steps<20000 && !fw_exception && (cpu.mSFR[REG_P1]&7)==3);
        if(cpu.mPC==0x1ff4) {
            unsigned src=(xram[0x6a2]<<8)|xram[0x6a3];
            unsigned dst=(xram[0x6a5]<<8)|xram[0x6a6];
            transfers++;channel=cpu.mLowerData[7];target=cpu.mLowerData[5];
            write_len=cpu.mLowerData[3];read_len=xram[0x6a4];
            require(cpu.mLowerData[2]==0 && !xram[0x6a7]);
            require(write_len<=32 && read_len<=32 && src+write_len<=65536 && dst+read_len<=65536);
            memcpy(sent,xram+src,write_len);
            if(success) for(unsigned i=0;i<read_len;i++)xram[dst+i]=(unsigned char)(0xa0+i);
            cpu.mLowerData[7]=(unsigned char)success;return_from_double();continue;
        }
        tick(&cpu);
    }
    require(cpu.mSFR[REG_SP]==0x70 && !unexpected_accesses);
}
static void host(int command,unsigned char value) {
    xram[0x1520]=(unsigned char)(2|(command?8:0));xram[0x1522]=value;
    run(0x0a71);
}
int main(int argc,char **argv) {
    const unsigned char pin[32]={0x10,0x37,0x21,0x57,0x8b,0x66,0xda,0xed,0x81,0xdc,0xf7,0xa0,0xbe,0xd0,0x67,0x09,0xc0,0x72,0xf9,0xda,0x1d,0xc7,0x5a,0x6d,0x78,0x87,0x32,0x1e,0x6e,0x32,0xb0,0x60};
    unsigned char digest[32];FILE *f=NULL;
    if(argc!=2 || fopen_s(&f,argv[1],"rb") || !f)return 2;
    size_t n=fread(rom,1,sizeof(rom),f);int extra=fgetc(f);fclose(f);
    if(n!=sizeof(rom)||extra!=EOF||BCryptHash(BCRYPT_SHA256_ALG_HANDLE,NULL,0,rom,sizeof(rom),digest,sizeof(digest))<0||memcmp(pin,digest,32))return 2;
    unsigned cases=0;
    const unsigned lengths[]={0,2,32,33,255};
    for(unsigned payload=1;payload<=2;payload++)for(unsigned i=0;i<5;i++)for(success=0;success<=1;success++) {
        init(0);cpu.xread=pmc_read;cpu.xwrite=pmc_write;
        transfers=replies=0;memset(reply,0,sizeof(reply));
        memset(xram+0xa90,0x5a,32);
        cpu.mLowerData[8]=0x32; /* Bank3 return selector, matching the mapped code view. */
        host(1,0x71);host(0,(unsigned char)payload);
        if(payload==2)host(0,0x98);
        host(0,0xb6);
        require(!transfers && xram[0xa70+payload-1]==0xb6);
        host(1,0x70);host(0,(unsigned char)lengths[i]);
        unsigned capped=lengths[i]>32?32:lengths[i];
        require(transfers==1 && target==0x80 && channel==4 && write_len==payload && sent[payload-1]==0xb6 && read_len==capped);
        if(payload==2)require(sent[0]==0x98);
        require(replies==1 && reply[0]==(success?0xcc:0xee));
        host(1,0x72);
        require(replies==capped+2 && reply[1]==capped);
        for(unsigned j=0;j<capped;j++)require(reply[j+2]==(success?(unsigned char)(0xa0+j):0x5a));
        require(!cpu.mLowerData[0x5a]);cases++;
    }
    printf("{\"cases\":%u,\"originalPmc3ReceiverExecuted\":true,\"targetAddressHex\":\"80\",\"channel\":4,\"readLengthClamp\":32,\"busIsRamDouble\":true,\"hardwareRequests\":0}\n",cases);
    return 0;
}
