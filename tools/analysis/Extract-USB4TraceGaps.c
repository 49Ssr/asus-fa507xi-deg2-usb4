/* Read four undecoded message GUIDs from an existing ETL, offline.
 * No trace session creation, device APIs or system changes. Output includes
 * private trace payloads and must remain private. Build with advapi32.lib.
 */
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <evntrace.h>
#include <evntcons.h>
#include <stdio.h>
#include <string.h>

static const GUID targets[]={
 {0xa3776331,0x57bf,0x31b1,{0x02,0x8e,0xc9,0xb0,0x9d,0x96,0xef,0x8f}},
 {0xcb7a5c27,0x8baa,0x3da6,{0x30,0x50,0x9d,0x75,0x64,0xb0,0x42,0x61}},
 {0x10adc54e,0xb705,0x390a,{0x5f,0x23,0x14,0x5e,0x37,0x3e,0x5c,0x16}},
 {0x2cbb8eab,0xa489,0x3cb9,{0xc1,0x0a,0x66,0x8c,0x97,0x84,0xba,0x4d}}
};
static unsigned counts[4];
static unsigned long long total;
static void WINAPI record(EVENT_RECORD *event) {
    total++;
    for(unsigned i=0;i<4;i++) if(!memcmp(&event->EventHeader.ProviderId,&targets[i],sizeof(GUID))) {
        counts[i]++;
        printf("{\"group\":%u,\"id\":%u,\"version\":%u,\"opcode\":%u,\"flags\":%u,\"timestamp100ns\":%lld,\"bytes\":%u,\"payload\":\"",i,event->EventHeader.EventDescriptor.Id,event->EventHeader.EventDescriptor.Version,event->EventHeader.EventDescriptor.Opcode,event->EventHeader.Flags,event->EventHeader.TimeStamp.QuadPart,event->UserDataLength);
        for(unsigned j=0;j<event->UserDataLength;j++) printf("%02x",((unsigned char*)event->UserData)[j]);
        puts("\"}"); return;
    }
}
int wmain(int argc,wchar_t **argv) {
    if(argc!=2) { fputs("Usage: Extract-USB4TraceGaps existing-private.etl\n",stderr); return 2; }
    EVENT_TRACE_LOGFILEW input={0};
    input.LogFileName=argv[1]; input.ProcessTraceMode=PROCESS_TRACE_MODE_EVENT_RECORD;
    input.EventRecordCallback=record;
    TRACEHANDLE handle=OpenTraceW(&input);
    if(handle==INVALID_PROCESSTRACE_HANDLE) { fprintf(stderr,"OpenTrace failed: %lu\n",GetLastError()); return 3; }
    ULONG result=ProcessTrace(&handle,1,NULL,NULL);
    ULONG close_result=CloseTrace(handle);
    fprintf(stderr,"{\"eventsScanned\":%llu,\"groups\":[%u,%u,%u,%u],\"processStatus\":%lu,\"closeStatus\":%lu}\n",total,counts[0],counts[1],counts[2],counts[3],result,close_result);
    return result || close_result ? 4 : 0;
}
