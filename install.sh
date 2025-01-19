#!/bin/sh

sudo apt update
sudo apt install git build-essential make gcc net-tools -y
git clone "https://github.com/z3APA3A/3proxy.git"
cd 3proxy
make -f Makefile.Linux
sudo make install
    

