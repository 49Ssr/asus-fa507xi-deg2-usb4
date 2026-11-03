/* Follow the reference record's producers and receiver initialization offline.
 * Reuses the pinned firmware loader, bank model and 40 earlier dispatch checks.
 * Output is JSON Lines: the existing dispatch result, then this follow-up result.
 * The send helper is a declared return-value fixture, not a simulated PD wire.
 */
#define main dispatch_fixture_main
#include "Test-It8857Dispatch.c"
#undef main

static void followup_require(int condition, int line, const char *expression) {
    if (!condition) fprintf(stderr, "Follow-up assertion at line %d: %s\n", line, expression);
    require(condition);
}
#define require(condition) followup_require((condition), __LINE__, #condition)

static unsigned mmio_reads, mmio_writes, send_calls, send_type, send_result;
static int allow_init;
static unsigned write_addresses[32], write_values[32];

static int allowed_mmio(unsigned address) {
    if (address == 0xff50) return 1;
    if (!allow_init) return 0;
    switch (address) {
    case 0xfc00: case 0xfc01: case 0xfc03: case 0xfc04:
    case 0xfc06: case 0xfc07: case 0xfc1f: case 0xffc6: return 1;
    default: return 0;
    }
}
static unsigned char record_read(struct em8051 *c, unsigned short address) {
    if (allowed_mmio(address)) { mmio_reads++; return ram[address]; }
    return read_ram(c, address);
}
static void record_write(struct em8051 *c, unsigned short address, unsigned char value) {
    if (allowed_mmio(address)) {
        require(mmio_writes < 32);
        write_addresses[mmio_writes] = address;
        write_values[mmio_writes++] = value;
        ram[address] = value;
        return;
    }
    write_ram(c, address, value);
}
static void init_record(void) {
    initialize(0);
    cpu.xread = record_read;
    cpu.xwrite = record_write;
    mmio_reads = mmio_writes = send_calls = send_type = 0;
    allow_init = 0;
}
static unsigned long get_word(unsigned address) {
    return ((unsigned long)ram[address] << 24) | ((unsigned long)ram[address+1] << 16) |
           ((unsigned long)ram[address+2] << 8) | ram[address+3];
}
static void put_word(unsigned address, unsigned long value) {
    for (unsigned j=0; j<4; j++) ram[address+j] = (unsigned char)(value >> (24-8*j));
}
/* Instruction execution is unchanged except for the explicitly declared send
 * helper boundary. Return its fixture result using the normal 8051 call stack. */
