source env.sh
./version.sh
${DIAMONDDIR}/bin/lin64/diamondc build.tcl | tee build.log
cp megakey_impl1.xcf impl1/

tar zcvf mega65-kbd-cpld-`cat version.txt`.tgz impl1
