#include "DriverShim.h"
#include <stdio.h>
#include <wctype.h>
WCHAR HarnessMaker[128],HarnessModel[128];
int HarnessWrongRegistryType,HarnessUnsafeRegistryRead,HarnessCreated;
NTSTATUS HarnessCreateStatus,HarnessQueueStatus;
HARNESS_DEVICE HarnessDevice;
WDF_IO_QUEUE_CONFIG HarnessQueue;
static unsigned checks;
#define CHECK(c) do{++checks;if(!(c)){fprintf(stderr,"Driver callback check failed at %d: %s\n",__LINE__,#c);return 1;}}while(0)
extern EVT_WDF_DRIVER_DEVICE_ADD RoleDeviceAdd;
extern EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL RoleIoctl;
extern EVT_WDF_IO_QUEUE_IO_INTERNAL_DEVICE_CONTROL RoleInternalIoctl;

NTSTATUS RtlQueryRegistryValues(ULONG base,PCWSTR path,RTL_QUERY_REGISTRY_TABLE *q,void *ctx,void *env){
    unsigned i;UNREFERENCED_PARAMETER(base);UNREFERENCED_PARAMETER(path);UNREFERENCED_PARAMETER(ctx);UNREFERENCED_PARAMETER(env);
    for(i=0;i<2;++i){
        UNICODE_STRING *out=q[i].EntryContext;const WCHAR *value=i?HarnessMaker:HarnessModel;
        size_t bytes=wcslen(value)*sizeof(WCHAR);
        if(!(q[i].Flags&RTL_QUERY_REGISTRY_NOEXPAND))HarnessUnsafeRegistryRead=1;
        if(HarnessWrongRegistryType){
            if((q[i].Flags&RTL_QUERY_REGISTRY_TYPECHECK) && (q[i].DefaultType>>24)==REG_SZ)return STATUS_OBJECT_TYPE_MISMATCH;
            HarnessUnsafeRegistryRead=1;
        }
        if(bytes+sizeof(WCHAR)>out->MaximumLength)return STATUS_BUFFER_TOO_SMALL;
        memcpy(out->Buffer,value,bytes+sizeof(WCHAR));out->Length=(USHORT)bytes;
    }
    return STATUS_SUCCESS;
}
WCHAR RtlUpcaseUnicodeChar(WCHAR c){return (WCHAR)towupper(c);}
BOOLEAN RtlEqualUnicodeString(PCUNICODE_STRING a,PCUNICODE_STRING b,BOOLEAN ignore){
    USHORT i;if(a->Length!=b->Length)return FALSE;
    for(i=0;i<a->Length/sizeof(WCHAR);++i)if((ignore?towupper(a->Buffer[i]):a->Buffer[i])!=(ignore?towupper(b->Buffer[i]):b->Buffer[i]))return FALSE;
    return TRUE;
}
NTSTATUS IoGetDeviceProperty(void *physical,int property,ULONG size,void *data,ULONG *needed){
    static const WCHAR yes[]=L"ACPI\\USBC000\0",no[]=L"ACPI\\OTHER\0";
    HARNESS_INIT *init=physical;UNREFERENCED_PARAMETER(property);
    *needed=init->HardwareMatches?sizeof(yes):sizeof(no);
    if(size<*needed)return STATUS_BUFFER_TOO_SMALL;
    memcpy(data,init->HardwareMatches?yes:no,*needed);return STATUS_SUCCESS;
}
void *WdfFdoInitWdmGetPhysicalDevice(PWDFDEVICE_INIT i){return i;}
void WdfFdoInitSetFilter(PWDFDEVICE_INIT i){i->Filter=TRUE;}
NTSTATUS WdfDriverCreate(PDRIVER_OBJECT o,PUNICODE_STRING p,void *a,WDF_DRIVER_CONFIG *c,void *h){UNREFERENCED_PARAMETER(o);UNREFERENCED_PARAMETER(p);UNREFERENCED_PARAMETER(a);UNREFERENCED_PARAMETER(c);UNREFERENCED_PARAMETER(h);return STATUS_SUCCESS;}
NTSTATUS WdfDeviceCreate(PWDFDEVICE_INIT *init,WDF_OBJECT_ATTRIBUTES *a,WDFDEVICE *device){
    if(!(*init)->Filter || a->ContextSize>sizeof(HarnessDevice.Context))return STATUS_UNSUCCESSFUL;
    if(!NT_SUCCESS(HarnessCreateStatus))return HarnessCreateStatus;
    memset(&HarnessDevice,0,sizeof(HarnessDevice));HarnessCreated=1;*device=&HarnessDevice;return STATUS_SUCCESS;
}
NTSTATUS WdfIoQueueCreate(WDFDEVICE d,WDF_IO_QUEUE_CONFIG *q,void *a,void *h){UNREFERENCED_PARAMETER(d);UNREFERENCED_PARAMETER(a);UNREFERENCED_PARAMETER(h);HarnessQueue=*q;return HarnessQueueStatus;}
WDFDEVICE WdfIoQueueGetDevice(WDFQUEUE q){return q;}
WDFIOTARGET WdfDeviceGetIoTarget(WDFDEVICE d){return d;}
void WdfRequestFormatRequestUsingCurrentType(WDFREQUEST r){r->Formatted=1;}
void WdfRequestSetCompletionRoutine(WDFREQUEST r,EVT_WDF_REQUEST_COMPLETION_ROUTINE *c,void *ctx){r->Completion=c;r->CompletionContext=ctx;}
BOOLEAN WdfRequestSend(WDFREQUEST r,WDFIOTARGET t,WDF_REQUEST_SEND_OPTIONS *o){UNREFERENCED_PARAMETER(t);r->Sent=1;r->Forget=o?o->Forget:0;return (BOOLEAN)r->SendSucceeds;}
NTSTATUS WdfRequestGetStatus(WDFREQUEST r){return r->Status;}
void WdfRequestComplete(WDFREQUEST r,NTSTATUS s){++r->Completed;r->Status=s;}
void WdfRequestCompleteWithInformation(WDFREQUEST r,NTSTATUS s,ULONG_PTR n){WdfRequestComplete(r,s);r->Information=n;}
int WdfRequestGetRequestorMode(WDFREQUEST r){return r->Mode;}
NTSTATUS WdfRequestRetrieveInputBuffer(WDFREQUEST r,size_t min,void **p,size_t *n){if(!r->Input||r->InputLength<min)return STATUS_BUFFER_TOO_SMALL;*p=r->Input;*n=r->InputLength;return STATUS_SUCCESS;}
NTSTATUS WdfRequestRetrieveOutputBuffer(WDFREQUEST r,size_t min,void **p,size_t *n){if(!r->Output||r->OutputLength<min)return STATUS_BUFFER_TOO_SMALL;*p=r->Output;*n=r->OutputLength;return STATUS_SUCCESS;}
static void Reset(void){wcscpy_s(HarnessMaker,128,L"ASUSTeK COMPUTER INC.");wcscpy_s(HarnessModel,128,L"ASUS TUF Gaming A15 FA507XI_FA507XI");HarnessCreated=HarnessWrongRegistryType=HarnessUnsafeRegistryRead=0;HarnessCreateStatus=HarnessQueueStatus=STATUS_SUCCESS;memset(&HarnessQueue,0,sizeof(HarnessQueue));}
static void Input(unsigned char *p,ULONG function){
    static const unsigned char uuid[16]={0xc2,0x98,0x83,0x6f,0xa4,0x7c,0xe4,0x11,0xad,0x36,0x63,0x10,0x42,0xb5,0x00,0x8f};
    PACPI_EVAL_INPUT_BUFFER_COMPLEX b=(void *)p;PACPI_METHOD_ARGUMENT a;
    memset(p,0,64);b->Signature=ACPI_EVAL_INPUT_BUFFER_COMPLEX_SIGNATURE;memcpy(b->MethodName,"_DSM",4);b->Size=44;b->ArgumentCount=4;
    a=b->Argument;ACPI_METHOD_SET_ARGUMENT_BUFFER(a,uuid,16);a=ACPI_METHOD_NEXT_ARGUMENT(a);ACPI_METHOD_SET_ARGUMENT_INTEGER(a,0);
    a=ACPI_METHOD_NEXT_ARGUMENT(a);ACPI_METHOD_SET_ARGUMENT_INTEGER(a,function);a=ACPI_METHOD_NEXT_ARGUMENT(a);a->Type=ACPI_METHOD_ARGUMENT_PACKAGE_EX;a->DataLength=0;
}
static HARNESS_REQUEST Request(void *input,void *output){HARNESS_REQUEST r={0};r.Input=input;r.InputLength=60;r.Output=output;r.OutputLength=64;r.SendSucceeds=1;return r;}
static void Reply(void *buffer,unsigned char mask){PACPI_EVAL_OUTPUT_BUFFER p=buffer;memset(buffer,0,20);p->Signature=ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE;p->Length=20;p->Count=1;p->Argument[0].Type=ACPI_METHOD_ARGUMENT_BUFFER;p->Argument[0].DataLength=1;p->Argument[0].Data[0]=mask;}
static void Complete(HARNESS_REQUEST *r,NTSTATUS status,size_t info){WDF_REQUEST_COMPLETION_PARAMS p;memset(&p,0,sizeof(p));p.IoStatus.Status=status;p.IoStatus.Information=info;r->Completion(r,NULL,&p,r->CompletionContext);}
int main(void){
    HARNESS_INIT init;HARNESS_REQUEST r;unsigned char input[64],output[64];unsigned f;
    Reset();wcscpy_s(HarnessMaker,128,L"Other");init.Filter=FALSE;init.HardwareMatches=TRUE;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);CHECK(init.Filter&&!HarnessCreated);
    Reset();wcscpy_s(HarnessModel,128,L"FA507XII");init.Filter=FALSE;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);CHECK(init.Filter&&!HarnessCreated);
    Reset();HarnessWrongRegistryType=1;init.Filter=FALSE;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);CHECK(init.Filter&&!HarnessCreated&&!HarnessUnsafeRegistryRead);
    Reset();init.Filter=FALSE;init.HardwareMatches=FALSE;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);CHECK(init.Filter&&!HarnessCreated);
    Reset();init.HardwareMatches=TRUE;HarnessCreateStatus=STATUS_UNSUCCESSFUL;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_UNSUCCESSFUL);CHECK(!HarnessCreated);
    Reset();HarnessQueueStatus=STATUS_UNSUCCESSFUL;
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_UNSUCCESSFUL);
    Reset();CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);CHECK(HarnessCreated&&!HarnessUnsafeRegistryRead);
    CHECK(HarnessQueue.PowerManaged==WdfFalse&&HarnessQueue.Dispatch==WdfIoQueueDispatchParallel);
    CHECK(HarnessQueue.EvtIoDeviceControl==RoleIoctl&&HarnessQueue.EvtIoInternalDeviceControl==RoleInternalIoctl);
    for(f=1;f<=3;++f){Input(input,f);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&r.Forget&&r.Formatted&&!r.Completion&&!r.Completed);}
    Input(input,0);r=Request(input,output);r.Mode=UserMode;RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&r.Forget&&!r.Completion);
    r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD_EX);CHECK(r.Sent&&r.Forget&&!r.Completion);
    r=Request(input,output);r.SendSucceeds=0;r.Status=STATUS_CANCELLED;RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_ENUM_CHILDREN);CHECK(r.Completed==1&&r.Status==STATUS_CANCELLED);
    Input(input,4);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&!r.Completed);
    Input(input,0);r=Request(input,output);HarnessQueue.EvtIoInternalDeviceControl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&!r.Forget&&r.Completion&&!r.Completed);
    Reply(output,15);Complete(&r,STATUS_SUCCESS,20);CHECK(r.Completed==1&&r.Information==20&&output[16]==31);
    Input(input,4);r=Request(input,output);memset(output,0xa5,64);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);
    CHECK(!r.Sent&&r.Completed==1&&r.Status==STATUS_SUCCESS&&r.Information==20);CHECK(((PACPI_EVAL_OUTPUT_BUFFER)output)->Argument[0].Argument==1);CHECK(output[20]==0xa5);
    r=Request(input,output);r.OutputLength=19;RoleIoctl(&HarnessDevice,&r,19,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Completed==1&&r.Status==STATUS_BUFFER_TOO_SMALL&&!r.Sent);
    Input(input,0);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);Reply(output,15);Complete(&r,STATUS_CANCELLED,0);CHECK(r.Completed==1&&r.Status==STATUS_CANCELLED&&output[16]==15);
    Input(input,4);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&!r.Completed);
    Input(input,0);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);Reply(output,31);Complete(&r,STATUS_SUCCESS,20);CHECK(output[16]==31&&r.Completed==1);
    Input(input,4);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&!r.Completed);
    Input(input,0);r=Request(input,output);r.SendSucceeds=0;r.Status=STATUS_UNSUCCESSFUL;RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Completed==1&&r.Status==STATUS_UNSUCCESSFUL);
    /* METHOD_BUFFERED input/output alias after the lower driver overwrites it. */
    Input(input,0);r=Request(input,input);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);Reply(input,15);Complete(&r,STATUS_SUCCESS,20);CHECK(input[16]==31&&r.Completed==1);
    /* New filter object starts disarmed: no stale state across object lifetime. */
    CHECK(RoleDeviceAdd(NULL,&init)==STATUS_SUCCESS);Input(input,4);r=Request(input,output);RoleIoctl(&HarnessDevice,&r,64,60,IOCTL_ACPI_EVAL_METHOD);CHECK(r.Sent&&!r.Completed);
    printf("Actual Driver.c callbacks passed %u assertions with WDF/registry/transport doubles. No kernel driver loaded.\n",checks);
    return 0;
}
