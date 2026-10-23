# mruby/c on run-hazard3: `make` builds picoruby.elf from hello.rb.
#
#   PICORUBY   the PicoRuby checkout (default ../../picoruby)
#   CROSS      toolchain prefix (default riscv32-unknown-elf-)
#
# Needs the toolchain on PATH, and `rake` in PICORUBY for the host mrbc
# (MRUBY_CONFIG=build_config/picorbc.rb rake).
#
#   hio cpu boot picoruby.elf

-include ../local.mk

PICORUBY ?= $(abspath ../../picoruby)
CROSS    ?= riscv32-unknown-elf-
MRBC     ?= $(PICORUBY)/bin/mrbc
SCRIPT   ?= hello.rb

MRUBYC = $(PICORUBY)/mrbgems/picoruby-mrubyc/lib/mrubyc
BUILD  = build

# The core cannot do a misaligned access, and bytecode has unaligned fields.
DEFS   = -DMRBC_REQUIRE_32BIT_ALIGNMENT=1 -DMRBC_SCHEDULER_EXIT=1
ARCH   = -march=rv32im_zicsr_zifencei -mabi=ilp32
CFLAGS = $(ARCH) -Os -g -ffunction-sections -fdata-sections -Wall \
         -I. -Ihal -I$(BUILD)/mrubyc/src -DMRBC_USE_STRING_UTF8=1 $(DEFS)
LDFLAGS = $(ARCH) -nostartfiles -specs=nano.specs -Wl,--gc-sections -Wl,--no-warn-rwx-segments -Wl,-T,link.ld

SRCS = main.c rtt.c sys.c
OBJS = $(addprefix $(BUILD)/, $(SRCS:.c=.o)) $(BUILD)/start.o $(BUILD)/program.o

picoruby.elf: $(OBJS) $(BUILD)/libmrubyc.a link.ld
	$(CROSS)gcc $(LDFLAGS) -o $@ $(OBJS) $(BUILD)/libmrubyc.a -lc -lgcc
	$(CROSS)size $@

$(BUILD)/%.o: %.c $(BUILD)/libmrubyc.a
	@mkdir -p $(dir $@)
	$(CROSS)gcc $(CFLAGS) -c -o $@ $<

$(BUILD)/start.o: start.S
	@mkdir -p $(BUILD)
	$(CROSS)gcc $(ARCH) -c -o $@ $<

# The script, compiled to bytecode on the host.
$(BUILD)/program.c: $(SCRIPT)
	@mkdir -p $(BUILD)
	$(MRBC) -B program -o $@ $<
$(BUILD)/program.o: $(BUILD)/program.c
	$(CROSS)gcc $(CFLAGS) -c -o $@ $<

# mruby/c itself, with the HAL of this directory. It builds in a copy of its
# source, because it writes generated headers beside it.
$(BUILD)/libmrubyc.a: hal/hal.h hal/hal.c rtt.h
	@mkdir -p $(BUILD)/mrubyc
	cp -r $(MRUBYC)/src $(MRUBYC)/support $(MRUBYC)/mrblib $(BUILD)/mrubyc/
	mkdir -p $(BUILD)/mrubyc/hal && cp hal/hal.h hal/hal.c $(BUILD)/mrubyc/hal/ && cp rtt.h $(BUILD)/mrubyc/
	CFLAGS="$(ARCH) -Os -ffunction-sections -fdata-sections $(DEFS)" \
	  $(MAKE) -C $(BUILD)/mrubyc/src MRBC_USE_HAL=../hal \
	  MRBC_USE_STRING_UTF8=1 CC=$(CROSS)gcc AR=$(CROSS)ar
	cp $(BUILD)/mrubyc/build/libmrubyc.a $@

clean:
	rm -rf $(BUILD) picoruby.elf

.PHONY: clean
