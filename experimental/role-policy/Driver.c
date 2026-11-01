#include <ntddk.h>
#pragma warning(push)
#pragma warning(disable:4324) /* KMDF 1.15 public headers have intentional padding. */
#include <wdf.h>
#pragma warning(pop)
#include <acpiioct.h>
#include <TraceLoggingProvider.h>
#include "Policy.h"

/* A device lower filter; no firmware commands or arbitrary-memory access. */
TRACELOGGING_DEFINE_PROVIDER(g_Trace, "Usb4RolePolicyExperiment",
    (0x5f231789,0xf629,0x48d7,0x9d,0xaf,0xd8,0xe4,0x8b,0xdb,0x99,0x7f));

C_ASSERT(ACPI_EVAL_INPUT_BUFFER_COMPLEX_SIGNATURE == RP_INPUT_SIGNATURE);
C_ASSERT(ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE == RP_OUTPUT_SIGNATURE);
C_ASSERT(FIELD_OFFSET(ACPI_EVAL_INPUT_BUFFER_COMPLEX, Argument) == 16);
C_ASSERT(FIELD_OFFSET(ACPI_EVAL_OUTPUT_BUFFER, Argument) == 12);
C_ASSERT(ACPI_METHOD_ARGUMENT_INTEGER == 0 && ACPI_METHOD_ARGUMENT_BUFFER == 2);
C_ASSERT(ACPI_METHOD_ARGUMENT_PACKAGE_EX == 4);
C_ASSERT(sizeof(ACPI_EVAL_OUTPUT_BUFFER) == RP_OUTPUT_BYTES);

typedef struct { volatile LONG Armed; } DEVICE_CONTEXT;
WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(DEVICE_CONTEXT, DeviceContext);
DRIVER_INITIALIZE DriverEntry;
EVT_WDF_DRIVER_DEVICE_ADD RoleDeviceAdd;
EVT_WDF_DRIVER_UNLOAD RoleUnload;
EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL RoleIoctl;
EVT_WDF_REQUEST_COMPLETION_ROUTINE MaskCompleted;

static BOOLEAN IsAlphaNumeric(WCHAR c) {
    c = RtlUpcaseUnicodeChar(c);
    return (c >= L'A' && c <= L'Z') || (c >= L'0' && c <= L'9');
}
static BOOLEAN Contains(_In_ PCUNICODE_STRING value, _In_ PCWSTR token, BOOLEAN boundary) {
    USHORT i, j, count = value->Length / sizeof(WCHAR);
    for (i = 0; i < count; ++i) {
        for (j = 0; token[j] && i + j < count; ++j)
            if (RtlUpcaseUnicodeChar(value->Buffer[i + j]) != RtlUpcaseUnicodeChar(token[j])) break;
        if (!token[j] && (!boundary ||
            ((i == 0 || !IsAlphaNumeric(value->Buffer[i - 1])) &&
             (i + j == count || !IsAlphaNumeric(value->Buffer[i + j]))))) return TRUE;
    }
    return FALSE;
}

static BOOLEAN IsAsusSystem(void) {
    WCHAR modelBuffer[128] = {0}, makerBuffer[128] = {0};
    UNICODE_STRING model = {0, sizeof(modelBuffer), modelBuffer};
    UNICODE_STRING maker = {0, sizeof(makerBuffer), makerBuffer};
    RTL_QUERY_REGISTRY_TABLE query[3] = {0};
    NTSTATUS status;
    query[0].Flags = RTL_QUERY_REGISTRY_DIRECT | RTL_QUERY_REGISTRY_REQUIRED;
    query[0].Name = L"SystemProductName"; query[0].EntryContext = &model;
    query[1].Flags = RTL_QUERY_REGISTRY_DIRECT | RTL_QUERY_REGISTRY_REQUIRED;
    query[1].Name = L"SystemManufacturer"; query[1].EntryContext = &maker;
    status = RtlQueryRegistryValues(RTL_REGISTRY_ABSOLUTE,
        L"\\Registry\\Machine\\HARDWARE\\DESCRIPTION\\System\\BIOS", query, NULL, NULL);
    return NT_SUCCESS(status) && Contains(&maker, L"ASUS", FALSE) && Contains(&model, L"FA507XI", TRUE);
}

static BOOLEAN IsUcsiDevice(_In_ PWDFDEVICE_INIT init) {
    WCHAR ids[256] = {0}; ULONG needed = 0, offset = 0;
    UNICODE_STRING expected = RTL_CONSTANT_STRING(L"ACPI\\USBC000");
    NTSTATUS status = IoGetDeviceProperty(WdfFdoInitWdmGetPhysicalDevice(init),
        DevicePropertyHardwareID, sizeof(ids), ids, &needed);
    if (!NT_SUCCESS(status) || needed > sizeof(ids) || needed % sizeof(WCHAR)) return FALSE;
    while (offset < needed / sizeof(WCHAR) && ids[offset]) {
        ULONG end = offset;
        UNICODE_STRING current;
        while (end < needed / sizeof(WCHAR) && ids[end]) ++end;
        if (end == needed / sizeof(WCHAR)) return FALSE;
        current.Buffer = ids + offset;
        current.Length = (USHORT)((end - offset) * sizeof(WCHAR));
        current.MaximumLength = current.Length;
        if (RtlEqualUnicodeString(&current, &expected, TRUE)) return TRUE;
        offset = end + 1;
    }
    return FALSE;
}

