// Standard descriptor transport only. Do not invoke in the interactive process:
// the planned PowerShell wrapper must supervise a separate worker with a time limit.
// This component has been compiled offline; no native method has been exercised.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Usb4Research {
    public sealed class BillboardStringRecord {
        public byte Index;
        public ushort Language;
        public string RawBase64;
        public string Text;
    }
    public sealed class BillboardStringCapture {
        public string HubPath;
        public uint Port;
        public ushort UsbAddressBefore;
        public ushort UsbAddressAfter;
        public string BosBase64;
        public string LanguageReplyBase64;
        public List<BillboardStringRecord> Strings = new List<BillboardStringRecord>();
    }
    public static class BillboardHubReader {
        [ThreadStatic] static string CaptureDirectory;
        [ThreadStatic] static int RequestSequence;
        [StructLayout(LayoutKind.Sequential)]
        struct InterfaceData { public uint Size; public Guid Class; public uint Flags; public IntPtr Reserved; }
        [StructLayout(LayoutKind.Sequential)]
        struct DeviceInfo { public uint Size; public Guid Class; public uint DevInst; public IntPtr Reserved; }
        [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr w, uint flags);
        [DllImport("setupapi.dll", SetLastError=true)]
        static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr dev, ref Guid g, uint index, ref InterfaceData data);
        [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref InterfaceData data, IntPtr detail, uint bytes, out uint required, ref DeviceInfo dev);
        [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern bool SetupDiGetDeviceInstanceId(IntPtr set, ref DeviceInfo dev, StringBuilder text, uint bytes, out uint required);
        [DllImport("setupapi.dll")]
        static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern SafeFileHandle CreateFile(string path, uint access, uint share, IntPtr sec, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool DeviceIoControl(SafeFileHandle h, uint code, byte[] input, uint inputBytes, byte[] output, uint outputBytes, out uint returned, IntPtr overlapped);

        static void Need(bool ok, string message) { if (!ok) throw new InvalidDataException(message); }
        static void Port(byte[] b, uint port) { Array.Copy(BitConverter.GetBytes(port),b,4); }
        static int Read(SafeFileHandle h, uint code, byte[] b) {
            Need(code == 0x220420 || code == 0x220448 || code == 0x220410, "IOCTL outside read allowlist");
            string stem=Path.Combine(CaptureDirectory,(++RequestSequence).ToString("D2")+"-"+code.ToString("x8"));
            using(FileStream f=new FileStream(stem+"-request.bin",FileMode.CreateNew)) f.Write(b,0,b.Length);
            uint returned;
            bool success=DeviceIoControl(h,code,b,(uint)b.Length,b,(uint)b.Length,out returned,IntPtr.Zero);
            int error=success?0:Marshal.GetLastWin32Error();
            using(FileStream f=new FileStream(stem+"-reply.bin",FileMode.CreateNew)) f.Write(b,0,b.Length);
            File.WriteAllText(stem+"-status.txt","success="+success+"\r\nreturned="+returned+"\r\nwin32="+error);
            if (!success) throw new Win32Exception(error);
            Need(returned <= b.Length, "Driver returned an invalid byte count");
            return (int)returned;
        }

        static string FindHub(string parent) {
            Need(parent != null && parent.StartsWith("USB\\VID_1D5C&PID_5801\\",StringComparison.OrdinalIgnoreCase), "Unexpected parent hub identity");
            Guid g = new Guid("f18a0e88-c30c-11d0-8815-00a0c906bed8");
            IntPtr set = SetupDiGetClassDevs(ref g,IntPtr.Zero,IntPtr.Zero,0x12);
            if (set == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
            string found = null;
            try {
                for (uint i=0;i<256;i++) {
                    InterfaceData iface = new InterfaceData(); iface.Size=(uint)Marshal.SizeOf(typeof(InterfaceData));
                    if (!SetupDiEnumDeviceInterfaces(set,IntPtr.Zero,ref g,i,ref iface)) {
                        int error=Marshal.GetLastWin32Error(); if(error==259) return found;
                        throw new Win32Exception(error);
                    }
                    DeviceInfo dev=new DeviceInfo(); dev.Size=(uint)Marshal.SizeOf(typeof(DeviceInfo));
                    uint required;
                    bool first=SetupDiGetDeviceInterfaceDetail(set,ref iface,IntPtr.Zero,0,out required,ref dev);
                    int firstError=Marshal.GetLastWin32Error();
                    Need(!first && firstError==122 && required>=8 && required<=65536,"Invalid interface detail length");
                    IntPtr detail=Marshal.AllocHGlobal((int)required);
                    try {
                        Marshal.WriteInt32(detail,IntPtr.Size==8?8:6);
                        uint size=required;
                        if(!SetupDiGetDeviceInterfaceDetail(set,ref iface,detail,size,out required,ref dev)) throw new Win32Exception(Marshal.GetLastWin32Error());
                        Need(required<=size,"Interface detail changed");
                        StringBuilder id=new StringBuilder(1024); uint idBytes;
                        if(!SetupDiGetDeviceInstanceId(set,ref dev,id,1024,out idBytes)) throw new Win32Exception(Marshal.GetLastWin32Error());
                        if(String.Equals(id.ToString(),parent,StringComparison.OrdinalIgnoreCase)) {
                            Need(found==null,"Multiple interfaces for selected parent");
                            // SP_DEVICE_INTERFACE_DETAIL_DATA_W has a DWORD then WCHAR path,
                            // even though its x64 cbSize is8.
                            string bounded=Marshal.PtrToStringUni(IntPtr.Add(detail,4),((int)size-4)/2);
                            int end=bounded.IndexOf('\0'); Need(end>=0,"Unterminated hub interface path");
                            found=bounded.Substring(0,end);
                            Need(found!=null && found.StartsWith("\\\\?\\",StringComparison.Ordinal),"Invalid hub interface path");
                        }
                    } finally { Marshal.FreeHGlobal(detail); }
                }
                throw new InvalidDataException("Hub enumeration exceeded limit");
            } finally { SetupDiDestroyDeviceInfoList(set); }
        }

        static void CheckDriverKey(SafeFileHandle h,uint port,string expected) {
            Need(!String.IsNullOrEmpty(expected) && expected.Length<=512,"Missing target driver key");
            byte[] b=new byte[2048]; Port(b,port); int n=Read(h,0x220420,b);
            Need(n>=10 && BitConverter.ToUInt32(b,0)==port,"Invalid driver-key reply");
            uint length=BitConverter.ToUInt32(b,4);
            Need(length>=10 && length<=n && (length-8)%2==0,"Invalid driver-key length");
            string key=new UnicodeEncoding(false,false,true).GetString(b,8,(int)length-8);
            int nul=key.IndexOf('\0'); Need(nul>=0,"Unterminated driver key");
            Need(String.Equals(key.Substring(0,nul),expected,StringComparison.OrdinalIgnoreCase),"Port does not belong to selected PnP device");
        }
        static ushort CheckIdentity(SafeFileHandle h,uint port) {
            byte[] b=new byte[4096]; Port(b,port); int n=Read(h,0x220448,b);
            return BillboardDescriptorProtocol.ValidateConnection(b,n,port);
        }
        static byte[] BosRequest(uint port,ushort size) {
            Need(size==5 || size==112,"BOS size outside retained-device contract");
            byte[] b=new byte[12+size]; Port(b,port); b[7]=15;
            Array.Copy(BitConverter.GetBytes(size),0,b,10,2); return b;
        }
        static byte[] Payload(byte[] b,int n,int required) {
            Need(n==12+required,"Descriptor byte count differs from requested exact size");
            byte[] result=new byte[required]; Buffer.BlockCopy(b,12,result,0,required); return result;
        }

        // Caller must derive these three fields from the same freshly selected exact
        //041f:d002/rev8200 PnP instance. Driver-key equality independently checks port ownership.
        public static BillboardStringCapture Capture(string parent,uint port,string driverKey,string privateDirectory) {
            Need(CaptureDirectory==null && Directory.Exists(privateDirectory),"Capture requires a new worker and existing private directory");
            CaptureDirectory=Path.GetFullPath(privateDirectory); RequestSequence=0;
            Need(port>=1 && port<=255,"Invalid downstream port");
            string path=FindHub(parent); Need(path!=null,"Selected parent hub is unavailable");
            using(SafeFileHandle h=CreateFile(path,0x40000000,3,IntPtr.Zero,3,0,IntPtr.Zero)) {
                if(h.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
                CheckDriverKey(h,port,driverKey);
                BillboardStringCapture result=new BillboardStringCapture(); result.HubPath=path; result.Port=port;
                result.UsbAddressBefore=CheckIdentity(h,port);
                byte[] header=BosRequest(port,5); int n=Read(h,0x220410,header);
                byte[] bh=Payload(header,n,5);
                Need(bh[0]==5 && bh[1]==15 && BitConverter.ToUInt16(bh,2)==112,"Unexpected current BOS header");
                byte[] request=BosRequest(port,112); n=Read(h,0x220410,request);
                byte[] bos=Payload(request,n,112); byte[] indices=BillboardDescriptorProtocol.ValidateAdvertisedStrings(bos);
                result.BosBase64=Convert.ToBase64String(bos);
                byte[] langs=BillboardDescriptorProtocol.BuildStringRequest(port,0,0); n=Read(h,0x220410,langs);
                ushort[] languages=BillboardDescriptorProtocol.ParseLanguages(langs,n,port);
                // Prefer advertised English(US); otherwise use the first advertised LANGID.
                ushort language=languages[0]; foreach(ushort lang in languages) if(lang==0x409) language=lang;
                result.LanguageReplyBase64=Convert.ToBase64String(langs,0,n);
                foreach(byte index in indices) {
                    byte[] reply=BillboardDescriptorProtocol.BuildStringRequest(port,index,language); n=Read(h,0x220410,reply);
                    string text=BillboardDescriptorProtocol.ParseText(reply,n,port);
                    result.Strings.Add(new BillboardStringRecord {Index=index,Language=language,RawBase64=Convert.ToBase64String(reply,0,n),Text=text});
                }
                CheckDriverKey(h,port,driverKey); result.UsbAddressAfter=CheckIdentity(h,port);
                Need(result.UsbAddressAfter==result.UsbAddressBefore,"USB address changed during collection");
                return result;
            }
        }
    }
}
