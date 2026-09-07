# Contributing and reproducing changes

Start with the [architecture](docs/ARCHITECTURE.md) and [ISA limits](docs/ISA_SUPPORT.md).
Small, testable changes are easiest to review in this CPU/SoC.

1. Explain the concrete behavior or failing instruction/serial sequence.
2. Add a reproducer or extend the relevant regression for functional RTL changes.
3. Run `python sim/run_tests.py` and `python scripts/check_docs.py`.
4. Describe what the tests observe and any remaining limits. Include seed,
   compiler version, source digest and failure log for nondeterministic issues.
5. Update architecture/decision documents when interfaces or tradeoffs change.

Do not commit generated ELF/bin files, simulator executables, large waveforms,
or Gowin implementation directories. A small evidence snapshot can be committed
with a date, source identity, commands and interpretation. Never describe an
unrun test, unconstrained target clock, or older netlist result as a current pass.

For new instructions, review decode legality, x0, signed behavior, forwarding,
load-use interaction, branch recovery and memory side effects. For FPGA memory
changes, explicitly review latency/handshakes and read-during-write semantics.
For loader changes, test both accepted and rejected streams.

Contributions are covered by the repository's existing [MIT license](LICENSE).
