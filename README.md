# mega65-keyboard-cpld

Program for the CPLD in the MEGA65 custom keyboard

## Build

Make sure to edit env.sh to reflect your lattice-diamond installation and
provide a license.dat!

Use `./build.sh` to build the binary and package it.

Use `./program.sh` to program the binary to the keyboard CPLD. Attention!
This requires you to hotwire a JTAG to the keyboard! The keyboard must not
be connected to the MEGA65 mainboard.

Use `./clean.sh` to remove files that where build. Also removes the archive!

