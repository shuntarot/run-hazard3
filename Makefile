# make hazard3   flatten the Hazard3 sources into src/hazard3.v
# make sw        build sw/smoke.elf
# make sim       run sw/smoke.elf on hazard3_top in Verilator (5.x)
#
# Tool and checkout locations default to PATH and a sibling Hazard3 clone.
# Put anything specific to your machine in local.mk (not committed):
#
#   HAZARD3   = /path/to/Hazard3
#   VERILATOR = /path/to/verilator/bin/verilator
#   CROSS     = /path/to/riscv64-unknown-elf-

-include local.mk
HAZARD3 ?= ../Hazard3

.PHONY: hazard3 sw sim

hazard3:
	python3 -I scripts/flatten.py $(HAZARD3)/hdl > src/hazard3.v

sw:
	$(MAKE) -C sw

sim:
	$(MAKE) -C sim
