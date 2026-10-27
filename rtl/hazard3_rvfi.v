// Turns on Hazard3's RVFI port outside riscv-formal, so that synthesis keeps
// it too. An `embed` block would not do: Veryl hides it from synthesis.
`define HAZARD3_RVFI_STANDALONE
