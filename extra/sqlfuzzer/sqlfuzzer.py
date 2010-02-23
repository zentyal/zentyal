#!/usr/bin/python

import os
import sys
import yaml
import types
import random
from mx import DateTime
import psycopg2

def create_choice_generator(f):
    choice = f['choice']
    weights = [c['weight'] for c in choice]
    total_chances = sum(weights)

    def choice_generator():
        val = random.randint(0, total_chances-1)
        for i, w in enumerate(weights):
            val = val - w
            if val < 0:
                return choice[i]['value']

    return choice_generator

def create_integer_generator(f):
    begin = 0
    end = 65535

    if f.has_key('begin'):
        begin = f['begin']
    if f.has_key('end'):
        end = f['end']

    def integer_generator():
        return random.randint(begin, end)

    return integer_generator

def create_ip_generator(f):
    def ip_generator():
        return ".".join([str(random.randint(1,255)) for i in range(4)])

    return ip_generator

def create_timestamp_generator(f):
    begin = f['begin']
    end = f['end']

    (byear, bmonth, bday) = begin.split('-')
    (eyear, emonth, eday) = end.split('-')
    bticks = DateTime.DateTime(int(byear), int (bmonth), int(bday)).ticks()
    eticks = DateTime.DateTime(int(eyear), int (emonth), int(eday)).ticks()

    def timestamp_generator():
        ticks = random.randint(bticks, eticks)
        d = DateTime.DateTimeFromTicks(ticks)
        return d.strftime("%Y-%m-%d %H:%M:%S")

    return timestamp_generator

def create_random_generator(f):
    type = f['type']

    if type == 'int':
        return create_integer_generator(f)
    elif type == 'ip_addr':
        return create_ip_generator(f)
    elif type == 'timestamp':
        return create_timestamp_generator(f)
    else:
        return ''

def create_generator(f):
    if f.has_key('value'):
        return f['value']
    elif f.has_key('choice'):
        return create_choice_generator(f)
    else:
        return create_random_generator(f)

db = psycopg2.connect("dbname=eboxlogs user=postgres")

st = db.cursor()

stream = file(sys.argv[1], 'r')
num = int(sys.argv[2])
table_info = yaml.load(stream)

table = table_info['table']
fields = table_info['fields']

names = [f['name'] for f in fields]
generators = [create_generator(f) for f in fields]

for i, n in enumerate(names):
    if type(generators[i]) == types.FunctionType:
        value = str(generators[i]())
    else:
        value = str(generators[i])
    print "%s: %s" % (n, value)

placeholders = ", ".join(["%s" for i in names])
query = 'INSERT INTO %s VALUES ( %s )' % (table, placeholders)

print query
value_array = []
for i in range(num):
    values = []
    for g in generators:
        if type(g) == types.FunctionType:
            values.append(str(g()))
        else:
            values.append(str(g))
    value_array.append(values)

    if len(value_array) == 1000:
        print i
        value_array = []
        st.executemany(query, value_array)
        db.commit()

if len(value_array) != 0:
    st.executemany(query, value_array)
    db.commit()

st.close()
db.close()
