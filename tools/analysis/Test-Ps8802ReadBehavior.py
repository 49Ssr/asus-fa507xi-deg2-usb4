"""Compile three pinned upstream reader functions against RAM-only fixtures.

Requires the original Chromium EC ps8802.c/.h files and a C compiler.
No hardware, network, driver, actual sleep or operating-system power API.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

PINS = {
    "c": "9b16ed69de5b1eb5f8424a0d86f6c360c81c9314d56fe05e223eb82491c7b922",
    "h": "0a3b223ad81f6e82bb8c987f93a749d9d1ddee32f3977f7621e2d9bb58ea0b77",
}


def function(text, name):
    match = re.search(r"(?:static )?int " + name + r"\([^;]+?\)\s*\{", text)
    if not match:
        raise ValueError("Missing pinned function: " + name)
    depth = 1
    end = match.end()
    while depth:
        if text[end] == "{":
            depth += 1
        elif text[end] == "}":
            depth -= 1
        end += 1
    return text[match.start():end]


PRELUDE = r"""
#include <stdio.h>
#include <stdlib.h>
#define BIT(x) (1U << (x))
#define PS8802_DEBUG 0
#define PS8802_I2C_WAKE_DELAY 500
#define ccprintf(...) ((void)0)
#define EC_SUCCESS 0
#define EC_ERROR_UNKNOWN -1
#define EC_ERROR_NOT_POWERED -2
#define CHIPSET_STATE_HARD_OFF 1
#define USB_PD_MUX_NONE 0
#define USB_PD_MUX_USB_ENABLED 1
#define USB_PD_MUX_DP_ENABLED 2
#define USB_PD_MUX_POLARITY_INVERTED 4
typedef int mux_state_t;
struct usb_mux { int i2c_port, i2c_addr_flags; };
static int errors[8], values[8], reads, delays, off, bad;
static int chipset_in_state(int mask) { return mask && off; }
static void usleep(int micros) { if(micros != 500) bad++; delays++; }
static int i2c_read8(int port, int addr, int reg, int *value) {
    if(port != 97 || addr != 0x2a || reg != 6 || reads >= 8) { bad++; return -99; }
    int i = reads++; *value = values[i]; return errors[i];
}
"""

MAIN = r"""
static void require(int condition) { if(!condition) exit(3); }
static void reset(void) {
    for(int i=0;i<8;i++) { errors[i]=0; values[i]=0x54; }
    reads=delays=off=bad=0;
}
int main(void) {
    const struct usb_mux me={97,0x28}; mux_state_t state;
    reset(); off=1; state=99;
    require(ps8802_get_mux(&me,&state)==EC_ERROR_NOT_POWERED && !reads && !delays);
    reset();
    require(ps8802_get_mux(&me,&state)==0 && reads==2 && !delays && state==7 && !bad);
    reset(); errors[0]=-7;
    require(ps8802_get_mux(&me,&state)==0 && reads==3 && delays==1 && state==7 && !bad);
    reset(); errors[0]=errors[1]=-7;
    require(ps8802_get_mux(&me,&state)==-7 && reads==2 && delays==2 && !bad);
    reset(); errors[1]=-9;
    require(ps8802_get_mux(&me,&state)==-9 && reads==2 && !delays && !bad);
    reset(); values[1]=0x10;
    require(ps8802_get_mux(&me,&state)==0 && state==USB_PD_MUX_USB_ENABLED && reads==2 && !bad);
    puts("{\"scope\":\"Original reference reader with simulated bus/power/time\",\"cases\":6,\"hardOffBusReads\":0,\"awakeBusReads\":2,\"firstNackThenSuccessReads\":3,\"firstNackThenSuccessDelays\":1,\"delayMicroseconds\":500,\"twoNacksReturnFailure\":true,\"finalReadFailurePropagates\":true,\"actualHardwareRequests\":0}");
    return 0;
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_c", type=Path)
    parser.add_argument("source_h", type=Path)
    parser.add_argument("--compiler", default="cc")
    args = parser.parse_args()
    try:
        texts = {}
        for kind, path in (("c", args.source_c), ("h", args.source_h)):
            raw = path.read_bytes()
            if hashlib.sha256(raw).hexdigest() != PINS[kind]:
                raise ValueError("Pinned source hash differs: " + kind)
            texts[kind] = raw.decode("utf-8")
        defines = "\n".join(line for line in texts["h"].splitlines()
                            if line.startswith("#define "))
        funcs = "\n".join(function(texts["c"], name) for name in
                          ("ps8802_i2c_read", "ps8802_i2c_wake", "ps8802_get_mux"))
        with tempfile.TemporaryDirectory(prefix="ps8802-offline-") as temp:
            root = Path(temp)
            cfile, exe = root / "reference.c", root / "reference.exe"
            cfile.write_text(PRELUDE + defines + "\n" + funcs + MAIN,
                             encoding="utf-8", newline="\n")
            if Path(args.compiler).stem.lower() == "cl":
                command = [args.compiler, "/nologo", "/std:c11", "/TC",
                           "/Fe:" + str(exe), "/Fo:" + str(root / "reference.obj"), str(cfile)]
            else:
                command = [args.compiler, "-std=c11", "-O0", str(cfile), "-o", str(exe)]
            subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
            result = subprocess.run([str(exe)], cwd=root, check=True,
                                    capture_output=True, text=True)
            print(json.dumps(json.loads(result.stdout), indent=2))
        return 0
    except (OSError, ValueError, IndexError, subprocess.CalledProcessError) as exc:
        parser.exit(2, "Offline source execution stopped: " + str(exc) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
