"use strict";

// WinDbg JavaScript. No writes, AML evaluation, UCSI commands or explicit physical-memory commands.
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

function emitProbeJson(result) {
    // DbgEng truncates sufficiently large individual output calls. Keep frames intact.
    const text = JSON.stringify(result);
    host.diagnostics.debugLog("UCSI_PROBE_JSON_BEGIN\n");
    for (let index = 0; index < text.length; index += 1024) {
        host.diagnostics.debugLog(text.slice(index, index + 1024));
    }
    host.diagnostics.debugLog("\nUCSI_PROBE_JSON_END\n");
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
    emitProbeJson(result);
    return result;
}

let connectionWindow = null;

function beginConnectionWindow(source, count, intervalMs) {
    if (source !== "LiveKD" && source !== "OfflineReplay") { throw new Error("Invalid capture source"); }
    if (!Number.isInteger(count) || count < 6 || count > 120 ||
        !Number.isInteger(intervalMs) || intervalMs < 100 || intervalMs > 2000 ||
        (count - 1) * intervalMs > 70000) { throw new Error("Unapproved sampling window"); }
    connectionWindow = {schema: 1, kind: "ConnectionWindow", source: source,
        startedUtc: new Date().toISOString(), expectedSamples: count, intervalMs: intervalMs,
        namespace: UCSI_NODE, namespaceOutput: [], samples: [], regions: [], discovery: "Failed",
        consistentSnapshot: false, firmwareWritesRequested: false, amlMethodsExecuted: false,
        explicitPhysicalMemoryCommands: false, readyEmitted: false};
    return "Bounded connection sampling initialized";
}

function readKernelControl(symbol, count) {
    if (!((symbol === "NtBuildNumber" && count === 4) || (symbol === "KeTickCount" && count === 12))) {
        throw new Error("Unapproved kernel control read");
    }
    const result = {symbol: symbol, expectedBytes: count, status: "Unavailable"};
    try {
        const address = host.getModuleSymbolAddress("nt", symbol);
        if (address === null || address === undefined) { throw new Error("Public symbol unavailable"); }
        canonicalKernelAddress(address.toString(16));
        const bytes = Array.from(host.memory.readMemoryValues(address, count, 1, false));
        if (bytes.length !== count || bytes.some(function(b) {
            return typeof b !== "number" || !Number.isInteger(b) || b < 0 || b > 255;
        })) { throw new Error("Incomplete kernel control"); }
        result.status = "Readable"; result.rawHex = byteHex(bytes);
    } catch (error) { result.error = String(error.message || error); }
    return result;
}

function sampleConnectionWindow(sequence) {
    if (connectionWindow === null || !Number.isInteger(sequence) ||
        sequence !== connectionWindow.samples.length || sequence >= connectionWindow.expectedSamples) {
        throw new Error("Unexpected sample sequence");
    }
    const sample = {sequence: sequence, startedUtc: new Date().toISOString(), discovery: "Failed", regions: []};
    // Fixed public-symbol controls: four build-number bytes and twelve tick-counter bytes.
    sample.controls = [readKernelControl("NtBuildNumber", 4), readKernelControl("KeTickCount", 12)];
    try {
        const lines = Array.from(host.namespace.Debugger.Utility.Control.ExecuteCommand("!amli dns /s " + UCSI_NODE));
        const regions = discoverUcsiRegions(lines);
        if (connectionWindow.namespaceOutput.length === 0) { connectionWindow.namespaceOutput = lines; }
        sample.discovery = "Validated";
        sample.regions = examineRegions(regions, function(address, count) {
            return host.memory.readMemoryValues(host.parseInt64(address), count, 1, false);
        });
        // Page-table metadata only; never read the physical firmware pages directly.
        if (sequence === 0 || sequence === connectionWindow.expectedSamples - 1) {
            sample.pageTables = regions.map(function(region) {
                const diagnostic = {name: region.name};
                try {
                    diagnostic.lines = Array.from(host.namespace.Debugger.Utility.Control.ExecuteCommand("!pte " + region.mappedVirtualAddress));
                } catch (error) { diagnostic.error = String(error.message || error); }
                return diagnostic;
            });
        }
    } catch (error) { sample.discoveryError = String(error.message || error); }
    sample.finishedUtc = new Date().toISOString();
    connectionWindow.samples.push(sample);
    host.diagnostics.debugLog("UCSI_CONNECTION_SAMPLE " + JSON.stringify(sample) + "\n");
    if (sample.discovery === "Validated" && !connectionWindow.readyEmitted) {
        connectionWindow.readyEmitted = true;
        host.diagnostics.debugLog("UCSI_CONNECTION_READY\n");
    }
    return sequence;
}

function endConnectionWindow() {
    if (connectionWindow === null || connectionWindow.samples.length !== connectionWindow.expectedSamples) {
        throw new Error("Incomplete connection window");
    }
    const result = connectionWindow;
    result.validatedSamples = result.samples.filter(function(s) { return s.discovery === "Validated"; }).length;
    result.discovery = result.validatedSamples > 0 ? "Validated" : "Failed";
    result.regions = REGION_RULES.map(function(rule) {
        const reads = [];
        for (const sample of result.samples) {
            for (const region of sample.regions) { if (region.name === rule.name) { reads.push(region); } }
        }
        const readable = reads.filter(function(r) { return r.status === "Readable"; });
        return {name: rule.name, expectedBytes: rule.bytes, attemptedSamples: reads.length,
            readableSamples: readable.length, status: readable.length > 0 ? "Readable" : "Unavailable"};
    });
    const tickValues = result.samples.map(function(sample) {
        return sample.controls.filter(function(c) { return c.symbol === "KeTickCount" && c.status === "Readable"; });
    }).filter(function(items) { return items.length === 1; }).map(function(items) { return items[0].rawHex; });
    result.changingKernelClockObserved = tickValues.some(function(value) { return value !== tickValues[0]; });
    result.finishedUtc = new Date().toISOString();
    emitProbeJson(result);
    connectionWindow = null;
    return result;
}

function initializeScript() { return [new host.apiVersionSupport(1, 7)]; }
