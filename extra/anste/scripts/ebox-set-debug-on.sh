#!/bin/bash

sed -i 's/debug.*=.*no/debug = yes/' /etc/ebox/99ebox.conf

sed -i 's/override_user_modification.*=.*no/override_user_modification = yes/' /etc/ebox/99ebox.conf
