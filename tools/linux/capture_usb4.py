#!/usr/bin/env python3
"""One Linux observation. Default Preview never reads hardware or writes files.

Capture requires the prepared SystemRescue FAT USB, root, and an allowed laptop.
Only logging controls, this process's files and the verified boot USB are written.
No authorization, role/mode request, raw register access, scan, flash or reboot.
All captures are PRIVATE; kernel logs can contain personal identifiers/pointers.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

BOOT = Path('/run/archiso/bootmnt')
MARKER = 'USB4 research capture media v1\n'
TB_ATTRS = ('vendor', 'device', 'vendor_name', 'device_name', 'authorized',
            'generation', 'rx_speed', 'tx_speed', 'rx_lanes', 'tx_lanes',
            'security', 'iommu_dma_protection')
TYPEC_ATTRS = ('data_role', 'power_role', 'power_operation_mode', 'port_type',
               'preferred_role', 'orientation', 'usb_power_delivery_revision',
               'usb_capability', 'usb_mode', 'supports_usb_power_delivery',
               'number_of_alternate_modes', 'type', 'svid', 'mode', 'active',
               'vdo', 'priority', 'description')
IDENTITY_ATTRS = ('id_header', 'cert_stat', 'product', 'product_type_vdo1',
                  'product_type_vdo2', 'product_type_vdo3')
USB_ATTRS = ('idVendor', 'idProduct', 'bcdDevice', 'product', 'speed', 'busnum', 'devnum')
PCI_ATTRS = ('vendor', 'device', 'class', 'subsystem_vendor', 'subsystem_device')


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def read(path, errors):
    try:
        with path.open(encoding='utf-8', errors='replace') as f:
            value = f.read(4097)
        if len(value) > 4096:
            raise ValueError('attribute exceeds limit')
        return value.strip()
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as exc:
        errors[str(path)] = str(exc)
        return None


def records(root, attrs, errors):
    result = {}
    if root.is_dir():
        for path in sorted(root.iterdir()):
            if path.is_dir():
                row = {a: read(path / a, errors) for a in attrs}
                row['sysfs_path'] = str(path.resolve())
                row['firmware_node'] = read(path / 'firmware_node/path', errors)
                result[path.name] = row
    return result


def snapshot(sysroot=Path('/sys')):
    errors = {}
    value = {'utc': utc(), 'monotonic_ns': time.monotonic_ns(),
             'thunderbolt': records(sysroot / 'bus/thunderbolt/devices', TB_ATTRS, errors),
             'typec': records(sysroot / 'class/typec', TYPEC_ATTRS, errors),
             'usb': records(sysroot / 'bus/usb/devices', USB_ATTRS, errors),
             'pci': records(sysroot / 'bus/pci/devices', PCI_ATTRS, errors)}
    for name, row in value['typec'].items():
        identity = sysroot / 'class/typec' / name / 'identity'
        if identity.is_dir():
            row['identity'] = {a: read(identity / a, errors) for a in IDENTITY_ATTRS}
    value['errors'] = errors
    return value


def external_routers(state):
    # Exclude root routers, domains, retimers and interfaces. Require device ID:
    # an XDomain entry or directory name alone is insufficient identification.
    return {name: row for name, row in state['thunderbolt'].items()
            if re.fullmatch(r'\d+-[0-9a-f]+', name) and int(name.split('-')[1], 16) != 0
            and row.get('device') is not None}


def deg2_usb_present(state):
    return any((row.get('idVendor', '').lower(), row.get('idProduct', '').lower())
               in {('041f', 'd002'), ('1d5c', '5801')} for row in state['usb'].values()
               if row.get('idVendor') and row.get('idProduct'))


def display_devices(state):
    result = set()
    for name, row in state['pci'].items():
        try:
            if int(row.get('class') or '', 16) >> 16 == 3:
                result.add((name, row.get('vendor'), row.get('device')))
        except ValueError:
            pass
    return result


def supported_product(product):
    return bool(re.search(r'(?:^|[^A-Z0-9])FA507XI(?:$|[^A-Z0-9])', product)
                or product == 'Latitude 5540')


def classify(before, samples, preconnected=False):
    if not samples:
        return {'status': 'IncompleteCapture', 'external_router_observed': None}
    seen = {}; new_displays = set(); target_seen = deg2_usb_present(before)
    baseline_routers = external_routers(before)
    for state in samples:
        observed = external_routers(state)
        seen.update({n: row for n, row in observed.items() if preconnected
                     or n not in baseline_routers
                     or (row.get('vendor'), row.get('device')) !=
                     (baseline_routers[n].get('vendor'), baseline_routers[n].get('device'))})
        new_displays.update(display_devices(state) - display_devices(before))
        target_seen = target_seen or deg2_usb_present(state)
    final = {n: row for n, row in external_routers(samples[-1]).items() if n in seen}
    if seen:
        if not final:
            status = 'ExternalRouterObservedThenAbsent'
        elif any(row.get('authorized') == '0' for row in final.values()):
            status = 'ExternalRouterPresentAuthorizationPending'
        else:
            status = 'ExternalRouterPresentRequiresTopologyReview'
    else:
        status = 'DEG2FallbackObservedNoExternalRouter' if target_seen else 'AttachmentNotEstablished'
    return {'status': status, 'external_router_observed': bool(seen),
            'observed_router_names': sorted(seen), 'final_router_names': sorted(final),
            'deg2_usb_signature_observed': target_seen,
            'new_display_endpoints': sorted(new_displays),
            'preconnected_without_fresh_attachment': preconnected,
            'limits': ['Router identity/topology requires review; no automatic DEG2 attribution.',
                       'New display endpoints are candidates, not proof of a bound RTX4080SUPER.',
                       'Router presence alone does not distinguish native USB4 from TBT3-compatible mode.',
                       'No raw PD exchange or applied retimer state is measured.',
                       'No authorization is performed; missing GPU can be authorization-related.']}


def command(args, output=None):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=15, check=False)
    if output is not None:
        output.write_bytes(result.stdout)
    if result.returncode:
        raise RuntimeError(f'{args[0]} returned {result.returncode}: '
                           + result.stdout.decode(errors='replace')[:500])
    return result.stdout.decode(errors='replace')


def verify_media(mount, transport_path, marker, source_script, boot=BOOT):
    if mount.get('target') != str(boot) or mount.get('fstype') != 'vfat':
        raise RuntimeError('A directly mounted writable-format SystemRescue USB is required.')
    if not re.fullmatch(r'/dev/sd[a-z]+\d+', mount.get('source', '')):
        raise RuntimeError('Unexpected boot-device mapping; no device will be mounted or written.')
    if not re.search(r'/usb\d+/', transport_path):
        raise RuntimeError('Boot device is not independently identified as USB storage.')
    if marker != MARKER or source_script != (boot / 'usb4/capture_usb4.py').resolve():
        raise RuntimeError('Prepared USB marker/script location does not match.')


def prepare_output():
    mounts = json.loads(command(['findmnt', '-J', '-T', str(BOOT),
                               '-o', 'TARGET,SOURCE,FSTYPE,OPTIONS']))['filesystems']
    if len(mounts) != 1:
        raise RuntimeError('Ambiguous boot mount.')
    mount = mounts[0]
    source = mount.get('source', '')
    block = Path('/sys/class/block') / Path(source).name
    disk = block.resolve().parent.name if (block / 'partition').exists() else ''
    transport = str((Path('/sys/class/block') / disk / 'device').resolve()) if disk else ''
    verify_media(mount, transport, (BOOT / 'USB4-CAPTURE-MEDIA.txt').read_text(encoding='utf-8'),
                 Path(__file__).resolve())
    manifest = json.loads((BOOT / 'usb4/payload-manifest.json').read_text(encoding='utf-8'))
    for rel, expected in manifest['files'].items():
        p = (BOOT / rel).resolve()
        if not p.is_relative_to(BOOT.resolve()) or hashlib.sha256(p.read_bytes()).hexdigest() != expected:
            raise RuntimeError('Payload verification failed: ' + rel)
    was_ro = 'ro' in mount.get('options', '').split(',')
    if was_ro:
        command(['mount', '-o', 'remount,rw', '--', str(BOOT)])
    try:
        if shutil.disk_usage(BOOT).free < 128 * 1024 * 1024:
            raise RuntimeError('Boot USB needs at least128MiB free for private results.')
        out = BOOT / 'USB4-RESULTS' / (dt.datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8])
        out.mkdir(parents=True, exist_ok=False)
        return out, was_ro
    except BaseException:
        if was_ro:
            command(['mount', '-o', 'remount,ro', '--', str(BOOT)])
        raise


def write_json(path, value):
    with path.open('w', encoding='utf-8', newline='\n') as f:
        json.dump(value, f, indent=2, ensure_ascii=True); f.write('\n')
        f.flush(); os.fsync(f.fileno())


class Logs:
    def __init__(self, out):
        self.out = out; self.children = []; self.files = []; self.instance = None
        self.notes = []

    def start_process(self, args, name):
        f = (self.out / name).open('wb'); self.files.append(f)
        try:
            self.children.append(subprocess.Popen(args, stdout=f, stderr=subprocess.STDOUT))
        except OSError as exc:
            self.notes.append(str(exc))

    def start(self):
        self.start_process(['dmesg', '--follow'], 'kernel.private.log')
        self.start_process(['udevadm', 'monitor', '--kernel', '--property'], 'uevents.private.log')
        for root in [Path('/sys/kernel/tracing'), Path('/sys/kernel/debug/tracing')]:
            if (root / 'available_events').is_file() and (root / 'instances').is_dir():
                try:
                    self.instance = root / 'instances' / ('usb4_capture_' + uuid.uuid4().hex[:8])
                    self.instance.mkdir()
                    (self.instance / 'buffer_size_kb').write_text('128', encoding='ascii')
                    clocks = (self.instance / 'trace_clock').read_text(encoding='ascii')
                    if 'mono' in clocks.replace('[', '').replace(']', '').split():
                        (self.instance / 'trace_clock').write_text('mono', encoding='ascii')
                    self.notes.append({'trace_clock': (self.instance / 'trace_clock').read_text().strip()})
                    enabled = []
                    for group in ['thunderbolt', 'ucsi', 'typec']:
                        enable = self.instance / 'events' / group / 'enable'
                        if enable.exists():
                            enable.write_text('1', encoding='ascii'); enabled.append(group)
                    self.notes.append({'enabled_trace_groups': enabled})
                    (self.instance / 'tracing_on').write_text('1', encoding='ascii')
                    self.start_process(['cat', str(self.instance / 'trace_pipe')], 'trace.private.log')
                except OSError as exc:
                    self.notes.append('Trace setup: ' + str(exc))
                break
        if self.instance is None:
            self.notes.append('Tracefs unavailable; kernel/uevent/topology capture only.')

    def stop(self):
        if self.instance is not None:
            try:
                (self.instance / 'tracing_on').write_text('0', encoding='ascii')
                stats = {p.parent.name: p.read_text(encoding='utf-8')
                         for p in self.instance.glob('per_cpu/cpu*/stats')}
                write_json(self.out / 'trace-stats.private.json', stats)
            except OSError as exc:
                self.notes.append('Trace stop: ' + str(exc))
        for child in self.children:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=3)
            self.notes.append({'logger_pid': child.pid, 'exit_code': child.returncode})
        for f in self.files:
            f.flush(); os.fsync(f.fileno()); f.close()
        if self.instance is not None:
            try:
                self.instance.rmdir()
            except OSError as exc:
                self.notes.append('Trace instance retained in RAM: ' + str(exc))


def capture():
    if sys.platform != 'linux' or os.geteuid() != 0:
        raise RuntimeError('Capture runs only as root in the prepared Linux live environment.')
    product = Path('/sys/class/dmi/id/product_name').read_text().strip()
    if not supported_product(product):
        raise RuntimeError('This collector is scoped to FA507XI or Latitude5540.')
    import resource
    resource.setrlimit(resource.RLIMIT_FSIZE, (32 * 1024 * 1024, 32 * 1024 * 1024))
    lock = Path('/run/usb4-research-capture.lock')
    with lock.open('x', encoding='ascii') as f:
        f.write(str(os.getpid()))
    out, was_ro = prepare_output()
    logs = Logs(out); samples = []; before = None; result = {'status': 'IncompleteCapture'}
    try:
        write_json(out / 'run.private.json', {'utc': utc(), 'product': product,
                   'kernel': os.uname().release, 'cmdline': Path('/proc/cmdline').read_text(),
                   'collector_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
        logs.start()
        initial = snapshot()
        write_json(out / 'initial.private.json', initial)
        if not any(re.fullmatch(r'\d+-0', n) for n in initial['thunderbolt']):
            raise RuntimeError('Linux exposes no USB4 host router. Results saved; no reconnect requested.')
        preconnected = deg2_usb_present(initial) or bool(external_routers(initial))
        print('\nUSB4 capture. Keep DEG2 powered. Keep barrel power and the boot USB connected.', flush=True)
        if preconnected:
            input('A dock/router is already visible. Leave it connected. Press Enter for a45-second observation: ')
        else:
            input('Leave DEG2 disconnected from this laptop. Press Enter when ready: ')
        before = snapshot()
        if not preconnected and deg2_usb_present(before):
            raise RuntimeError('DEG2 appeared before GREEN; fresh-attachment condition was not established.')
        write_json(out / 'before.private.json', before)
        print('OBSERVING existing connection.' if preconnected else
              'GREEN: connect powered DEG2 to the SAME tested USB4 port now.', flush=True)
        print('Keep it connected. Capture ends automatically after45seconds.', flush=True)
        deadline = time.monotonic() + 45
        with (out / 'samples.private.jsonl').open('w', encoding='utf-8', newline='\n') as f:
            while True:
                state = snapshot(); samples.append(state)
                f.write(json.dumps(state, ensure_ascii=True) + '\n'); f.flush()
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                time.sleep(min(1, remaining))
            os.fsync(f.fileno())
        result = classify(before, samples, preconnected)
    except BaseException as exc:
        result = {'status': 'StoppedRequiresReview', 'error': str(exc),
                  'partial_observation': classify(before, samples) if before else None}
    finally:
        try:
            logs.stop()
        except BaseException as exc:
            result['logging_cleanup_error'] = str(exc)
        try:
            write_json(out / 'result.private.json', result)
            write_json(out / 'logging.private.json', logs.notes)
            hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
            write_json(out / 'manifest.private.json', hashes)
            os.sync()
        finally:
            if was_ro:
                command(['mount', '-o', 'remount,ro', '--', str(BOOT)])
    print('\nRESULT: ' + result['status'])
    print('Private results saved to ' + str(out))
    print('No automatic authorization, role change, retimer scan, firmware operation or reboot was performed.')
    return 0 if result['status'] != 'StoppedRequiresReview' else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true', help='Run only on the prepared live USB')
    args = parser.parse_args()
    if not args.capture:
        print('PREVIEW ONLY. Capture records45seconds of Linux USB4/Type-C/USB/PCIe state and kernel logs.')
        print('Requires prepared USB and local owner interaction. No hardware read or write was performed.')
        return 0
    return capture()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as exc:
        print('STOPPED: ' + str(exc), file=sys.stderr)
        sys.exit(2)
