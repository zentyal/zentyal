zoctools
========

Build dependencies
==================

    - libjson0-dev >= 0.9
    - librabbitmq-dev >= 0.4.1
    - libpopt-dev >= 1.16
    - libocpf >= 2.0
    - libmapi-dev >= 2.0

Runtime dependencies
====================

    - libjson0
    - librabbitmq1
    - libpopt0
    - libocpf0
    - libmapi0
    - libmapiproxy0

How to build zoctools:
======================
    $ ./bin/waf configure
    $ ./bin/waf build

Binaries are in build/src/
