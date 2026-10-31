"use strict";

// WinDbg JavaScript. No memory writes, AML evaluation, UCSI commands or physical reads.
const UCSI_NODE = "\\_SB_.UBTC";
const REGION_RULES = [{name: "PM08", bytes: 48}, {name: "EURM", bytes: 64}];

function canonicalKernelAddress(value) {
    const text = String(value).replace(/`/g, "").replace(/^0x/i, "").toLowerCase();
    if (!/^ffff[89a-f][0-9a-f]{11}$/.test(text) || text === "ffffffffffffffff") {
        throw new Error("Not an accepted x64 mapped kernel address");
    }
    return text;
}

function boundedAddressEnd(address, count) {
    let high = parseInt(address.slice(0, 8), 16);
    const sum = parseInt(address.slice(8), 16) + count;
    if (sum >= 0x100000000) { high += 1; }
    if (high > 0xffffffff) { throw new Error("Firmware read would wrap the address space"); }
    return ("00000000" + high.toString(16)).slice(-8) +
        ("00000000" + (sum >>> 0).toString(16)).slice(-8);
}

function validateRegionList(regions) {
    if (regions.length !== REGION_RULES.length) { throw new Error("Unexpected firmware region count"); }
    const bounds = regions.map(function(region, index) {
        if (region.name !== REGION_RULES[index].name || region.expectedBytes !== REGION_RULES[index].bytes) {
            throw new Error("Unapproved firmware region or read length");
        }
        const address = canonicalKernelAddress(region.mappedVirtualAddress);
        return {start: address, end: boundedAddressEnd(address, region.expectedBytes)};
    });
    if (bounds[0].start < bounds[1].end && bounds[1].start < bounds[0].end) {
        throw new Error("Firmware mappings overlap");
    }
}

function discoverUcsiRegions(lines) {
    const text = Array.from(lines).join("\n");
    if (!/ACPI Name Space:\s*\\_SB_?\.UBTC\s*\(/i.test(text) || !/Device\(UBTC\)/.test(text)) {
        throw new Error("Expected UBTC namespace device was not found");
    }
    // EISA-encoded USBC000. Require this device, not just similarly named regions.
    if (!/Integer\(_HID:Value=0x0*c06256\[/i.test(text)) {
        throw new Error("UBTC hardware ID does not match USBC000");
    }
    const regions = [];
    for (const rule of REGION_RULES) {
        const expression = new RegExp("OpRegion\\(" + rule.name + ":RegionSpace=([^,]+),Offset=([0-9a-fx`]+),Len=([0-9]+)\\)", "gi");
        const matches = [];
        let match;
        while ((match = expression.exec(text)) !== null) { matches.push(match); }
        if (matches.length !== 1) { throw new Error("Expected exactly one region " + rule.name); }
        match = matches[0];
        if (match[1] !== "SystemMemory" || Number(match[3]) !== rule.bytes) {
            throw new Error("Unsupported firmware region space or size: " + rule.name);
        }
        const address = canonicalKernelAddress(match[2]);
        regions.push({name: rule.name, mappedVirtualAddress: "0x" + address, expectedBytes: rule.bytes});
    }
    validateRegionList(regions);
    return regions;
}

function byteHex(bytes) {
    return bytes.map(function(value) { return ("0" + value.toString(16)).slice(-2); }).join(" ");
}

function decodeLegacyUcsi(bytes) {
    if (bytes.length !== 48) { throw new Error("A UCSI region must contain exactly 48 bytes"); }
    const version = bytes[0] | (bytes[1] << 8);
    const raw = {versionHex: "0x" + ("0000" + version.toString(16)).slice(-4), interpretation: "RawOnly"};
    // Do not turn all-FF/unrecognized version values into fabricated protocol fields.
    if ([0x0100, 0x0110, 0x0120].indexOf(version) < 0) { return raw; }
    const cci = (bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24)) >>> 0;
    raw.interpretation = "LegacyUcsi1x";
    raw.version = (version >>> 8) + "." + ((version >>> 4) & 15) + "." + (version & 15);
    raw.cciHex = "0x" + ("00000000" + cci.toString(16)).slice(-8);
    raw.cci = {
        connectorChange: (cci >>> 1) & 127,
        dataLength: (cci >>> 8) & 255,
        notSupported: (cci >>> 25) & 1,
        cancelCompleted: (cci >>> 26) & 1,
        resetCompleted: (cci >>> 27) & 1,
        busy: (cci >>> 28) & 1,
        ackCompleted: (cci >>> 29) & 1,
        error: (cci >>> 30) & 1,
        commandCompleted: (cci >>> 31) & 1
    };
    raw.controlHex = byteHex(bytes.slice(8, 16));
    raw.messageInHex = byteHex(bytes.slice(16, 32));
    raw.messageOutHex = byteHex(bytes.slice(32, 48));
    return raw;
}

function examineRegions(regions, readBytes) {
    validateRegionList(regions);
    return regions.map(function(region) {
        const result = {name: region.name, mappedVirtualAddress: region.mappedVirtualAddress,
            expectedBytes: region.expectedBytes, status: "Unavailable", readStartedUtc: new Date().toISOString()};
        try {
            const bytes = Array.from(readBytes(region.mappedVirtualAddress, region.expectedBytes));
            if (bytes.length !== region.expectedBytes || bytes.some(function(b) {
                return typeof b !== "number" || !Number.isInteger(b) || b < 0 || b > 255;
            })) { throw new Error("The memory provider did not return a complete byte buffer"); }
            result.rawHex = byteHex(bytes);
            result.status = "Readable";
            result.allZero = bytes.every(function(b) { return b === 0; });
            result.allFF = bytes.every(function(b) { return b === 255; });
            if (region.name === "PM08") { result.decoded = decodeLegacyUcsi(bytes); }
            // EURM is vendor-specific shadow storage. Preserve bytes without assuming an ABI.
        } catch (error) { result.error = String(error.message || error); }
        result.readFinishedUtc = new Date().toISOString();
        return result;
    });
}

function probeFirmwareBuffers(source) {
    if (source !== "LiveKD" && source !== "OfflineReplay") { throw new Error("Invalid capture source"); }
    const result = {schema: 1, source: source, startedUtc: new Date().toISOString(),
        namespace: UCSI_NODE, discovery: "Failed", regions: [], consistentSnapshot: false,
        firmwareWritesRequested: false, amlMethodsExecuted: false, explicitPhysicalMemoryCommands: false};
    try {
        const command = "!amli dns /s " + UCSI_NODE;
        const lines = Array.from(host.namespace.Debugger.Utility.Control.ExecuteCommand(command));
        result.namespaceOutput = lines;
        const regions = discoverUcsiRegions(lines);
        result.discovery = "Validated";
        result.regions = examineRegions(regions, function(address, count) {
            return host.memory.readMemoryValues(host.parseInt64(address), count, 1, false);
        });
    } catch (error) { result.discoveryError = String(error.message || error); }
    result.finishedUtc = new Date().toISOString();
    // A wrapper and a returned object permit both batch extraction and interactive inspection.
    host.diagnostics.debugLog("UCSI_PROBE_JSON_BEGIN\n" + JSON.stringify(result) + "\nUCSI_PROBE_JSON_END\n");
    return result;
}

function initializeScript() { return [new host.apiVersionSupport(1, 7)]; }
