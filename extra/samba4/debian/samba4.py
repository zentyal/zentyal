#!/usr/bin/python

from apport.hookutils import *
import apport.packaging

def add_info(report, ui):
    attach_file(report, '/etc/samba/smb.conf')
