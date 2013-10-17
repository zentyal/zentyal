zentyal-exchange
================

Build dependencies
==================

    - libdbus-1-dev
    - libpopt-dev
    - libmapi-dev >= 2.0

Runtime dependencies
====================

    - libpopt0
    - libdbus-1-3
    - libmapi0
    - libmapiproxy0

How to build exchange-tools:
============================
	$ ./bin/waf configure
	$ ./bin/waf build

Binaries are in build/src/
