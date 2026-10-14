# make hazard3   flatten the Hazard3 sources into rtl/hazard3.v
# make asm       build asm/smoke.elf
# make sim       run asm/smoke.elf on hazard3_top in Verilator (5.x)
#
# Tool and checkout locations default to PATH and a sibling Hazard3 clone.
# Put anything specific to your machine in local.mk (not committed):
#
#   HAZARD3   = /path/to/Hazard3
#   VERILATOR = /path/to/verilator/bin/verilator
#   CROSS     = /path/to/riscv64-unknown-elf-

-include local.mk
HAZARD3 ?= ../Hazard3

.PHONY: hazard3 asm sim

hazard3:
	python3 -I scripts/flatten.py $(HAZARD3)/hdl > rtl/hazard3.v

asm:
	$(MAKE) -C asm

sim:
	$(MAKE) -C sim
