using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace Usb4DeepCompare {
    public sealed class FileReceipt {
        public string Name;
        public long Bytes;
        public string Sha256;
    }
    public static class Native {
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern uint EnumSystemFirmwareTables(uint provider, [Out] byte[] buffer, uint size);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern uint GetSystemFirmwareTable(uint provider, uint id, [Out] byte[] buffer, uint size);
        const uint Acpi = 0x41435049; // Provider is 'ACPI'; returned table IDs are little endian.
        public static uint[] AcpiIds() {
            uint size = EnumSystemFirmwareTables(Acpi, null, 0);
            if (size == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
            if (size > 65536 || size % 4 != 0) throw new InvalidDataException("Unexpected ACPI enumeration size.");
            byte[] bytes = new byte[size];
            if (EnumSystemFirmwareTables(Acpi, bytes, size) != size) throw new InvalidDataException("ACPI enumeration changed or failed.");
            uint[] ids = new uint[size / 4];
            for (int i=0; i<ids.Length; i++) ids[i] = BitConverter.ToUInt32(bytes, i*4);
            return ids;
        }
        public static byte[] AcpiTable(uint id) {
            uint size = GetSystemFirmwareTable(Acpi, id, null, 0);
            if (size == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
            if (size < 36 || size > 16*1024*1024) throw new InvalidDataException("Unexpected ACPI table size.");
            byte[] bytes = new byte[size];
            if (GetSystemFirmwareTable(Acpi, id, bytes, size) != size) throw new InvalidDataException("ACPI table read changed or failed.");
            return bytes;
        }
        static string Hex(byte[] bytes) { return BitConverter.ToString(bytes).Replace("-", ""); }
        public static FileReceipt Compress(string source, string destination) {
            long count = 0;
            using (SHA256 sha = SHA256.Create()) {
                using (FileStream input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read))
                using (FileStream output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                    using (GZipStream gzip = new GZipStream(output, CompressionLevel.Optimal, true)) {
                        byte[] buffer = new byte[1024*1024];
                        int n;
                        while ((n=input.Read(buffer,0,buffer.Length)) != 0) {
                            sha.TransformBlock(buffer,0,n,buffer,0);
                            gzip.Write(buffer,0,n); count += n;
                        }
                        sha.TransformFinalBlock(new byte[0],0,0);
                    }
                    // .NET Framework can emit no member when an empty input was
                    // never written. Preserve empty files as a valid RFC1952 member.
                    if (count == 0 && output.Length == 0) {
                        byte[] empty = {31,139,8,0,0,0,0,0,0,255,3,0,0,0,0,0,0,0,0,0};
                        output.Write(empty,0,empty.Length);
                    }
                    output.Flush(true);
                }
                return new FileReceipt { Name=Path.GetFileName(source), Bytes=count, Sha256=Hex(sha.Hash) };
            }
        }
        public static FileReceipt[] SplitCopy(string source, string directory, long partBytes) {
            if (partBytes < 1024 || partBytes > 1024L*1024*1024) throw new ArgumentOutOfRangeException("partBytes");
            var result = new List<FileReceipt>();
            using (FileStream input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                byte[] buffer = new byte[1024*1024];
                while (input.Position < input.Length) {
                    if (result.Count >= 65535) throw new InvalidDataException("Too many transport parts.");
                    string name = "part"+(result.Count+1).ToString("D5")+".gzseg";
                    long count = 0;
                    using (SHA256 sha = SHA256.Create()) {
                        using (FileStream output = new FileStream(Path.Combine(directory,name), FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                            while (count < partBytes) {
                                int n = input.Read(buffer,0,(int)Math.Min(buffer.Length,partBytes-count));
                                if (n == 0) break;
                                output.Write(buffer,0,n); sha.TransformBlock(buffer,0,n,buffer,0); count += n;
                            }
                            sha.TransformFinalBlock(new byte[0],0,0); output.Flush(true);
                        }
                        result.Add(new FileReceipt { Name=name, Bytes=count, Sha256=Hex(sha.Hash) });
                    }
                }
            }
            return result.ToArray();
        }
    }
}
