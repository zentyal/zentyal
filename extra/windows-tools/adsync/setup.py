from distutils.core import setup
import py2exe

setup(console=['zentyal-pwdsync-hook','zentyal-pwdsync-service'],
      windows=['zentyal-enable-hook'])