static unsigned run_with_send_result(unsigned entry, unsigned stop) {
    cpu.mPC = (unsigned short)entry;
    push_to_stack(&cpu, 0xfe);
    push_to_stack(&cpu, 0x7f);
    while (cpu.mPC != stop && cpu.mPC != 0x7ffe) {
        require(steps++ < 20000 && !fault);
        unsigned selected = cpu.mSFR[REG_P1] & 7;
        require(selected < 3);
        if (selected != bank) {
            memcpy(code+0x8000, rom+0x8000+selected*0x8000, 0x8000);
            bank = selected;
        }
        if (cpu.mPC == 0x4c5e) {
            require(cpu.mSFR[REG_SP] <= 0x7f && cpu.mSFR[REG_SP] >= 2);
            send_calls++;
            send_type = cpu.mLowerData[3];
            unsigned high = cpu.mLowerData[cpu.mSFR[REG_SP]--];
            unsigned low = cpu.mLowerData[cpu.mSFR[REG_SP]--];
            cpu.mPC = (unsigned short)((high << 8) | low);
            cpu.mLowerData[7] = (unsigned char)send_result;
            continue;
        }
        tick(&cpu);
    }
    require(!fault);
    return cpu.mPC;
}
static void verify_serialization(unsigned port, unsigned long value) {
    /* Keep the produced record; only prepare the original read-dispatch inputs. */
    select_receiver_bank();
    ram[0x141b] = (unsigned char)port;
    ram[0x5c5] = 0x10;
    for (unsigned index=0; index<4; index++) {
        ram[0x5c6] = (unsigned char)index;
        output_count = 0;
        steps = 0;
        require(execute(0x8a90, 0x8b7d, 0xffff) == 0x8b7d);
        require(output_count == 1 && output_byte == ((value >> (8*index)) & 255));
    }
}
int main(int argc, char **argv) {
    int result = dispatch_fixture_main(argc, argv);
    if (result) return result;
    unsigned cases = 0;
    const unsigned init_addresses[] = {
        0xfc03,0xfc1f,0xffc6,0xffc6,0xfc07,0xfc00,0xfc01,
        0xfc04,0xfc01,0xfc01,0xfc00,0xfc06
    };
    const unsigned init_values[] = {0xf0,0xf8,4,0x84,0xff,0x80,0,0xff,1,9,0xa0,0x10};
    init_record(); allow_init = 1; cpu.mLowerData[7] = 1;
    require(execute(0x4b78, 0xffff, 0xffff) == 0x7ffe);
    if (mmio_writes != sizeof(init_addresses)/sizeof(init_addresses[0]))
        fprintf(stderr, "Initialization writes: %u\n", mmio_writes);
    require(mmio_writes == sizeof(init_addresses)/sizeof(init_addresses[0]));
    for (unsigned j=0; j<mmio_writes; j++)
    {
        if (write_addresses[j] != init_addresses[j] || write_values[j] != init_values[j])
            fprintf(stderr, "Write[%u]: %04x=%02x, expected %04x=%02x\n", j,
                    write_addresses[j],write_values[j],init_addresses[j],init_values[j]);
        require(write_addresses[j] == init_addresses[j] && write_values[j] == init_values[j]);
    }
    cases++;

    for (unsigned port=0; port<2; port++) {
        init_record(); cpu.mLowerData[7] = (unsigned char)port;
        put_word(0x5e4+0x18*port, 0xabcdef12);
        require(execute(0x4c77, 0xffff, 0xffff) == 0x7ffe);
        require(get_word(0x5e4+0x18*port) == 1 &&
                get_word(0x5d8+0x18*port) == 3 && ram[0xff50] == 0x20);
        verify_serialization(port, 1); cases++;

        init_record(); cpu.mLowerData[7] = (unsigned char)port;
        put_word(0x5e4+0x18*port, 0xabcdef12);
        require(execute(0x4bf0, 0xffff, 0xffff) == 0x7ffe);
        require(get_word(0x5e4+0x18*port) == 0 && mmio_writes == 0);
        verify_serialization(port, 0); cases++;

        /* Original data-message dispatcher identifies type8 as the handler. */
        init_record(); cpu.mLowerData[7] = (unsigned char)port;
        cpu.mLowerData[3] = 8;
        ram[0x503+0x5e*port] = 2;
        require(execute(0x2373, 0x2d4c, 0x4c5e) == 0x2d4c);
        cases++;

        for (unsigned mode=0; mode<4; mode++) {
            for (unsigned orientation=0; orientation<2; orientation++) {
                for (send_result=0; send_result<2; send_result++) {
                    init_record();
                    ram[0x1465] = (unsigned char)port;
                    ram[0x1468] = 1; ram[0x1469] = 0x10; ram[0x146a] = 0;
                    put_word(0x1000, (unsigned long)mode << 28);
                    ram[0x1801+0x23*port] = (unsigned char)orientation;
                    unsigned long before = 0x12345670;
                    put_word(0x5e4+0x18*port, before);
                    unsigned stopped = run_with_send_result(0x2d4c, 0x2e11);
                    require(stopped == (mode<3 ? 0x2e11 : 0x7ffe));
                    require(send_calls == 1 && send_type == (mode<3 ? 3 : 4));
                    unsigned long after = before;
                    if (mode<3 && send_result==1)
                        after = ((before | 0x1800) & ~0x20UL) | (orientation ? 2 : 0);
                    require(get_word(0x5e4+0x18*port) == after);
                    require(mmio_writes == (mode<3 && send_result==1 ? 1 : 0));
                    verify_serialization(port, after);
                    cases++;
                }
            }
        }
    }
    printf("{\"followupCases\":%u,\"enterUsbModesTested\":[0,1,2,3],"
           "\"recordSetMaskHex\":\"00001800\",\"recordClearMaskHex\":\"00000020\","
           "\"enterUsbRecordChangesOnlyAfterSendReturnsOne\":true,"
           "\"receiverInitializationExecuted\":true,\"hardwareRequests\":0}\n", cases);
    return 0;
}

