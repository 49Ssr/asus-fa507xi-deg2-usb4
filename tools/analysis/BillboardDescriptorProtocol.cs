// Pure byte validation/request preparation. No native calls or device access.
// Windows SDK USBIOCTL.H is packed to one byte. See evidence/billboard-capture-contract.json.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Usb4Research {
    public static class BillboardDescriptorProtocol {
        public const uint DescriptorIoctl = 0x220410;
        public const uint ConnectionInfoIoctl = 0x220448;
        public const int RequestHeaderBytes = 12;
        public const int ConnectionInfoHeaderBytes = 35;

        private static ushort U16(byte[] b, int p) {
            return (ushort)(b[p] | (b[p + 1] << 8));
        }
        private static uint U32(byte[] b, int p) {
            return (uint)(b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24));
        }
        private static void Put16(byte[] b, int p, ushort v) {
            b[p] = (byte)v; b[p + 1] = (byte)(v >> 8);
        }
        private static void Put32(byte[] b, int p, uint v) {
            for (int i = 0; i < 4; i++) b[p + i] = (byte)(v >> (8 * i));
        }
        private static void Require(bool ok, string why) {
            if (!ok) throw new InvalidDataException(why);
        }

        // Fresh hub-port metadata must identify the Billboard, not its parent hub.
        // This validates a saved result; callers must establish the hub/interface binding.
        public static ushort ValidateConnection(byte[] b, int returned, uint port) {
            Require(b != null && returned >= ConnectionInfoHeaderBytes && returned <= b.Length,
                    "Truncated connection information");
            Require(port >= 1 && port <= 255 && U32(b, 0) == port, "Port mismatch");
            Require(b[4] == 18 && b[5] == 1, "Invalid device descriptor");
            Require(U16(b, 12) == 0x041f && U16(b, 14) == 0xd002 && U16(b, 16) == 0x8200,
                    "Not the retained DEG2 Billboard identity");
            Require(b[24] == 0 && U32(b, 31) == 1, "Not a connected non-hub device");
            return U16(b, 25); // USB address, for a subsequent consistency check only.
        }

        // A maximum of five standard string GETs: LANGID then advertised indices7..10.
        // USBHUB/USBD supplies request type80 and GET_DESCRIPTOR06, as in USBView.
        public static byte[] BuildStringRequest(uint port, byte index, ushort language) {
            Require(port >= 1 && port <= 255, "Invalid port");
            Require(index == 0 || (index >= 7 && index <= 10), "String outside fixed allowlist");
            Require(index == 0 ? language == 0 : language != 0, "Invalid string language");
            byte[] b = new byte[RequestHeaderBytes + 255];
            Put32(b, 0, port);
            Put16(b, 6, (ushort)(0x0300 | index));
            Put16(b, 8, language);
            Put16(b, 10, 255);
            return b;
        }

        public static byte[] ExtractStringReply(byte[] b, int returned, uint port) {
            Require(b != null && returned >= RequestHeaderBytes + 2 && returned <= b.Length,
                    "Truncated string reply");
            Require(U32(b, 0) == port, "Reply port mismatch");
            int length = returned - RequestHeaderBytes;
            Require(length <= 254 && length % 2 == 0 && b[12] == length && b[13] == 3,
                    "Invalid USB string type or exact length");
            byte[] payload = new byte[length - 2];
            Buffer.BlockCopy(b, 14, payload, 0, payload.Length);
            return payload;
        }

        public static ushort[] ParseLanguages(byte[] b, int returned, uint port) {
            byte[] p = ExtractStringReply(b, returned, port);
            Require(p.Length >= 2, "No supported language advertised");
            List<ushort> langs = new List<ushort>();
            for (int i = 0; i < p.Length; i += 2) {
                ushort language = U16(p, i);
                Require(language != 0 && !langs.Contains(language), "Invalid or duplicate LANGID");
                langs.Add(language);
            }
            return langs.ToArray();
        }

        public static string ParseText(byte[] b, int returned, uint port) {
            byte[] p = ExtractStringReply(b, returned, port);
            // Throw for malformed surrogate pairs instead of replacing bytes silently.
            return new UnicodeEncoding(false, false, true).GetString(p);
        }

        // Use fresh BOS data to establish the advertised indices before string GETs.
        // Revision/count/SVIDs match the two retained inputs. Configuration status may differ.
        public static byte[] ValidateAdvertisedStrings(byte[] b) {
            Require(b != null && b.Length >= 5 && b[0] == 5 && b[1] == 15 && U16(b, 2) == b.Length,
                    "Invalid BOS header or total length");
            int pos = 5, count = 0, found = -1;
            while (pos < b.Length) {
                Require(pos + 3 <= b.Length, "Truncated capability");
                int n = b[pos];
                Require(n >= 3 && pos + n <= b.Length && b[pos + 1] == 16,
                        "Invalid capability boundary");
                if (b[pos + 2] == 13) {
                    Require(found == -1 && n == 56, "Unexpected Billboard count or size");
                    found = pos;
                }
                count++; pos += n;
            }
            Require(count == b[4] && found >= 0, "Missing Billboard or capability count mismatch");
            int f = found;
            Require(b[f + 3] == 7 && b[f + 4] == 3 && U16(b, f + 40) == 0x0122,
                    "Unqualified URL index, mode count or revision");
            ushort[] svids = {0xff00, 0x8087, 0xff01};
            for (int i = 0; i < 3; i++) {
                int m = f + 44 + 4 * i;
                Require(U16(b, m) == svids[i] && b[m + 3] == 8 + i,
                        "Unqualified mode/string mapping");
            }
            return new byte[] {7, 8, 9, 10};
        }
    }
}
