# heavy SECONDS CMD..: one heavy command, alone under the shared lock, capped at 5120 MB
# (the memory rules of 2026-11-23); bun emits get BUN_JSC_forceRAMSize.
heavy() {
  local s=$1; shift
  until [ -x ~/Software/supgen-bend/limit ]; do sleep 1; done
  BUN_JSC_forceRAMSize=3000000000 lockf /private/tmp/bend-opt/timing.lock ~/Software/supgen-bend/limit $s 5120 "$@"
}
