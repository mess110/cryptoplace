#!/usr/bin/env sh

# https://en.bitcoin.it/wiki/Running_Bitcoin
bitcoind -datadir=../wallet -prune=2048 -rpcuser=user -rpcpassword=password
