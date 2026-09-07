# ISA scope and known limitations

Compile controlled bare-metal code using **`-march=rv32i -mabi=ilp32`**. The
implementation is an RV32I integer datapath demonstrator, not a certified or
fully compliant RV32I execution environment. The project name expresses the
RV32IM + AXI development direction.

| Group | Implemented datapath operations | Verification / limit |
| --- | --- | --- |
| Upper immediates | LUI, AUIPC | Baseline checks |
| Register ALU | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND | Baseline plus six seeded programs |
| Immediate ALU | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI | Signed/unsigned and shift edge cases |
| Loads | LB, LH, LW, LBU, LHU | All byte lanes; both aligned halfword lanes |
| Stores | SB, SH, SW | Neighbor-lane preservation and forwarding |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU | Taken/not-taken predicates and backward loop |
| Jumps | JAL, JALR | Call/return, link value, odd JALR bit-zero clearing |
| Ordering / system | No FENCE, ECALL, EBREAK trap implementation | No complete architectural exception environment |
| M extension | No MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU | Planned only |
| Other extensions | No C, A, floating point, vector, Zicsr or privileged ISA | No interrupts, MMU or OS support |

## Decode and execution caveats

- The `illegal` decoder output is wired inside the core but never used to raise
  an exception. Unsupported opcodes generally clear controls, but reserved
  encodings within recognized opcodes are not comprehensively rejected.
- `OP_REG` does not validate the complete `funct7` field. In particular, an
  M-extension encoding can execute an ordinary ALU operation with the wrong
  meaning instead of trapping. Compiling with `-march=rv32im` is incorrect.
- Misaligned halfword/word accesses and misaligned instruction targets are not
  trapped. Software must use naturally aligned accesses and four-byte instruction
  targets. Cross-word misaligned accesses are not implemented.
- There is no bus error response, privilege separation, CSR state, or precise
  exception mechanism.
- Scratch RAM address decoding wraps via index truncation; the MMIO decode also
  aliases. See the [memory map](MEMORY_MAP.md).
- The pipeline has no retirement-valid trace suitable for architectural lockstep
  checking. Current tests check selected results and externally visible effects.

The official [RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html)
is the architectural reference. The official
[M-extension specification](https://docs.riscv.org/reference/isa/v20240411/unpriv/m-st-ext.html)
defines the future multiply/divide behavior. Those references specify what a
complete implementation should do; they do not certify this core.
