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

# make -C sim picoruby    runs picoruby/picoruby.elf (make -C picoruby first)
# and prints its RTT console. Slow: the program boots, then sleeps for a second.
PICO      = ../picoruby/picoruby.elf
PICO_CROSS ?= riscv32-unknown-elf-
HEXPY     = import sys; b = open(sys.argv[1], 'rb').read(); b += bytes(-len(b) % 4); \
	print('\n'.join('%08x' % int.from_bytes(b[i:i + 4], 'little') for i in range(0, len(b), 4)))

picoruby: obj_dir/Vtb_picoruby $(PICO)
	$(PICO_CROSS)objcopy -O binary -j .head $(PICO) picoruby_tcm.bin
	$(PICO_CROSS)objcopy -O binary -j .text -j .rodata -j .data $(PICO) picoruby_dmem.bin
	python3 -I -c "$(HEXPY)" picoruby_tcm.bin > picoruby_tcm.hex
	python3 -I -c "$(HEXPY)" picoruby_dmem.bin > picoruby_dmem.hex
	obj_dir/Vtb_picoruby $(PICO_ARGS) +cb=$$($(PICO_CROSS)nm $(PICO) | awk '$$3 == "cb" {print $$1}')

obj_dir/Vtb_picoruby: tb_picoruby.sv $(SV)
	$(VERILATOR) --binary --timing -Wno-fatal -Wno-lint -Wno-style \
		--top-module tb --Mdir obj_dir_picoruby -o Vtb_picoruby \
		tb_picoruby.sv $(AXI) $(SV)
	mkdir -p obj_dir && cp obj_dir_picoruby/Vtb_picoruby obj_dir/Vtb_picoruby

.PHONY: picoruby
