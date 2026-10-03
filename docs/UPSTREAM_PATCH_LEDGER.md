# Upstream patch ledger

Direct edits to `RahvinGS/` and `Sample Job Files/` are class-C patches and must be recorded here with their reason, conflict risk, protecting test, and removal condition.

## Current patches

None.

Phase 1 and the independently re-audited Phase 2 leave all upstream product files under
`RahvinGS/` and `Sample Job Files/` unchanged. The Phase 2 audit diff from
`d973c5100be358215ab24574cfaf3469b839a71c` through executable verification commit
`bdd8e339ef18c709410883ca53ceb49d4abd25b8` contains only `ashita/` and `tests/` changes.

Phase 3 remains upstream-clean as well. Comparing the approved Phase 2 endpoint
`5fc56b35470e58717f82c1f0208a82ec2ec45ab1` to the Phase 3 automated verification
commit `8307ab47c7e4716b41398b5d4b4619ed0b450073` shows only `ashita/`, `compat/` and
`tests/` changes. No file under `RahvinGS/` or `Sample Job Files/` changed, so Phase 3
adds no class-C patch.
