#include "Policy.h"

static uint16_t Read16(const uint8_t *p) {
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}
static uint32_t Read32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static void Write32(uint8_t *p, uint32_t value) {
    unsigned i;
    for (i = 0; i < 4; ++i) p[i] = (uint8_t)(value >> (i * 8));
}

uint32_t RpPolicyFunction(const void *buffer, size_t length) {
    static const uint8_t uuid[16] = {
        0xc2,0x98,0x83,0x6f,0xa4,0x7c,0xe4,0x11,
        0xad,0x36,0x63,0x10,0x42,0xb5,0x00,0x8f
    };
    const uint8_t *p = (const uint8_t *)buffer;
    size_t offset = 16, declared;
    uint32_t function = RP_NO_FUNCTION;
    unsigned index, byte;
    if (!p || length < 16 || Read32(p) != RP_INPUT_SIGNATURE) return RP_NO_FUNCTION;
    if (p[4] != '_' || p[5] != 'D' || p[6] != 'S' || p[7] != 'M') return RP_NO_FUNCTION;
    /* Pinned Microsoft client: Size counts Argument bytes, not the 16-byte header.
       Its four-argument request is 60 bytes with Size == 44. */
    declared = Read32(p + 8);
    if (declared > length - 16 || Read32(p + 12) != 4) return RP_NO_FUNCTION;
    declared += 16;
    for (index = 0; index < 4; ++index) {
        uint16_t type, size;
        size_t encoded;
        if (offset > declared || declared - offset < 8) return RP_NO_FUNCTION;
        type = Read16(p + offset); size = Read16(p + offset + 2);
        encoded = 4u + (size < 4u ? 4u : (size_t)size);
        if (encoded > declared - offset) return RP_NO_FUNCTION;
        if (index == 0) {
            if (type != 2 || size != 16) return RP_NO_FUNCTION;
            for (byte = 0; byte < 16; ++byte)
                if (p[offset + 4 + byte] != uuid[byte]) return RP_NO_FUNCTION;
        } else if (index == 1) {
            if (type != 0 || size != 4 || Read32(p + offset + 4) != 0) return RP_NO_FUNCTION;
        } else if (index == 2) {
            if (type != 0 || size != 4) return RP_NO_FUNCTION;
            function = Read32(p + offset + 4);
            if (function != 0 && function != 4) return RP_NO_FUNCTION;
        } else if (type != 4 || size != 0) return RP_NO_FUNCTION;
        offset += encoded;
    }
    return offset == declared ? function : RP_NO_FUNCTION;
}

int RpPatchSupportedMask(void *buffer, size_t capacity, size_t returned) {
    uint8_t *p = (uint8_t *)buffer;
    if (!p || returned != RP_OUTPUT_BYTES || returned > capacity) return 0;
    if (Read32(p) != RP_OUTPUT_SIGNATURE || Read32(p + 4) != RP_OUTPUT_BYTES ||
        Read32(p + 8) != 1 || Read16(p + 12) != 2 || Read16(p + 14) != 1 || p[16] != 0x0f) return 0;
    p[16] = 0x1f;
    return 1;
}

int RpWriteDisableReply(void *buffer, size_t capacity) {
    uint8_t *p = (uint8_t *)buffer;
    size_t i;
    if (!p || capacity < RP_OUTPUT_BYTES) return 0;
    for (i = 0; i < RP_OUTPUT_BYTES; ++i) p[i] = 0;
    Write32(p, RP_OUTPUT_SIGNATURE); Write32(p + 4, RP_OUTPUT_BYTES);
    Write32(p + 8, 1); p[14] = 4; Write32(p + 16, 1);
    return 1;
}
