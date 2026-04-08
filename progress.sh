#!/usr/bin/env bash

cleanup_progress() {
  :
}

progress_init() {
  :
}

progress_tick() {
  :
}

progress_finish() {
  :
}

if [ "${DJPT_PROGRESS_AUTO_TRAP:-0}" = "1" ]; then
  trap cleanup_progress EXIT
fi
