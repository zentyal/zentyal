#!/usr/bin/env python
# encoding: utf-8

top = '.'
build = 'build'

APPNAME = 'ZentyalMigration'
VERSION = '0.9'

def options(ctx):
    ctx.load('compiler_c')

def configure(ctx):
    ctx.recurse('src')
    ctx.write_config_header('config.h')

def build(ctx):
        ctx.recurse('src')
