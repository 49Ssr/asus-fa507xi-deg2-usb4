/* Execute selected original IT8857 add-in-card firmware paths in RAM.
 * Build with emu8051 5dc681275151c4a5d7b85ec9ff4ceb1b25abd5a8 and bcrypt.lib.
 * Private firmware is an input file; no device access or firmware is included.
 * The receiver's peripheral registers are fixtures. Execution stops before
 * the state setter / transmit helper, so neither completion nor timing is tested.
 */
#include <windows.h>
#include <bcrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu8051.h"

static unsigned char rom[131072], code[65536], ram[65536], upper[128];
static struct em8051 cpu;
static int fault, receiver_fixture;
static unsigned steps, bank, fifo_index, acknowledgements, fixture_port;
static unsigned output_count;
static unsigned char fifo[3], output_byte;

static void require(int condition) {
    if (!condition) {
        fprintf(stderr, "Assertion: PC=%04x bank=%u steps=%u fault=%d\n",
                cpu.mPC, bank, steps, fault);
        exit(3);
    }
}

static void exception(struct em8051 *c, int number) {
    (void)c;
    fault = number + 1;
}

static unsigned char read_ram(struct em8051 *c, unsigned short address) {
    (void)c;
    if (receiver_fixture) {
        /* Inputs to the reference receiver, not a model of the physical bus.
         * Its first ACK starts reception without consuming a FIFO byte. */
        if (address == 0xfc04) return fifo_index < 3 ? 0x11 : 0;
        if (address == 0xfc05) return (unsigned char)(fixture_port * 2);
        if (address == 0xfc08) {
            require(fifo_index < 3);
            return fifo[fifo_index++];
        }
        if (address == 0xfc01) return 0;
    }
    require(address < 0x2000);
    return ram[address];
}

static void write_ram(struct em8051 *c, unsigned short address, unsigned char value) {
    (void)c;
    if (receiver_fixture && address == 0xfc10) {
        output_count++;
        output_byte = value;
        return;
    }
    if (receiver_fixture && address == 0xfc01) {
        require(value == 1);
        acknowledgements++;
        return;
    }
    require(address < 0x2000);
    ram[address] = value;
}

static void initialize(unsigned char seed) {
    memset(&cpu, 0, sizeof(cpu));
    memset(ram, seed, sizeof(ram));
    memset(upper, 0, sizeof(upper));
    memcpy(code, rom, sizeof(code));
    cpu.mCodeMem = code;
    cpu.mCodeMemMaxIdx = 65535;
    cpu.mExtData = ram;
    cpu.mExtDataMaxIdx = 65535;
    cpu.mUpperData = upper;
    reset(&cpu, false);
    cpu.except = exception;
    cpu.xread = read_ram;
    cpu.xwrite = write_ram;
    cpu.mSFR[REG_P1] = 0;
    cpu.mSFR[REG_SP] = 0x60;
    cpu.mLowerData[8] = 0x1f;  /* Keil external stack: private RAM fixture. */
    cpu.mLowerData[9] = 0;
    cpu.mLowerData[10] = 0x0a; /* Bank-zero return trampoline. */
    fault = receiver_fixture = 0;
    steps = bank = fifo_index = acknowledgements = output_count = 0;
    output_byte = 0;
}

static unsigned execute(unsigned entry, unsigned stop1, unsigned stop2) {
    cpu.mPC = (unsigned short)entry;
    push_to_stack(&cpu, 0xfe);
    push_to_stack(&cpu, 0x7f);
    while (cpu.mPC != 0x7ffe && cpu.mPC != stop1 && cpu.mPC != stop2) {
        require(steps++ < 20000 && !fault);
        unsigned selected_bank = cpu.mSFR[REG_P1] & 7;
        require(selected_bank < 3);
        if (selected_bank != bank) {
            memcpy(code + 0x8000, rom + 0x8000 + selected_bank * 0x8000, 0x8000);
            bank = selected_bank;
        }
        tick(&cpu);
    }
    require(!fault);
    return cpu.mPC;
}

static void select_receiver_bank(void) {
    receiver_fixture = 1;
    cpu.mSFR[REG_P1] = 2;
    cpu.mLowerData[10] = 0x32;
}

