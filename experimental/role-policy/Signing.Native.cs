using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

namespace Usb4RolePolicy {
    // Read-only cryptographic checks. No catalog installation or certificate trust writes.
    public static class SignatureCheck {
        [DllImport("wintrust.dll",CharSet=CharSet.Unicode,SetLastError=true)]
        static extern bool CryptCATAdminAcquireContext2(out IntPtr context,ref Guid subsystem,string algorithm,IntPtr policy,uint flags);
        [DllImport("wintrust.dll",SetLastError=true)]
        static extern bool CryptCATAdminCalcHashFromFileHandle2(IntPtr context,IntPtr file,ref uint size,byte[] hash,uint flags);
        [DllImport("wintrust.dll")] static extern bool CryptCATAdminReleaseContext(IntPtr context,uint flags);
        [DllImport("wintrust.dll",CharSet=CharSet.Unicode,SetLastError=true)]
        static extern IntPtr CryptCATOpen(string path,uint flags,IntPtr provider,uint version,uint encoding);
        [DllImport("wintrust.dll",CharSet=CharSet.Unicode)] static extern IntPtr CryptCATGetMemberInfo(IntPtr catalog,string tag);
        [DllImport("wintrust.dll")] static extern bool CryptCATClose(IntPtr catalog);
        [DllImport("crypt32.dll",SetLastError=true)]
        static extern bool CryptQueryObject(uint kind,IntPtr file,uint content,uint format,uint flags,
            out uint encoding,out uint type,out uint form,out IntPtr store,out IntPtr message,IntPtr context);
        [DllImport("crypt32.dll",SetLastError=true)] static extern bool CryptMsgControl(IntPtr message,uint flags,uint type,IntPtr data);
        [DllImport("crypt32.dll")] static extern bool CryptMsgClose(IntPtr message);
        [DllImport("crypt32.dll")] static extern bool CertCloseStore(IntPtr store,uint flags);
        [StructLayout(LayoutKind.Sequential)] struct CertificateContext {
            public uint Encoding;public IntPtr Encoded;public uint Length;public IntPtr Info;public IntPtr Store;
        }
        static void Require(bool value){if(!value)throw new Win32Exception(Marshal.GetLastWin32Error());}
        public static string AuthenticodeHash(string path){
            IntPtr context=IntPtr.Zero;
            Guid subsystem=new Guid("f750e6c3-38ee-11d1-85e5-00c04fc295ee");
            Require(CryptCATAdminAcquireContext2(out context,ref subsystem,"SHA256",IntPtr.Zero,0));
            try {
                using(var file=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read)){
                    uint size=0;Require(CryptCATAdminCalcHashFromFileHandle2(context,file.SafeFileHandle.DangerousGetHandle(),ref size,null,0));
                    if(size!=32)throw new InvalidDataException("Expected SHA-256 digest.");
                    byte[] hash=new byte[size];file.Position=0;
                    Require(CryptCATAdminCalcHashFromFileHandle2(context,file.SafeFileHandle.DangerousGetHandle(),ref size,hash,0));
                    return BitConverter.ToString(hash).Replace("-","");
                }
            } finally {CryptCATAdminReleaseContext(context,0);}
        }
        public static bool CatalogContains(string catalog,string file){
            string digest=AuthenticodeHash(file);
            IntPtr handle=CryptCATOpen(catalog,0,IntPtr.Zero,0x200,0x10001);
            if(handle==IntPtr.Zero||handle==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error());
            try{return CryptCATGetMemberInfo(handle,digest)!=IntPtr.Zero;}
            finally{CryptCATClose(handle);}
        }
        public static void VerifySignatureMath(string file,string certificate){
            IntPtr name=Marshal.StringToCoTaskMemUni(Path.GetFullPath(file)),store=IntPtr.Zero,message=IntPtr.Zero;
            try{
                uint encoding,type,format;
                Require(CryptQueryObject(1,name,0x100|0x400,2,0,out encoding,out type,out format,out store,out message,IntPtr.Zero));
                using(var cert=new X509Certificate2(certificate)){
                    var context=(CertificateContext)Marshal.PtrToStructure(cert.Handle,typeof(CertificateContext));
                    Require(CryptMsgControl(message,0,1,context.Info));
                }
            }finally{
                if(message!=IntPtr.Zero)CryptMsgClose(message);
                if(store!=IntPtr.Zero)CertCloseStore(store,0);
                Marshal.FreeCoTaskMem(name);
            }
        }
        [StructLayout(LayoutKind.Sequential)] struct CodeIntegrity {public uint Length,Flags;}
        [DllImport("ntdll.dll")] static extern int NtQuerySystemInformation(int kind,ref CodeIntegrity data,uint length,out uint returned);
        public static uint CodeIntegrityFlags(){
            var info=new CodeIntegrity{Length=8};uint returned;
            int status=NtQuerySystemInformation(103,ref info,8,out returned);
            if(status<0||returned!=8)throw new InvalidOperationException("Code-integrity flags unavailable.");
            return info.Flags;
        }
    }
}
