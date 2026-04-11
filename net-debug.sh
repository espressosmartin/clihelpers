#!/bin/bash

# macOS network diagnostic logger
# Logs interface state, gateway reachability, internet reachability, and DNS health.

LOGFILE="${HOME}/net-debug-$(date +%Y%m%d-%H%M%S).log"
INTERVAL=5

# -------- config you can change --------
TEST_IP="8.8.8.8"
TEST_HOST="google.com"
# --------------------------------------

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
    if ping -c 1 -t 2 "$gateway" >/dev/null 2>&1; then
      router_result="OK"
    else
      router_result="FAIL"
    fi
  fi

  if ping -c 1 -t 2 "$TEST_IP" >/dev/null 2>&1; then
    ip_result="OK"
  else
    ip_result="FAIL"
  fi

  if dscacheutil -q host -a name "$TEST_HOST" >/dev/null 2>&1; then
    resolve_result="OK"
  else
    resolve_result="FAIL"
  fi

  if ping -c 1 -t 2 "$TEST_HOST" >/dev/null 2>&1; then
    dns_result="OK"
  else
    dns_result="FAIL"
  fi

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

  if [[ "$iface" != "$LAST_IFACE" ]]; then
    echo "[$now] CHANGE: interface changed: '$LAST_IFACE' -> '$iface'" | tee -a "$LOGFILE"
    LAST_IFACE="$iface"
  fi

  if [[ "$gateway" != "$LAST_GATEWAY" ]]; then
    echo "[$now] CHANGE: gateway changed: '$LAST_GATEWAY' -> '$gateway'" | tee -a "$LOGFILE"
    LAST_GATEWAY="$gateway"
  fi

  if [[ "$ipaddr" != "$LAST_IP" ]]; then
    echo "[$now] CHANGE: IP changed: '$LAST_IP' -> '$ipaddr'" | tee -a "$LOGFILE"
    LAST_IP="$ipaddr"
  fi

  if [[ "$status" != "$LAST_STATUS" ]]; then
    echo "[$now] CHANGE: link status changed: '$LAST_STATUS' -> '$status'" | tee -a "$LOGFILE"
    LAST_STATUS="$status"
  fi
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
