# make -C sim    runs asm/smoke.elf on hazard3_top in Verilator (5.x)
-include ../local.mk
CROSS     ?= riscv64-unknown-elf-
VERILATOR ?= verilator
AXI       := ../dependencies/std/axi_if/axi_pkg.sv ../dependencies/std/axi_if/axi_if.sv
SV        := ../dependencies/hns/src/ahb2axi.sv ../rtl/hazard3_top.sv

run: obj_dir/Vtb smoke.hex
	obj_dir/Vtb

obj_dir/Vtb: tb.sv $(SV)
	$(VERILATOR) --binary --timing -Wno-fatal -Wno-lint -Wno-style \
		--top-module tb tb.sv $(AXI) $(SV)

$(SV): ../rtl/hazard3_top.veryl ../rtl/hazard3.v ../Veryl.lock
	cd .. && veryl build

smoke.hex: ../asm/smoke.elf
	$(CROSS)objcopy -O binary $< smoke.bin
	python3 -I -c "import sys; b = open('smoke.bin', 'rb').read(); b += bytes(-len(b) % 4); \
	print('\n'.join('%08x' % int.from_bytes(b[i:i + 4], 'little') for i in range(0, len(b), 4)))" > $@

clean:
	rm -rf obj_dir smoke.bin smoke.hex
