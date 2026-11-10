#!/bin/sh
# Fetch the exact Infineon library versions this firmware was built with
# (no ModusToolbox install needed). Creates ./mtb_shared next to build.py.
set -e
cd "$(dirname "$0")"
mkdir -p mtb_shared && cd mtb_shared
get() { [ -d "$2" ] || git -c advice.detachedHead=false clone -q --depth 1 -b "$3" "https://github.com/$1/$2" "$2"; echo "  $2 $3"; }
get cypresssemiconductorco freertos          release-v10.6.202
get cypresssemiconductorco abstraction-rtos  release-v1.13.0
get Infineon               cat1cm0p          release-v1.11.0
get cypresssemiconductorco clib-support      release-v1.8.0
get Infineon               cmsis             release-v6.1.0
get cypresssemiconductorco core-lib          release-v1.7.0
get cypresssemiconductorco mtb-pdl-cat1      release-v3.23.0
get Infineon               usbfxstack        release-v1.3.4
