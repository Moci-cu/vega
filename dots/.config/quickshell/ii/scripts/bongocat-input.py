#!/usr/bin/env python3
"""Read keyboard activity locally; emit paw bits only, never keycodes or text."""
import os
from pathlib import Path
import selectors
import struct
import sys
import time

EVENT = struct.Struct("@llHHi")
# Same physical-hand mapping as wayland-bongocat (see assets/bongocat/LICENSE).
LEFT = {1, 2, 3, 4, 5, 6, 7, 15, 16, 17, 18, 19, 20, 29, 30,
        31, 32, 33, 34, 41, 42, 44, 45, 46, 47, 48, 56, 58, 125}


def paw_events(data):
    paws = 0
    for _, _, kind, code, value in EVENT.iter_unpack(data):
        if kind == 1 and value in (1, 2) and 0 < code < 256:
            paws |= 1 if code in LEFT else 2
    return paws


def keyboards():
    for device in Path("/sys/class/input").glob("event*"):
        try:
            bits = int((device / "device/capabilities/key").read_text().replace(" ", ""), 16)
            if all(bits & (1 << key) for key in (16, 30, 44, 57)):
                yield "/dev/input/" + device.name
        except (OSError, ValueError):
            continue


def monitor():
    selector = selectors.DefaultSelector()
    devices = {}
    next_scan = 0
    last_status = None
    try:
        while True:
            if time.monotonic() >= next_scan:
                for path in keyboards():
                    if path in devices:
                        continue
                    try:
                        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
                    except OSError:
                        continue
                    devices[path] = fd
                    selector.register(fd, selectors.EVENT_READ, path)
                status = "ready" if devices else "unavailable"
                if status != last_status:
                    print(status, flush=True)
                    last_status = status
                next_scan = time.monotonic() + 5
            paws = 0
            for key, _ in selector.select(max(0, next_scan - time.monotonic())):
                try:
                    data = os.read(key.fd, EVENT.size * 64)
                    if not data:
                        raise OSError("disconnected")
                    paws |= paw_events(data)
                except BlockingIOError:
                    continue
                except OSError:
                    selector.unregister(key.fd)
                    os.close(devices.pop(key.data))
                    next_scan = 0
            if paws:
                print(paws, flush=True)
    finally:
        for fd in devices.values():
            os.close(fd)
        selector.close()


def self_test():
    def event(kind, code, value):
        return EVENT.pack(0, 0, kind, code, value)
    assert paw_events(event(1, 30, 1)) == 1
    assert paw_events(event(1, 36, 2)) == 2
    assert paw_events(event(1, 30, 1) + event(1, 36, 1)) == 3
    assert paw_events(event(1, 30, 0) + event(0, 0, 0) + event(1, 272, 1)) == 0
    print("PASS: left/right/both, repeat, releases and mouse filtering")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        monitor()
