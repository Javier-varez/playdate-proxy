#!/usr/bin/env python3

import serial
import code
import os
import sys
import subprocess
import pathlib
import time
import platform
import base64
import struct
import readline
from pwnlib import asm

def getOs():
    return platform.system()

class DarwinPlatform():
    SERIAL_DEVS_PATH = '/dev'

    def find_serial_dev_paths(self):
        return [self.SERIAL_DEVS_PATH + os.sep + entry for entry in os.listdir(self.SERIAL_DEVS_PATH) if str(entry).startswith('tty.usbmodemPDU1')]

    def eject(self, dev_path):
        os.system(f'diskutil eject {dev_path}')

    def wait_for_mount(self):
        while True:
            out = subprocess.run(f'mount', capture_output = True, encoding='UTF-8')
            mount_entries = [line for line in out.stdout.splitlines() if 'PLAYDATE' in line]
            if len(mount_entries) == 1:
                dev, _, mount_path, _ = mount_entries[0].split(' ', maxsplit=3)
                return (pathlib.PurePath(dev), pathlib.PurePath(mount_path))
            if len(mount_entries) > 1:
                raise Exception(f"Found more than one playdate mounted: {mount_entries}")
            time.sleep(0.1)

class LinuxPlatform():
    SERIAL_DEVS_PATH = '/dev/serial/by-id'

    def find_serial_dev_paths(self):
        return [self.SERIAL_DEVS_PATH + os.sep + entry for entry in os.listdir(self.SERIAL_DEVS_PATH) if str(entry).startswith('usb-Panic_Inc_Playdate')]

    def eject(self, dev_path):
        os.system(f'sudo  eject {dev_path}')

    def wait_for_mount(self):
        while True:
            out = subprocess.run(f'mount', capture_output = True, encoding='UTF-8')
            mount_entries = [line for line in out.stdout.splitlines() if 'PLAYDATE' in line]
            if len(mount_entries) == 1:
                dev, _, mount_path, _ = mount_entries[0].split(' ', maxsplit=3)
                return (pathlib.PurePath(dev), pathlib.PurePath(mount_path))
            if len(mount_entries) > 1:
                raise Exception(f"Found more than one playdate mounted: {mount_entries}")
            time.sleep(0.1)

