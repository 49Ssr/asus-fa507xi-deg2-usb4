#include <windows.h>
#include <acpiioct.h>
#include <stdio.h>
#include <string.h>
#include "Policy.h"

static unsigned checks;
#define CHECK(c) do { ++checks; if (!(c)) { fprintf(stderr,"Failed line %d: %s\n",__LINE__,#c); return 1; } } while (0)

static size_t Input(unsigned char *bytes, ULONG function) {
    static const unsigned char uuid[16] = {0xc2,0x98,0x83,0x6f,0xa4,0x7c,0xe4,0x11,0xad,0x36,0x63,0x10,0x42,0xb5,0x00,0x8f};
    PACPI_EVAL_INPUT_BUFFER_COMPLEX input = (void *)bytes;
    PACPI_METHOD_ARGUMENT argument;
    memset(bytes, 0, 80);
    input->Signature = ACPI_EVAL_INPUT_BUFFER_COMPLEX_SIGNATURE;
    memcpy(input->MethodName, "_DSM", 4); input->ArgumentCount = 4;
    argument = input->Argument;
    ACPI_METHOD_SET_ARGUMENT_BUFFER(argument, uuid, sizeof(uuid));
    argument = ACPI_METHOD_NEXT_ARGUMENT(argument);
    ACPI_METHOD_SET_ARGUMENT_INTEGER(argument, 0);
    argument = ACPI_METHOD_NEXT_ARGUMENT(argument);
    ACPI_METHOD_SET_ARGUMENT_INTEGER(argument, function);
    argument = ACPI_METHOD_NEXT_ARGUMENT(argument);
    argument->Type = ACPI_METHOD_ARGUMENT_PACKAGE_EX; argument->DataLength = 0;
    input->Size = (ULONG)((unsigned char *)ACPI_METHOD_NEXT_ARGUMENT(argument) - (unsigned char *)input->Argument);
    return 16u + input->Size;
}

int main(void) {
    unsigned char input[80], saved[80], output[64], original[64];
    PACPI_EVAL_OUTPUT_BUFFER reply = (void *)output;
    size_t size = Input(input, 0), i;
    uint32_t random = 0x12875289;
    CHECK(size == 60);
    CHECK(((PACPI_EVAL_INPUT_BUFFER_COMPLEX)input)->Size == 44);
    CHECK(RpPolicyFunction(input, size) == 0);
    CHECK(RpPolicyFunction(input, sizeof(input)) == 0);
    size = Input(input, 4); CHECK(RpPolicyFunction(input, size) == 4);
    for (i=0; i < 32; ++i) { Input(input, (ULONG)i); CHECK(RpPolicyFunction(input,size) == (i==0||i==4 ? i:RP_NO_FUNCTION)); }
    size=Input(input,0); memcpy(saved,input,sizeof(input));
    for (i=0;i<size;++i) CHECK(RpPolicyFunction(input,i)==RP_NO_FUNCTION);
    CHECK(RpPolicyFunction(NULL,80)==RP_NO_FUNCTION);
    for (i=0;i<16;++i) { memcpy(input,saved,sizeof(input));input[20+i]^=1;CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION); }
    memcpy(input,saved,sizeof(input));input[4]='X'; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[0]^=1; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[8]=255; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[8]=59; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[8]=60; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[12]=3; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[18]=255;input[19]=255; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[40]=1; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[52]=3; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);
    memcpy(input,saved,sizeof(input));input[54]=1; CHECK(RpPolicyFunction(input,size)==RP_NO_FUNCTION);

    memset(output,0xa5,sizeof(output));
    reply->Signature=ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE;reply->Length=20;reply->Count=1;
    reply->Argument[0].Type=ACPI_METHOD_ARGUMENT_BUFFER;reply->Argument[0].DataLength=1;reply->Argument[0].Data[0]=0x0f;
    memcpy(original,output,sizeof(output));
    CHECK(RpPatchSupportedMask(output,sizeof(output),20));
    CHECK(output[16]==0x1f);
    for(i=0;i<sizeof(output);++i) CHECK(i==16 || output[i]==original[i]);
    CHECK(!RpPatchSupportedMask(output,sizeof(output),20));
    for(i=0;i<20;++i) { memcpy(output,original,sizeof(output)); CHECK(!RpPatchSupportedMask(output,sizeof(output),i));CHECK(memcmp(output,original,sizeof(output))==0); }
    memcpy(output,original,sizeof(output));CHECK(!RpPatchSupportedMask(output,19,20));
    for(i=21;i<=64;++i) { memcpy(output,original,sizeof(output)); CHECK(!RpPatchSupportedMask(output,64,i)); CHECK(memcmp(output,original,sizeof(output))==0); }
    CHECK(!RpPatchSupportedMask(NULL,64,20));
    for(i=0;i<256;++i) { memcpy(output,original,sizeof(output));output[16]=(unsigned char)i; CHECK(RpPatchSupportedMask(output,64,20)==(i==15)); }
    memcpy(output,original,sizeof(output));reply->Count=2;CHECK(!RpPatchSupportedMask(output,64,20));
    memcpy(output,original,sizeof(output));reply->Length=21;CHECK(!RpPatchSupportedMask(output,64,20));
    memcpy(output,original,sizeof(output));reply->Argument[0].Type=ACPI_METHOD_ARGUMENT_INTEGER;CHECK(!RpPatchSupportedMask(output,64,20));
    memcpy(output,original,sizeof(output));reply->Argument[0].DataLength=2;CHECK(!RpPatchSupportedMask(output,64,20));

    memset(output,0xa5,sizeof(output));CHECK(RpWriteDisableReply(output,sizeof(output)));
    CHECK(reply->Signature==ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE && reply->Length==20 && reply->Count==1);
    CHECK(reply->Argument[0].Type==ACPI_METHOD_ARGUMENT_INTEGER && reply->Argument[0].DataLength==4 && reply->Argument[0].Argument==1);
    for(i=20;i<sizeof(output);++i) CHECK(output[i]==0xa5);
    memset(output,0xa5,sizeof(output));memcpy(original,output,sizeof(output));
    CHECK(!RpWriteDisableReply(output,19));CHECK(memcmp(output,original,sizeof(output))==0);
    CHECK(!RpWriteDisableReply(NULL,64));
    for(i=0;i<4000;++i) {
        size_t j;
        for(j=0;j<sizeof(input);++j) {random=random*1664525u+1013904223u;input[j]=(unsigned char)(random>>24);}
        CHECK(RpPolicyFunction(input,sizeof(input))==RP_NO_FUNCTION);
    }
    printf("Policy core passed %u assertions, including truncation/mutation and 4000 malformed frames. No driver loaded.\n",checks);
    return 0;
}