int main(int argc, char **argv) {
    const unsigned char expected_sha256[32] = {
        0x12,0xb2,0x1f,0x53,0xf9,0xcb,0xc8,0x3b,0xc3,0x6e,0x69,0x2c,0xad,0xac,0x8d,0xe6,
        0x23,0xde,0xd6,0x05,0xe3,0xd5,0x63,0x21,0x23,0x77,0xf5,0x21,0x14,0x06,0x94,0xe3
    };
    unsigned char digest[32];
    FILE *input = NULL;
    if (argc != 2 || fopen_s(&input, argv[1], "rb") || !input) return 2;
    size_t size = fread(rom, 1, sizeof(rom), input);
    int extra = fgetc(input);
    fclose(input);
    if (size != sizeof(rom) || extra != EOF ||
        BCryptHash(BCRYPT_SHA256_ALG_HANDLE, NULL, 0, rom, sizeof(rom), digest, 32) < 0 ||
        memcmp(expected_sha256, digest, 32)) return 2;

    unsigned cases = 0;
    /* Incoming PD control message 14. The port field's semantics remain unknown;
     * vary it across both sides of the original compare instead of naming it. */
    for (unsigned port = 0; port < 2; port++) {
        for (unsigned sop = 0; sop < 2; sop++) {
            for (unsigned field = 0; field < 4; field++) {
                initialize(0);
                cpu.mLowerData[7] = (unsigned char)port;
                cpu.mLowerData[5] = (unsigned char)sop;
                cpu.mLowerData[3] = 14;
                ram[0x503 + 0x5e * port] = (unsigned char)field;
                unsigned stop = execute(0x041e, 0x4c5e, 0xffff);
                if (sop == 0) {
                    require(stop == 0x4c5e && cpu.mLowerData[3] == 4 &&
                            cpu.mLowerData[5] == 0 && cpu.mLowerData[7] == port);
                } else {
                    require(stop == 0x7ffe && cpu.mLowerData[7] == 2);
                }
                cases++;
            }
        }
    }
    /* Policy dispatcher state 0708 reaches the type-14 send helper. Its adjacent
     * unhandled state 0709 is a negative control, not a real hardware state. */
    for (unsigned port = 0; port < 2; port++) {
        for (unsigned state = 8; state <= 9; state++) {
            initialize(0x5a);
            ram[0xc3c + 0x28c * port] = 0;
            cpu.mLowerData[7] = (unsigned char)port;
            cpu.mLowerData[4] = 7;
            cpu.mLowerData[5] = (unsigned char)state;
            unsigned stop = execute(0x547d, 0x4c5e, 0xffff);
            if (state == 8) {
                require(stop == 0x4c5e && cpu.mLowerData[3] == 14 &&
                        cpu.mLowerData[5] == 0 && cpu.mLowerData[7] == port);
                for (unsigned j = 0; j < 4; j++) {
                    require(!ram[0xc18 + 0x28c * port + j]);
                    require(!ram[0xc20 + 0x28c * port + j]);
                }
            } else require(stop == 0x7ffe);
            cases++;
        }
    }
    /* Zero data objects selects the control dispatcher, not the data dispatcher. */
    for (unsigned count = 0; count < 2; count++) {
        initialize(0);
        ram[0x1457] = 14;
        ram[0x1459] = (unsigned char)count;
        unsigned stop = execute(0x642b, 0x041e, 0x2373);
        require(stop == (count ? 0x2373 : 0x041e) && cpu.mLowerData[3] == 14);
        cases++;
    }
    /* The reference receiver consumes selector, length, payload. Stop at its
     * state-setter call: no timer, state setter, transmit or reset is executed. */
    for (fixture_port = 0; fixture_port < 2; fixture_port++) {
        for (unsigned value = 0; value < 4; value++) {
            initialize(0);
            select_receiver_bank();
            fifo[0] = 5; fifo[1] = 1; fifo[2] = (unsigned char)value;
            unsigned stop = execute(0x8855, 0x4a71, 0xffff);
            require(fifo_index == 3);
            if (value == 1 || value == 2) {
                require(stop == 0x4a71 && cpu.mLowerData[7] == fixture_port &&
                        cpu.mLowerData[5] == 0 && acknowledgements == 3);
                require(cpu.mLowerData[2] == (value == 1 ? 7 : 0) &&
                        cpu.mLowerData[3] == (value == 1 ? 8 : 1));
            } else require(stop == 0x7ffe && acknowledgements == 4);
            cases++;
        }
    }
    /* Selector 10 hex serializes four per-port RAM bytes in reverse order.
     * This does not identify their bit meanings or how recently they changed. */
    for (unsigned port = 0; port < 2; port++) {
        for (unsigned index = 0; index < 5; index++) {
            initialize(0);
            select_receiver_bank();
            ram[0x141b] = (unsigned char)port;
            ram[0x5c5] = 0x10;
            ram[0x5c6] = (unsigned char)index;
            for (unsigned j = 0; j < 4; j++)
                ram[0x5e4 + 0x18 * port + j] = (unsigned char)(0x12 + 0x22 * j);
            require(execute(0x8a90, 0x8b7d, 0xffff) == 0x8b7d);
            if (index < 4) require(output_count == 1 && output_byte == 0x12 + 0x22 * (3 - index));
            else require(output_count == 0);
            for (unsigned j = 0; j < 4; j++)
                require(ram[0x5e4 + 0x18 * port + j] == 0x12 + 0x22 * j);
            cases++;
        }
    }
    printf("{\"cases\":%u,\"receivedDataResetSop0ReplyType\":4,"
           "\"outboundStateHex\":\"0708\",\"outboundControlType\":14,"
           "\"referenceReceiverCommand\":5,\"referenceResetSelector\":1,"
           "\"fourByteReadCommand\":16,\"stoppedBeforeTransmit\":true,\"hardwareRequests\":0}\n", cases);
    return 0;
}
