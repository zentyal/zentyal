#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (C) 2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
"""
Set package info to a crash report from apport.

Package and Dependencies field are set
"""
from apport.report import Report
from apport.packaging_impl import impl as packaging
import optparse
import os
import re


def parse_options():
    """
    Parse command line options
    """
    optparser = optparse.OptionParser('%prog [-h] DIR_FILE')

    (opts, args) = optparser.parse_args()

    return (opts, args)


def run(target):
    if not os.path.isfile(target):
        raise SystemError("%s is not a file" % target)

    report = Report()
    with open(target, 'rb') as f:
        try:
            report.load(f)
        except Exception as exc:
            raise SystemError("Cannot load file %s: %s" % (target, exc))

        additional_deps = ""
        if 'ExecutablePath' in report and re.search('samba', report['ExecutablePath']):
                for pkg_name in ('openchangeserver', 'openchange-rpcproxy', 'openchange-ocsmanager',
                                 'sogo-openchange'):
                    try:
                        packaging.get_version(pkg_name)
                        report.add_package_info(pkg_name)
                        if additional_deps:
                            additional_deps += '\n'
                        additional_deps += report['Package'] + "\n" + report['Dependencies']
                    except ValueError:
                        # This package is not installed
                        pass

        # Add executable deps
        report.add_package_info()
        if additional_deps:
            report['Dependencies'] += '\n' + additional_deps
            report['Dependencies'] = '\n'.join(sorted(set(report['Dependencies'].split('\n'))))

        with open(target, 'wb') as f:
            report.write(f)


if __name__ == '__main__':
    (opts, args) = parse_options()
    run(args[0])
