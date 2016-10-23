#!/usr/bin/python
import subprocess
import sys

def getSambaProcess():
    ps = subprocess.Popen("ps -U 0", shell=True, stdout=subprocess.PIPE)
    psbuffer = ps.stdout.read()
    ps.stdout.close()
    ps.wait()
    return psbuffer

def main():
    psbuffer = getSambaProcess()
    if not 'samba' in psbuffer:
        return 1

    for line in psbuffer.split('\n'):
        if not 'samba' in line:
            continue
        pid = filter(None, line.split(' '))[0]
        fh = open('/proc/%s/maps' % pid, 'r')
        try:
            map_mem = fh.read()
            if 'dcerpc_mapiproxy' in map_mem:
                return 0
        except (IOError, OSError) as e:
            return -1
        finally:
            fh.close()
    return 1

if __name__ == '__main__':
    sys.exit(main())