class Proxy():
    DEFAULT_DEV_PATH = '/dev/serial/by-id/usb-Panic_Inc_Playdate_PDU1-Y072089-if00'

    def __init__(self, platform):
        self.platform = platform

        serial_paths = platform.find_serial_dev_paths()
        if len(serial_paths) == 0:
            raise Exception(f'Playdate serial device is not active')
        if len(serial_paths) > 1:
            raise Exception(f'Found more than one Playdate device: {serial_paths}')
        self.serial_path = serial_paths[0]

        self.dev = serial.Serial(self.serial_path, 115200, exclusive=True)
        self.dev.flushOutput()
        self.dev.flushInput()
        self.dev.timeout = 1

    def reopen(self):
        """ Reconnects the serial device """
        self.dev.close()
        print("Waiting for reconnection... ", end="")
        sys.stdout.flush()
        for i in range(100):
            print(".", end="")
            sys.stdout.flush()
            try:
                self.dev.open()
            except serial.serialutil.SerialException:
                time.sleep(0.1)
            else:
                break
        else:
            raise Exception("Reconnection timed out")
        print(" Connected")

    def _mount_data(self):
        """ Mounts the playdate data disk """
        self.dev.write(b'datadisk\r\n')
        self.dev.readline() # discard echo

        dev_path, mount_path = self.platform.wait_for_mount()
        print(f'Playdate data disk was found at {dev_path}, and it is mounted at {mount_path}')
        return dev_path, mount_path

    def mount_data(self):
        """ Mounts the playdate data disk """
        self._mount_data()

    def eject_disk(self):
        """ Ejects the playdate disk """
        dev_path, _ = self.platform.wait_for_mount()
        self.platform.eject(dev_path)

    def rg(self):
        """ Runs playdate-proxy """
        self.dev.write(b'run /Games/playdate-proxy.pdx\r\n')
        self.dev.readline() # Discard echo

    def lg(self):
        """ loads playground-proxy and runs it """
        self.load_game('./zig-out/playdate-proxy.pdx')
        self.rg()

    def load_game(self, game):
        """ loads the given game to the playdate """
        dev_path, mount_path = self._mount_data()

        dest = mount_path / 'Games' / os.path.basename(game)
        print(f'loading {game} to {dest}')

        os.system(f'rm -r {dest}')
        os.system(f'cp -r {game} {dest}')

        self.platform.eject(dev_path)
        self.reopen()

    def gc(self, clear = False):
        """ Obtains the crashlog """
        dev_path, mount_path = self._mount_data()

        crashlog = mount_path / 'crashlog.txt'
        errorlog = mount_path / 'errorlog.txt'

        has_crashlog = True
        try:
            with open(crashlog, 'r') as f:
                print(f.read())
        except:
            print("No crashlog found")
            has_crashlog = False

        has_errorlog = True
        try:
            with open(errorlog, 'r') as f:
                print(f.read())
        except:
            print("No errorlog found")
            has_errorlog = False

        if clear and has_crashlog:
            os.unlink(crashlog)
        if clear and has_errorlog:
            os.unlink(errorlog)

        self.platform.eject(dev_path)
        self.reopen()
        self.rg()

    def api(self, section, name, l = 0x40):
        """ Reads the code for the requested playdate api """
        length = base64.standard_b64encode(struct.pack("<I", l)).decode('UTF-8')

        cmd = f'msg api {length} {section} {name}\r\n'

        self.dev.write(cmd.encode('UTF-8'))
        self.dev.readline() # discard the echo

        response = self.dev.readline().decode('UTF-8')

        if response.startswith("Err: "):
            raise Exception(response)

        encoded_vma, encoded_data = response.split(' ')
        vma, = struct.unpack("<I", base64.standard_b64decode(encoded_vma))
        data = base64.standard_b64decode(encoded_data)

        print(asm.disasm(data, vma = vma, arch='thumb'))

    def _hexdump(self, addr, data):
        bytes_per_line = 16
        num_lines = (len(data) + bytes_per_line - 1) // bytes_per_line
        for l in range(num_lines):
            print(f'{addr + l * bytes_per_line:08x}  ' , end = '')
            for b in range(l * bytes_per_line, min((l + 1) * bytes_per_line, len(data))):
                if b % bytes_per_line == bytes_per_line // 2:
                    print(' ', end = '')
                print(f'{data[b]:02x} ', end = '')
            print('')

    def _memdump(self, addr, l):
        addr = base64.standard_b64encode(struct.pack("<I", addr)).decode('UTF-8')
        l = base64.standard_b64encode(struct.pack("<I", l)).decode('UTF-8')
        self.dev.write(f'msg memdump {addr} {l}\r\n'.encode('UTF-8'))
        self.dev.readline() # discard the echo

        encoded_data = self.dev.readline()
        return base64.standard_b64decode(encoded_data)

    def m(self, addr, l = 0x40):
        """ Reads bytes at the given address """
        data = self._memdump(addr, l);
        self._hexdump(addr, data)

    def disasm(self, addr, l = 0x40):
        """ Reads bytes at the given address, interpreting it as code """
        data = self._memdump(addr, l);
        print(asm.disasm(data, vma = addr, arch='thumb'))

    def _read_reg(self, size, addr, value_type):
        addr = base64.standard_b64encode(struct.pack("<I", addr)).decode('UTF-8')
        cmd = f'msg r{size} {addr}\r\n'
        self.dev.write(cmd.encode('UTF-8'))
        self.dev.readline() # Get rid of the echo

        encoded_value = self.dev.readline().decode('UTF-8')
        value, = struct.unpack(f"<{value_type}", base64.standard_b64decode(encoded_value))
        return value

    def r8(self, addr):
        """ reads a 8 bit value from memory, at the given address """
        print(f'0x{self._read_reg(8, addr, 'B'):x}')

    def r16(self, addr):
        """ reads a 16 bit value from memory, at the given address """
        print(f'0x{self._read_reg(16, addr, 'H'):x}')

    def r32(self, addr):
        """ reads a 32 bit value from memory, at the given address """
        print(f'0x{self._read_reg(32, addr, 'I'):x}')


    def _write_reg(self, size, addr, value, value_type):
        addr = base64.standard_b64encode(struct.pack("<I", addr)).decode('UTF-8')
        value = base64.standard_b64encode(struct.pack(f"<{value_type}", value)).decode('UTF-8')
        cmd = f'msg w{size} {addr} {value}\r\n'
        self.dev.write(cmd.encode('UTF-8'))
        self.dev.readline() # Get rid of the echo

        response = self.dev.readline().decode('UTF-8');
        if not response.startswith('Ok:'):
            raise Exception(f"Error writting register: {response}")
        print(response)

    def w8(self, addr, value):
        """ writes a 8 bit value to memory, at the given address """
        self._write_reg(8, addr, value, 'B')

    def w16(self, addr, value):
        """ writes a 16 bit value to memory, at the given address """
        self._write_reg(16, addr, value, 'H')

    def w32(self, addr, value):
        """ writes a 32 bit value to memory, at the given address """
        self._write_reg(32, addr, value, 'I')

    def __repr__(self):
        result = ""
        for attr in dir(self):
            if attr.startswith('_'):
                continue

            method = self.__getattribute__(attr)
            if callable(method):
                result = result + f'{attr:<20} {method.__doc__.strip()}' + '\n'

        return result

if __name__ == '__main__':
    print("Running proxy")
    platform = LinuxPlatform() if platform.system() == "Linux" else DarwinPlatform()
    proxy = Proxy(platform)

    def help():
        print(proxy)

    locals = { 'proxy' : proxy, 'help' : help }

    for attr in dir(proxy):
        if attr.startswith('_'):
            continue

        method = proxy.__getattribute__(attr)
        if callable(method):
            locals[attr] = method

    console = code.InteractiveConsole(locals = locals)
    console.interact(banner = "")
