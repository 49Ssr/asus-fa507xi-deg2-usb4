#pragma once
#include <stddef.h>
#include <stdint.h>

#define RP_INPUT_SIGNATURE 0x43696541u
#define RP_OUTPUT_SIGNATURE 0x426f6541u
#define RP_OUTPUT_BYTES 20u
#define RP_NO_FUNCTION 0xffffffffu

/* These routines only parse caller-owned byte buffers. No hardware access. */
uint32_t RpPolicyFunction(const void *buffer, size_t length);
int RpPatchSupportedMask(void *buffer, size_t capacity, size_t returned);
int RpWriteDisableReply(void *buffer, size_t capacity);
