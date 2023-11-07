#!/bin/bash

ip address show eth0 | grep '192.168' | awk '{print $2}' | cut -f1 -d'/'
