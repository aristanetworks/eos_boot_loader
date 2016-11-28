#!/bin/bash

pushd boot_installer > /dev/null
./clean.sh
popd > /dev/null

pushd boot_loader > /dev/null
./clean.sh
popd > /dev/null
