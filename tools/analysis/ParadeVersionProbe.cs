// Version-only transport. Never loads a driver or sends a CFU offer/payload.
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class ParadeVersionProbe {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sa, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool DeviceIoControl(IntPtr file, uint code, IntPtr input, uint inputSize, IntPtr output, uint outputSize, IntPtr returned, IntPtr overlapped);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CancelIoEx(IntPtr file, IntPtr overlapped);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetOverlappedResult(IntPtr file, IntPtr overlapped, out uint count, bool wait);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateEvent(IntPtr sa, bool manual, bool initial, string name);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    static readonly IntPtr Invalid = new IntPtr(-1);
    static void Check(bool ok, string operation) {
        if (!ok) throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
    }
    static byte[] Send(IntPtr file, uint code) {
        if(code != 0x04001c00 && code != 0x04001c10) throw new InvalidOperationException("IOCTL denied");
        bool read = code == 0x04001c10;
        IntPtr input=Marshal.AllocHGlobal(1), output=Marshal.AllocHGlobal(4), ov=Marshal.AllocHGlobal(32);
        IntPtr ev=IntPtr.Zero;
        bool completed=true;
        try {
            Marshal.WriteByte(input, 1); // Fixed MCU version register; no data write.
            for(int n=0;n<4;n++) Marshal.WriteByte(output,n,0);
            for(int n=0;n<32;n++) Marshal.WriteByte(ov,n,0);
            ev=CreateEvent(IntPtr.Zero,true,false,null); Check(ev!=IntPtr.Zero,"CreateEvent");
            Marshal.WriteIntPtr(ov,24,ev); // x64 OVERLAPPED.hEvent
            bool ok=DeviceIoControl(file,code,read?input:IntPtr.Zero,read?1u:0u,
                                    read?output:IntPtr.Zero,read?4u:0u,IntPtr.Zero,ov);
            int error=ok?0:Marshal.GetLastWin32Error();
            if(!ok && error!=997) throw new Win32Exception(error,"Version probe IOCTL 0x"+code.ToString("X8"));
            if(!ok) {
                completed=false;
                uint wait=WaitForSingleObject(ev,5000);
                if(wait!=0) {
                    CancelIoEx(file,ov);
                    completed=WaitForSingleObject(ev,5000)==0;
                    throw new TimeoutException("Version probe timed out; no retry. Cancellation completion: "+completed);
                }
                completed=true;
            }
            uint bytes; Check(GetOverlappedResult(file,ov,out bytes,false),"Version probe completion");
            if(read && bytes!=4) throw new InvalidOperationException("Expected exactly four version bytes; received "+bytes);
            byte[] result=new byte[read?4:0];
            if(read) Marshal.Copy(output,result,0,4);
            return result;
        } finally {
            // Never free an OVERLAPPED or buffers while cancellation is unresolved.
            // In that exceptional case they are retained until this process exits.
            if(completed) {
                if(ev!=IntPtr.Zero) CloseHandle(ev);
                Marshal.FreeHGlobal(input); Marshal.FreeHGlobal(output); Marshal.FreeHGlobal(ov);
            }
        }
    }
    public sealed class Result {
        public string Alias; public string Stage; public string VersionWord;
        public string Bytes; public string Error; public int NativeError; public bool HandleClosed;
    }
    public static Result ReadVersion(string alias) {
        if(alias!="PS883011" && alias!="PS883021") throw new InvalidOperationException("Endpoint denied");
        Result result=new Result(); result.Alias=alias; result.Stage="OpenFile";
        IntPtr file=CreateFile("\\\\.\\"+alias,0xc0000000,0,IntPtr.Zero,3,0x40000000,IntPtr.Zero);
        if(file==Invalid) { result.NativeError=Marshal.GetLastWin32Error(); result.Error=new Win32Exception(result.NativeError).Message; return result; }
        try {
            result.Stage="InitializeBus"; Send(file,0x04001c00);
            result.Stage="ReadVersionRegister1"; byte[] data=Send(file,0x04001c10);
            uint version=((uint)data[0]<<24)|((uint)data[1]<<16)|((uint)data[2]<<8)|data[3];
            result.Bytes=BitConverter.ToString(data); result.VersionWord="0x"+version.ToString("X8");
            result.Stage="Recorded";
        } catch(Exception ex) {
            result.Error=ex.GetType().Name+": "+ex.Message;
            Win32Exception win=ex as Win32Exception; if(win!=null) result.NativeError=win.NativeErrorCode;
        }
        finally {
            // Reviewed stock EvtFileCleanup closes this endpoint's resource-hub target.
            result.HandleClosed=CloseHandle(file);
            if(!result.HandleClosed) result.Error=(result.Error??"")+"; CloseHandle failed";
        }
        return result;
    }
}
