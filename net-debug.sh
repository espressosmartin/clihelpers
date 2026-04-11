#!/bin/bash

# -------- DEFAULT CONFIG (can be overridden) --------
INTERVAL="${INTERVAL:-5}"                         # seconds
LOG_DIR="${LOG_DIR:-$HOME}"                       # log folder
TEST_IP="${TEST_IP:-8.8.8.8}"
TEST_HOST="${TEST_HOST:-google.com}"
# ---------------------------------------------------

# -------- CLI overrides --------
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --log-dir)
      LOG_DIR="$2"
      shift 2
      ;;
    --ip)
      TEST_IP="$2"
      shift 2
      ;;
    --host)
      TEST_HOST="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done
# --------------------------------

mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/net-debug-$(date +%Y%m%d-%H%M%S).log"

get_default_interface() {
  route get default 2>/dev/null | awk '/interface: / {print $2; exit}'
}

get_default_gateway() {
  route get default 2>/dev/null | awk '/gateway: / {print $2; exit}'
}

get_ip_for_interface() {
  local iface="$1"
  ipconfig getifaddr "$iface" 2>/dev/null
}

get_link_status() {
  local iface="$1"
  ifconfig "$iface" 2>/dev/null | awk '/status: / {print $2; exit}'
}

log_header() {
  {
    echo "============================================================"
    echo "Network diagnostic started: $(date)"
    echo "Log file: $LOGFILE"
    echo "Interval: ${INTERVAL}s"
    echo "Log dir: $LOG_DIR"
    echo "Test IP: $TEST_IP"
    echo "Test host: $TEST_HOST"
    echo "============================================================"
  } | tee -a "$LOGFILE"
}

log_snapshot() {
  local iface gateway ipaddr status
  iface="$(get_default_interface)"
  gateway="$(get_default_gateway)"
  ipaddr="$(get_ip_for_interface "$iface")"
  status="$(get_link_status "$iface")"

  local router_result="N/A"
  local ip_result="N/A"
  local dns_result="N/A"
  local resolve_result="N/A"

  if [[ -n "$gateway" ]]; then
    ping -c 1 -t 2 "$gateway" >/dev/null 2>&1 && router_result="OK" || router_result="FAIL"
  fi

  ping -c 1 -t 2 "$TEST_IP" >/dev/null 2>&1 && ip_result="OK" || ip_result="FAIL"

  dscacheutil -q host -a name "$TEST_HOST" >/dev/null 2>&1 && resolve_result="OK" || resolve_result="FAIL"

  ping -c 1 -t 2 "$TEST_HOST" >/dev/null 2>&1 && dns_result="OK" || dns_result="FAIL"

  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "  interface : ${iface:-UNKNOWN}"
    echo "  status    : ${status:-UNKNOWN}"
    echo "  ip        : ${ipaddr:-NONE}"
    echo "  gateway   : ${gateway:-NONE}"
    echo "  router    : $router_result"
    echo "  internet  : $ip_result  (ping $TEST_IP)"
    echo "  resolve   : $resolve_result  (DNS lookup $TEST_HOST)"
    echo "  hostname  : $dns_result  (ping $TEST_HOST)"
    echo
  } | tee -a "$LOGFILE"
}

log_changes() {
  local iface gateway ipaddr status now
  iface="$(get_default_interface)"
  gateway="$(get_default_gateway)"
  ipaddr="$(get_ip_for_interface "$iface")"
  status="$(get_link_status "$iface")"
  now="$(date '+%Y-%m-%d %H:%M:%S')"

  [[ "$iface" != "$LAST_IFACE" ]] && echo "[$now] CHANGE: interface '$LAST_IFACE' -> '$iface'" | tee -a "$LOGFILE" && LAST_IFACE="$iface"
  [[ "$gateway" != "$LAST_GATEWAY" ]] && echo "[$now] CHANGE: gateway '$LAST_GATEWAY' -> '$gateway'" | tee -a "$LOGFILE" && LAST_GATEWAY="$gateway"
  [[ "$ipaddr" != "$LAST_IP" ]] && echo "[$now] CHANGE: IP '$LAST_IP' -> '$ipaddr'" | tee -a "$LOGFILE" && LAST_IP="$ipaddr"
  [[ "$status" != "$LAST_STATUS" ]] && echo "[$now] CHANGE: link '$LAST_STATUS' -> '$status'" | tee -a "$LOGFILE" && LAST_STATUS="$status"
}

trap 'echo; echo "Stopped: $(date)" | tee -a "$LOGFILE"; exit 0' INT TERM

log_header

LAST_IFACE=""
LAST_GATEWAY=""
LAST_IP=""
LAST_STATUS=""

while true; do
  log_changes
  log_snapshot
  sleep "$INTERVAL"
done
