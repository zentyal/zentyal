import sys
sys.path += ['./adsync', './export']

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
                      'packages': 'ctypes, encodings, yaml, dhcp, dns, pdc',
                      'includes': 'cairo, pango, pangocairo, atk, gobject, gio',
                  }
              },

    data_files = [ 'gui/migration.xml' ]
)
