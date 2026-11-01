/* User-mode DDI doubles for the actual Driver.c callbacks, never kernel code. */
#pragma once
#include <windows.h>
#include <acpiioct.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <wchar.h>
#ifndef NT_SUCCESS
#define NT_SUCCESS(s) (((NTSTATUS)(s)) >= 0)
#endif
#define STATUS_SUCCESS ((NTSTATUS)0)
#define STATUS_BUFFER_TOO_SMALL ((NTSTATUS)0xc0000023L)
#define STATUS_OBJECT_TYPE_MISMATCH ((NTSTATUS)0xc0000024L)
#define STATUS_UNSUCCESSFUL ((NTSTATUS)0xc0000001L)
#define STATUS_CANCELLED ((NTSTATUS)0xc0000120L)
#define RTL_REGISTRY_ABSOLUTE 0
#define RTL_QUERY_REGISTRY_REQUIRED 4
#define RTL_QUERY_REGISTRY_NOEXPAND 0x10
#define RTL_QUERY_REGISTRY_DIRECT 0x20
#define RTL_QUERY_REGISTRY_TYPECHECK 0x100
#define RTL_QUERY_REGISTRY_TYPECHECK_SHIFT 24
#define RTL_CONSTANT_STRING(s) {sizeof(s)-sizeof(WCHAR),sizeof(s),(PWSTR)(s)}
typedef struct {void *QueryRoutine;ULONG Flags;PWSTR Name;void *EntryContext;ULONG DefaultType;void *DefaultData;ULONG DefaultLength;} RTL_QUERY_REGISTRY_TABLE;
typedef LONG NTSTATUS;
typedef struct {USHORT Length,MaximumLength;PWSTR Buffer;} UNICODE_STRING,*PUNICODE_STRING;
typedef const UNICODE_STRING *PCUNICODE_STRING;
typedef struct {NTSTATUS Status;ULONG_PTR Information;} IO_STATUS_BLOCK;
typedef struct {BOOLEAN Filter;BOOLEAN HardwareMatches;} HARNESS_INIT, *PWDFDEVICE_INIT;
typedef struct {__declspec(align(8)) unsigned char Context[16];} HARNESS_DEVICE, *WDFDEVICE;
typedef WDFDEVICE WDFQUEUE;
typedef void *WDFDRIVER;
typedef void *WDFIOTARGET;
typedef void *WDFCONTEXT;
typedef void *PDRIVER_OBJECT;
enum {KernelMode,UserMode,WdfFalse=0,WdfIoQueueDispatchParallel=2,DevicePropertyHardwareID=1};
typedef struct {IO_STATUS_BLOCK IoStatus;} WDF_REQUEST_COMPLETION_PARAMS,*PWDF_REQUEST_COMPLETION_PARAMS;
typedef struct HARNESS_REQUEST *WDFREQUEST;
typedef VOID EVT_WDF_REQUEST_COMPLETION_ROUTINE(WDFREQUEST,WDFIOTARGET,PWDF_REQUEST_COMPLETION_PARAMS,WDFCONTEXT);
typedef VOID EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL(WDFQUEUE,WDFREQUEST,size_t,size_t,ULONG);
typedef VOID EVT_WDF_IO_QUEUE_IO_INTERNAL_DEVICE_CONTROL(WDFQUEUE,WDFREQUEST,size_t,size_t,ULONG);
typedef NTSTATUS EVT_WDF_DRIVER_DEVICE_ADD(WDFDRIVER,PWDFDEVICE_INIT);
typedef VOID EVT_WDF_DRIVER_UNLOAD(WDFDRIVER);
typedef NTSTATUS DRIVER_INITIALIZE(PDRIVER_OBJECT,PUNICODE_STRING);
typedef struct HARNESS_REQUEST {
    void *Input,*Output;size_t InputLength,OutputLength;
    int Mode,Formatted,Sent,SendSucceeds,Completed,Forget;
    NTSTATUS Status;ULONG_PTR Information;
    EVT_WDF_REQUEST_COMPLETION_ROUTINE *Completion;void *CompletionContext;
} HARNESS_REQUEST;
typedef struct {EVT_WDF_DRIVER_DEVICE_ADD *Add;EVT_WDF_DRIVER_UNLOAD *EvtDriverUnload;} WDF_DRIVER_CONFIG;
typedef struct {size_t ContextSize;} WDF_OBJECT_ATTRIBUTES;
typedef struct {int PowerManaged,Dispatch;EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL *EvtIoDeviceControl,*EvtIoInternalDeviceControl;} WDF_IO_QUEUE_CONFIG;
typedef struct {int Forget;} WDF_REQUEST_SEND_OPTIONS;
#define WDF_NO_OBJECT_ATTRIBUTES NULL
#define WDF_NO_HANDLE NULL
#define WDF_NO_SEND_OPTIONS NULL
#define WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET 1
#define WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(t,n) static t *n(WDFDEVICE d){return (t *)d->Context;}
#define WDF_DRIVER_CONFIG_INIT(p,f) (memset((p),0,sizeof(*(p))),(p)->Add=(f))
#define WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(p,t) ((p)->ContextSize=sizeof(t))
#define WDF_IO_QUEUE_CONFIG_INIT_DEFAULT_QUEUE(p,d) (memset((p),0,sizeof(*(p))),(p)->Dispatch=(d))
#define WDF_REQUEST_SEND_OPTIONS_INIT(p,f) ((p)->Forget=(f))
#define TRACELOGGING_DEFINE_PROVIDER(n,...) static int n
#define TraceLoggingRegister(p) ((void)(p))
#define TraceLoggingUnregister(p) ((void)(p))
#define TraceLoggingWrite(...) ((void)0)
extern WCHAR HarnessMaker[128],HarnessModel[128];
extern int HarnessWrongRegistryType,HarnessUnsafeRegistryRead,HarnessCreated;
extern NTSTATUS HarnessCreateStatus,HarnessQueueStatus;
extern HARNESS_DEVICE HarnessDevice;
extern WDF_IO_QUEUE_CONFIG HarnessQueue;
NTSTATUS RtlQueryRegistryValues(ULONG,PCWSTR,RTL_QUERY_REGISTRY_TABLE *,void *,void *);
WCHAR RtlUpcaseUnicodeChar(WCHAR);
BOOLEAN RtlEqualUnicodeString(PCUNICODE_STRING,PCUNICODE_STRING,BOOLEAN);
NTSTATUS IoGetDeviceProperty(void *,int,ULONG,void *,ULONG *);
void *WdfFdoInitWdmGetPhysicalDevice(PWDFDEVICE_INIT);
void WdfFdoInitSetFilter(PWDFDEVICE_INIT);
NTSTATUS WdfDriverCreate(PDRIVER_OBJECT,PUNICODE_STRING,void *,WDF_DRIVER_CONFIG *,void *);
NTSTATUS WdfDeviceCreate(PWDFDEVICE_INIT *,WDF_OBJECT_ATTRIBUTES *,WDFDEVICE *);
NTSTATUS WdfIoQueueCreate(WDFDEVICE,WDF_IO_QUEUE_CONFIG *,void *,void *);
WDFDEVICE WdfIoQueueGetDevice(WDFQUEUE);
WDFIOTARGET WdfDeviceGetIoTarget(WDFDEVICE);
void WdfRequestFormatRequestUsingCurrentType(WDFREQUEST);
void WdfRequestSetCompletionRoutine(WDFREQUEST,EVT_WDF_REQUEST_COMPLETION_ROUTINE *,void *);
BOOLEAN WdfRequestSend(WDFREQUEST,WDFIOTARGET,WDF_REQUEST_SEND_OPTIONS *);
NTSTATUS WdfRequestGetStatus(WDFREQUEST);
void WdfRequestComplete(WDFREQUEST,NTSTATUS);
void WdfRequestCompleteWithInformation(WDFREQUEST,NTSTATUS,ULONG_PTR);
int WdfRequestGetRequestorMode(WDFREQUEST);
NTSTATUS WdfRequestRetrieveInputBuffer(WDFREQUEST,size_t,void **,size_t *);
NTSTATUS WdfRequestRetrieveOutputBuffer(WDFREQUEST,size_t,void **,size_t *);
