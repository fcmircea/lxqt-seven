#!/bin/bash
# Snapshot desktop-session resource use, for comparing Plasma vs LXQt.
# Usage: de-measure.sh [label]   -> appends a report to ~/de-measure.log and prints it
# Run it ~1 minute after login, with the same apps open in each session.

LABEL=${1:-${XDG_CURRENT_DESKTOP:-unknown}}
LOG=~/de-measure.log
IGPU=$(basename "$(readlink -f /dev/dri/amd-igpu)")
DEV=/sys/class/drm/$IGPU/device
PDEV=$(basename "$(readlink -f "$DEV")")   # e.g. 0000:10:00.0

mib() { echo $(( $1 / 1048576 )); }

{
echo "=== $LABEL | $(date '+%F %T') | session=$XDG_SESSION_TYPE desktop=$XDG_CURRENT_DESKTOP"

echo "-- iGPU ($PDEV): vram $(mib "$(cat $DEV/mem_info_vram_used)") / $(mib "$(cat $DEV/mem_info_vram_total)") MiB, gtt $(mib "$(cat $DEV/mem_info_gtt_used)") MiB"
echo "-- NVIDIA: $(nvidia-smi --query-gpu=memory.used,power.draw,pstate --format=csv,noheader 2>/dev/null)"

# iGPU busy% over 10 s at idle (20 samples)
busy=0; for _ in $(seq 20); do busy=$((busy + $(cat $DEV/gpu_busy_percent))); sleep 0.5; done
echo "-- iGPU avg busy over 10s: $((busy / 20))%"

# Per-process iGPU memory from DRM fdinfo (compositor may be unreadable if it has capabilities)
echo "-- per-process iGPU memory (VRAM GTT MiB):"
for p in /proc/[0-9]*; do
  [ -O "$p" ] || continue
  c=$(cat "$p/comm" 2>/dev/null)
  grep -hE '^drm-(client-id|pdev|memory-vram|memory-gtt):' "$p"/fdinfo/* 2>/dev/null | awk -v c="$c" -v pd="$PDEV" '
    /drm-pdev/ {cur=$2} /drm-client-id/ {id=$2}
    /drm-memory-vram/ && cur==pd {v[id]=$2}
    /drm-memory-gtt/  && cur==pd {g[id]=$2}
    END {for (k in v) {tv+=v[k]; tg+=g[k]} if (tv+tg>0) printf "   %6d %6d  %s\n", tv/1024, tg/1024, c}'
done | sort -rn | head -12

# Desktop-session RAM (PSS) — shell/compositor/session processes only, not your apps
PAT='plasma|kwin|kded|ksmserver|kaccess|kdeconnect|kwalletd|ksecretd|kactivity|baloo|DiscoverNot|polkit-kde|org_kde|kglobalacc|powerdevil|lxqt|pcmanfm-qt|labwc|qlipper|xdg-desktop-por|Xwayland'
tot=0; n=0
for p in $(pgrep -u "$USER" -f "$PAT"); do
  v=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null); [ -n "$v" ] || continue
  tot=$((tot + v)); n=$((n + 1))
done
echo "-- desktop session RAM (PSS): $((tot / 1024)) MiB across $n processes"
echo "-- system RAM used: $(free -m | awk '/^Mem/{print $3}') MiB"
echo
} | tee -a "$LOG"
