#!/usr/bin/env python3
"""Writes Hazard3 and its Debug Module as one Verilog file, with every
`include expanded.

The harness reads the core through `include(inline, ...)` in a Veryl source,
and synthesis gets no include path, so the include files are pasted in place.
Macros and `ifdef are left as they are. An include that does not exist is
kept as a line: Hazard3 has one, under an `ifdef for formal checks only.

    scripts/flatten.py <Hazard3 checkout>/hdl > src/hazard3.v   (or: make hazard3)
"""
import pathlib
import re
import subprocess
import sys

INCLUDE = re.compile(r'^\s*`include\s+"([^"]+)"')


def expand(path, inc_dir, out):
    for line in path.read_text().splitlines():
        m = INCLUDE.match(line)
        if m and (inc_dir / m.group(1)).exists():
            expand(inc_dir / m.group(1), inc_dir, out)
        elif m:
            print(f"kept: {path.name}: {line.strip()}", file=sys.stderr)
            out.append(line)
        else:
            out.append(line)


def main():
    hdl = pathlib.Path(sys.argv[1]).resolve()
    # The core, then the Debug Module. The DM's list also names an AHB shim
    # for system bus access, which hazard3_top does not use.
    lists = ["hazard3.f", "debug/dm/hazard3_dm.f"]
    files = []
    for name in lists:
        base = (hdl / name).parent
        files += [base / l.split()[1] for l in (hdl / name).read_text().splitlines()
                  if l.startswith("file ")]
    rev = subprocess.run(["git", "-C", str(hdl), "rev-parse", "--short", "HEAD"],
                         capture_output=True, text=True).stdout.strip()
    out = [f"// Hazard3 ({rev}), {' and '.join('hdl/' + n for n in lists)}"
           " with every `include expanded.",
           "// Written by scripts/flatten.py. Do not edit."]
    for f in files:
        out.append(f"// ---- {f.relative_to(hdl)}")
        expand(f, hdl, out)
    print("\n".join(out))


main()