NTSTATUS DriverEntry(PDRIVER_OBJECT object, PUNICODE_STRING path) {
    WDF_DRIVER_CONFIG config;
    NTSTATUS status;
    TraceLoggingRegister(g_Trace);
    WDF_DRIVER_CONFIG_INIT(&config, RoleDeviceAdd);
    config.EvtDriverUnload = RoleUnload;
    status = WdfDriverCreate(object, path, WDF_NO_OBJECT_ATTRIBUTES, &config, WDF_NO_HANDLE);
    if (!NT_SUCCESS(status)) TraceLoggingUnregister(g_Trace);
    return status;
}

VOID RoleUnload(WDFDRIVER driver) {
    UNREFERENCED_PARAMETER(driver);
    TraceLoggingUnregister(g_Trace);
}

NTSTATUS RoleDeviceAdd(WDFDRIVER driver, PWDFDEVICE_INIT init) {
    WDFDEVICE device;
    WDF_OBJECT_ATTRIBUTES attributes;
    WDF_IO_QUEUE_CONFIG queue;
    NTSTATUS status;
    UNREFERENCED_PARAMETER(driver);
    if (!IsAsusSystem() || !IsUcsiDevice(init)) return STATUS_SUCCESS;
    WdfFdoInitSetFilter(init);
    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&attributes, DEVICE_CONTEXT);
    status = WdfDeviceCreate(&init, &attributes, &device);
    if (!NT_SUCCESS(status)) return status;
    WDF_IO_QUEUE_CONFIG_INIT_DEFAULT_QUEUE(&queue, WdfIoQueueDispatchParallel);
    queue.PowerManaged = WdfFalse;
    queue.EvtIoDeviceControl = RoleIoctl;
    queue.EvtIoInternalDeviceControl = RoleIoctl;
    return WdfIoQueueCreate(device, &queue, WDF_NO_OBJECT_ATTRIBUTES, WDF_NO_HANDLE);
}

static VOID Forward(WDFREQUEST request, WDFDEVICE device, BOOLEAN completion) {
    WDF_REQUEST_SEND_OPTIONS options;
    WdfRequestFormatRequestUsingCurrentType(request);
    if (completion) {
        WdfRequestSetCompletionRoutine(request, MaskCompleted, device);
        if (!WdfRequestSend(request, WdfDeviceGetIoTarget(device), WDF_NO_SEND_OPTIONS))
            WdfRequestComplete(request, WdfRequestGetStatus(request));
    } else {
        WDF_REQUEST_SEND_OPTIONS_INIT(&options, WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET);
        if (!WdfRequestSend(request, WdfDeviceGetIoTarget(device), &options))
            WdfRequestComplete(request, WdfRequestGetStatus(request));
    }
}

VOID RoleIoctl(WDFQUEUE queue, WDFREQUEST request, size_t outputLength,
               size_t inputLength, ULONG code) {
    WDFDEVICE device = WdfIoQueueGetDevice(queue);
    DEVICE_CONTEXT *context = DeviceContext(device);
    PVOID input, output; size_t capacity;
    uint32_t function = RP_NO_FUNCTION;
    UNREFERENCED_PARAMETER(outputLength);
    if (code == IOCTL_ACPI_EVAL_METHOD && WdfRequestGetRequestorMode(request) == KernelMode &&
        NT_SUCCESS(WdfRequestRetrieveInputBuffer(request, 16, &input, &capacity)) && inputLength <= capacity)
        function = RpPolicyFunction(input, inputLength);
    if (function == 0) {
        InterlockedExchange(&context->Armed, 0);
        Forward(request, device, TRUE);
        return;
    }
    if (function == 4 && InterlockedCompareExchange(&context->Armed, 0, 0)) {
        if (!NT_SUCCESS(WdfRequestRetrieveOutputBuffer(request, RP_OUTPUT_BYTES, &output, &capacity)) ||
            !RpWriteDisableReply(output, capacity)) {
            WdfRequestComplete(request, STATUS_BUFFER_TOO_SMALL);
            return;
        }
        TraceLoggingWrite(g_Trace, "DisableCorrectionReply", TraceLoggingUInt32(1, "Value"));
        WdfRequestCompleteWithInformation(request, STATUS_SUCCESS, RP_OUTPUT_BYTES);
        return;
    }
    Forward(request, device, FALSE);
}

VOID MaskCompleted(WDFREQUEST request, WDFIOTARGET target,
                   PWDF_REQUEST_COMPLETION_PARAMS params, WDFCONTEXT completionContext) {
    WDFDEVICE device = (WDFDEVICE)completionContext;
    PVOID output; size_t capacity;
    UNREFERENCED_PARAMETER(target);
    if (NT_SUCCESS(params->IoStatus.Status) &&
        NT_SUCCESS(WdfRequestRetrieveOutputBuffer(request, RP_OUTPUT_BYTES, &output, &capacity)) &&
        RpPatchSupportedMask(output, capacity, params->IoStatus.Information)) {
        InterlockedExchange(&DeviceContext(device)->Armed, 1);
        TraceLoggingWrite(g_Trace, "SupportedMaskPatched",
            TraceLoggingUInt32(0x0f, "Original"), TraceLoggingUInt32(0x1f, "Returned"));
    }
    WdfRequestCompleteWithInformation(request, params->IoStatus.Status, params->IoStatus.Information);
}
