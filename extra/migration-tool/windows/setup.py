import sys
sys.path += ['./common', './adsync', './export']

from distutils.core import setup
import py2exe

setup(console=['adsync/zentyal-pwdsync-hook', 'adsync/zentyal-pwdsync-service'])

setup(
    name = 'zentyal-migration',
    description = 'Zentyal Migration Tool',
    version = '2.2',

    windows = [
                  {
                      'script': 'gui/zentyal-migration',
                      'icon_resources': [(1, 'gui/zentyal.ico')],
                  }
              ],

    options = {
                  'py2exe': {
                      'packages': 'Crypto.Cipher.AES, ctypes, encodings, yaml, util, dhcp, dns',
                      'includes': 'cairo, pango, pangocairo, atk, gobject, gio',
                  }
              },

    data_files = [ 'gui/migration.xml', 'gui/zentyal-logo.png', 'export/getsid.vbs' ]
)
