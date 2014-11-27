########################################################################
## Samples Makefile to use with wbgen2 tool
##
## 	To use the desired output you just need to add them under the "all"
## target. (i,e. we generate vhdl and html output by default)
##
## Authors:
##	- Benoit Rat (Seven Solutions, www.sevensols.com)
##
## GNU Lesser General Public License Usage
## This file may be used under the terms of the GNU Lesser
## General Public License version 2.1 as published by the Free Software
## Foundation and appearing in the file LICENSE.LGPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU Lesser General Public License version 2.1 requirements
## will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
########################################################################

WBINPUT = $(wildcard *.wb)

## Main target
all: vhd html

## Targets creation
vhd: $(WBINPUT:.wb=.vhd)
html: $(WBINPUT:.wb=.html)
db: $(WBINPUT:.wb=.db)
header: $(WBINPUT:.wb=.h)
tex: $(WBINPUT:.wb=.tex)
pkg: $(WBINPUT:.wb=_pkg.vhd)

## Outputs generation
%.vhd: %.wb
	wbgen2 --lang vhdl  --vo=$@ $<

%.h: %.wb
	wbgen2 --cstyle=header  --co=$@ $<
	sed -i 's,#include <inttypes.h>,#ifdef __KERNEL__\n#include <linux/types.h>\n#else\n#include <stdint.h>\n#endif\n,' $@
	sed -i '/ Created *: .*20[0-9][0-9]$$/ d' $@
	sed -i 's/-REGS_WB//' $@

%.html: %.wb
	wbgen2 --docformat=html --doco=$@ $<

%.tex: %.wb
	wbgen2 --docformat=latex --docu=$@ $<
	
%_pkg.vhd: %.wb
	wbgen2 --vo=$*.vhdl --vpo=$@ --hstyle=record $<

## Cleaning
clean:
	rm $(WBINPUT:.wb=.vhd) $(WBINPUT:.wb=.html) $(WBINPUT:.wb=.db) $(WBINPUT:.wb=.h)
