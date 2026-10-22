#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Configure and build NuttX for Hazard3 on run-hazard3.
#
#   NUTTX_DIR   the NuttX checkout (required)
#   NUTTX_APPS  the nuttx-apps checkout, relative to NUTTX_DIR (default ../apps)
#   CONFIG      board configuration (default nsh)
#
# Needs riscv32-unknown-elf-gcc on PATH, and a Kconfig frontend: kconfiglib
# (pip install --user kconfiglib) or kconfig-frontends, with kconfig-tweak.
# The ELF is left at $NUTTX_DIR/nuttx.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
NUTTX_DIR="${NUTTX_DIR:?set NUTTX_DIR to the NuttX checkout}"
NUTTX_APPS="${NUTTX_APPS:-../apps}"
CONFIG="${CONFIG:-nsh}"

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "build.sh: $1 not found on PATH" >&2; exit 1; }
}

need riscv32-unknown-elf-gcc
need kconfig-tweak
command -v olddefconfig >/dev/null 2>&1 || command -v kconfig-conf >/dev/null 2>&1 || {
    echo "build.sh: neither kconfiglib (olddefconfig) nor kconfig-frontends found" >&2
    exit 1
}

# The defconfig names the chip and board directories, which depend on where
# this repository is. Write a copy with the real path into build/, next to
# the Make.defs that configure.sh looks for beside it.
GEN="$HERE/build/$CONFIG"
mkdir -p "$GEN"
sed "s|@HERE@|$HERE|g" "$HERE/boards/run-hazard3/configs/$CONFIG/defconfig" > "$GEN/defconfig.new"
ln -sf "$HERE/boards/run-hazard3/scripts/Make.defs" "$GEN/Make.defs"

cd "$NUTTX_DIR"

# Fixes this port needs until NuttX itself has them. Each is applied once:
# one already in the tree is skipped.
for p in "$HERE"/patches/*.patch; do
    [ -e "$p" ] || continue
    if git apply --reverse --check "$p" 2>/dev/null; then
        continue
    fi
    git apply "$p" || {
        echo "build.sh: $(basename "$p") does not apply to $NUTTX_DIR." >&2
        echo "If this NuttX already has the fix in another form, delete the patch." >&2
        exit 1
    }
    echo "build.sh: applied $(basename "$p")"
done

# A .config that exists is not necessarily a finished one: configure.sh leaves
# it behind when it fails part way. The chip symbol only appears once the
# Kconfig passes below have run, so test for that. Reconfigure when the
# defconfig changed too.
if ! grep -q '^CONFIG_ARCH_CHIP_RUN_HAZARD3=y' .config 2>/dev/null ||
   ! cmp -s "$GEN/defconfig.new" "$GEN/defconfig"; then
    mv "$GEN/defconfig.new" "$GEN/defconfig"
    rm -f .config .config.backup Make.defs .dirlinks
    ./tools/configure.sh -a "$NUTTX_APPS" "$GEN"

    # configure copies the chip and board Kconfig to arch/dummy/Kconfig and
    # boards/dummy/Kconfig before .config exists, so an out-of-tree chip's
    # Kconfig is not picked up. Copy again once .config names the custom
    # chip, and again until the symbols it selects (ARCH_RV32, ...) exist.
    for pass in 1 2; do
        rm -f arch/dummy/Kconfig boards/dummy/Kconfig
        make olddefconfig
    done
    rm -f .dirlinks
else
    rm -f "$GEN/defconfig.new"
fi

make -j"$(nproc)"
