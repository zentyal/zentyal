from distutils.core import setup
import py2exe

setup(console=['zentyal-pwdsync-hook', 'zentyal-pwdsync-service'],
      windows=['zentyal-enable-hook'])

setup(
    name = 'zentyal-migration',
    description = 'Zentyal Migration Tool',
    version = '2.2',

    windows = [
                  {
                      'script': 'zentyal-migration',
                      'icon_resources': [(1, "zentyal.ico")],
                  }
              ],

    options = {
                  'py2exe': {
                      'packages': 'encodings',
                      'includes': 'cairo, pango, pangocairo, atk, gobject, gio',
                  }
              },

    data_files = [ 'migration.xml' ]
)
