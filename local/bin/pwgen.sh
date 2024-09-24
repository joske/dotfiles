#!/bin/bash

if [ $# -eq 1 ]; then
    N=$1
else
    N=8
fi
head -c 10000 /dev/urandom | strings | grep '^[a-zA-Z0-9]*$' | tr -d '\n' | cut -c 1-$N
