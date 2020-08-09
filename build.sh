export DIAMONDDIR=/usr/local/diamond/3.10_x64
export TEMP=/tmp
export LSC_INI_PATH=""
export LSC_DIAMOND=true
export TCL_LIBRARY=${DIAMONDDIR}/tcltk/lib/tcl8.4
export FOUNDRY=/usr/local/lscc/diamond/1.3/ispFPGA
export PATH=$FOUNDRY/bin/nt:$PATH
./version.sh
${DIAMONDDIR}/bin/lin64/diamondc build.tcl | tee build.log

tar zcvf mega65-kbd-cpld-`cat version.txt`.tgz impl1
