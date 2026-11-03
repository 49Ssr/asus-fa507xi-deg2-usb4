/* Offline BIOS314 cache getter/population checks. No live device APIs. */
#define main existing_harness_main
#include "Test-EcPmcFirmware.c"
#undef main
static unsigned cache_reads;
static unsigned char cache_read(struct em8051 *c, unsigned short address) {
    if(address==0x2ac || address==0x2ad) {cache_reads++;return xram[address];}
    return read_x(c,address);
}
int main(int argc,char **argv) {
    const unsigned char pin[32]={0x10,0x37,0x21,0x57,0x8b,0x66,0xda,0xed,0x81,0xdc,0xf7,0xa0,0xbe,0xd0,0x67,0x09,0xc0,0x72,0xf9,0xda,0x1d,0xc7,0x5a,0x6d,0x78,0x87,0x32,0x1e,0x6e,0x32,0xb0,0x60};
    unsigned char digest[32];FILE *f=NULL;
    if(argc!=2 || fopen_s(&f,argv[1],"rb") || !f)return 2;
    size_t n=fread(rom,1,sizeof(rom),f);int extra=fgetc(f);fclose(f);
    if(n!=sizeof(rom)||extra!=EOF||BCryptHash(BCRYPT_SHA256_ALG_HANDLE,NULL,0,rom,sizeof(rom),digest,sizeof(digest))<0||memcmp(pin,digest,32))return 2;
    const unsigned char values[][2]={{0,4},{1,0x5a},{0xff,0xff}};
    for(unsigned v=0;v<3;v++)for(unsigned field=0;field<2;field++){
        init(0);relay_mode=service_mode=engine_mode=0;cpu.xread=cache_read;cache_reads=0;
        xram[0x2ac]=values[v][0];xram[0x2ad]=values[v][1];
        input(1,0xff);input(1,0xdd);input(0,5);input(0,(unsigned char)(0x10+field));input(0,1);
        require(output_count==1 && output[0]==values[v][field] && cache_reads==1 && !unexpected_accesses && input_count==5);
    }
    for(unsigned success=0;success<2;success++){
        relay_init();bus_result=success;bus_response[0]=0x01;bus_response[1]=0x26;
        xram[0x2ac]=0x5a;xram[0x2ad]=0xa5;
        execute(0xb800);
        require(bus_calls==1 && bus_write_length==1 && bus_write[0]==0xb6 && bus_read_length==2 && !unexpected_accesses);
        require(xram[0x2ac]==(success?1:0x5a) && xram[0x2ad]==(success?0x26:0xa5));
    }
    puts("{\"cacheGetters\":6,\"b6PopulateCases\":2,\"getterReadsOnlyEcCache\":true,\"failedRefreshPreservesOldCache\":true,\"hardwareRequests\":0}");
    return 0;
}
