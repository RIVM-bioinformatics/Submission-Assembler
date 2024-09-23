#!/bin/bash
# for this environment I need to implement a git repro as well: https://github.com/ruanjue/wtdbg2

mkdir -p wtdbg2
cd wtdbg2
git clone https://github.com/ruanjue/wtdbg2 .
make
cd ..