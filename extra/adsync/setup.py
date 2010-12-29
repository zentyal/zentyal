from distutils.core import setup
import py2exe

setup(console=['ebox-pwdsync-hook','ebox-pwdsync-service'],
      windows=['zentyal-enable-hook'])
