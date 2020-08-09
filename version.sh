#!/bin/bash

# status of 'B'ranch in 'S'hort format
branch=`git status -b -s | head -n 1`
# get from charpos3, for 6 chars
branch2=${branch:3:6}
version=`git describe --always --abbrev=8`
datestamp=$(expr $(expr $(date +%Y) - 2020) \* 366 + `date +%j`)

echo ${datestamp}-${version} > version.txt

echo $datestamp $version
cat > src/version.vhdl <<ENDTEMPLATE
library ieee;
use Std.TextIO.all;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

package version is

  constant git_version : unsigned(31 downto 0) := x"${version}";
  constant git_date : unsigned(13 downto 0) := to_unsigned(${datestamp},14);

end version;
ENDTEMPLATE
echo "wrote: src/version.vhdl"

