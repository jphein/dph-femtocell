#!/usr/bin/env bash
# find-femtocell.sh — locate a Cisco/ip.access DPH-15x femtocell on a LAN and probe it.
#
# PASSIVE ONLY. Scans, probes ports, reads banners. Writes nothing to the device and
# cannot cause it to transmit. Safe to run repeatedly.
#
# Usage:
#   ./find-femtocell.sh 192.0.2.0/24         discover on a subnet, then probe
#   ./find-femtocell.sh --ip 192.0.2.77      skip discovery, probe one host
#
# Exit: 0 probed · 2 COULD NOT MEASURE · 3 measured, no candidate found
#       ⭐ 2 and 3 are deliberately different. An instrument that cannot reach its
#         subject must not be able to report a finding about it.
#
# ⛔ ISOLATE THE UNIT FIRST. On boot it resolves its operator's management hostnames,
#    tries IPsec to a dead security gateway and TR-069 to a dead management server, and
#    retries forever. Nothing answers, but the DNS queries and IPsec attempts leave your
#    network. Put it on a segment with no internet route before powering it on.
set -uo pipefail
export LC_ALL=C

usage() { sed -n '2,14p' "$0"; exit 2; }
TARGET=""
case "${1:-}" in
  ""|-h|--help) usage ;;
  --ip)         TARGET="${2:?--ip needs an address}" ;;
  *)            SUBNET="$1" ;;
esac

hr(){ printf '%s\n' "──────────────────────────────────────────────────────────────"; }

# OUIs seen on these femtocells.
# ⚠️ An OUI lookup on any of these returns **Cisco SPVTG**, not ip.access. Both are right at
#    different layers: ip.access designed the femtocell platform and its software stack, Cisco
#    shipped, badged and registered the units. Do not discard a candidate because the vendor
#    string says Cisco -- that is the expected answer.
# ⚠️ NOT EXHAUSTIVE, and this is the script's main failure mode. An unlisted OUI does
#    NOT mean the device is absent. A real DPH-154 in our lab carried an OUI that was
#    missing from the first version of this list -- the scanner would have confidently
#    reported "not found" on the very unit sitting in front of it.
# ⇒ If discovery finds nothing, that is a prompt to check by hand, not an answer.
OUI_RE='48:1D:70|00:1B:9E|00:1A:2F|00:24:97|68:BC:0C|CC:EF:48'

if [ -z "$TARGET" ]; then
  echo "== discovery: $SUBNET =="
  # ⛔ DO NOT redirect nmap's stderr to /dev/null. A tool reporting its own failure
  #    into the one stream the habitual redirect discards is how a broken scan becomes
  #    a confident zero. Captured, and surfaced below.
  err=$(mktemp); trap 'rm -f "$err"' EXIT
  raw=$(sudo nmap -sn -n "$SUBNET" 2>"$err"); rc=$?
  scan=$(printf '%s\n' "$raw" | grep -E "Nmap scan report|MAC Address" | paste - -)
  total=$(printf '%s\n' "$scan" | grep -c .)

  # ⭐ COULD-NOT-MEASURE IS ITS OWN OUTCOME, AND IT IS NOT "FOUND NOTHING".
  #    An earlier version of this script printed "no femtocell among 0 hosts" and
  #    exited 3 for an invalid subnet, a missing nmap and a sudo refusal alike --
  #    byte-identical to a real scan of an empty network. The comment two lines up
  #    said those were different findings; the code did not implement it.
  # ⚠️ And 0 hosts on a subnet you are attached to is itself implausible: a working
  #    scan sees your own gateway. Treat it as a broken instrument, not an empty LAN.
  if [ $rc -ne 0 ] || [ "$total" -eq 0 ]; then
    echo "   🔴 COULD NOT MEASURE — this is NOT a 'no femtocell found' result."
    [ -s "$err" ] && sed 's/^/      nmap: /' "$err"
    echo "      nmap exit=$rc, hosts parsed=$total"
    echo "      Check: is the subnet right? is nmap installed? did sudo succeed?"
    echo "      A working scan of a subnet you are on sees at least your gateway."
    exit 2
  fi
  echo "   hosts responding: $total"
  hits=$(printf '%s\n' "$scan" | grep -iE "$OUI_RE")
  if [ -n "$hits" ]; then
    echo "   candidate(s) by OUI:"; printf '%s\n' "$hits" | sed 's/^/     /'
    TARGET=$(printf '%s\n' "$hits" | head -1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
  else
    echo "   no known femtocell OUI among $total hosts."
    echo "   ⚠️ This is NOT proof of absence -- the OUI list above is incomplete."
    echo "      Check your DHCP leases by hand, then re-run with --ip <addr>."
    exit 3
  fi
fi

hr; echo "== probing $TARGET =="

echo "-- MAC / vendor --"
sudo nmap -sn -n "$TARGET" 2>/dev/null | grep -E "MAC Address" | sed 's/^/   /'

echo "-- 'wizard' backdoor, UDP 14677 (fail0verflow, 2012) --"
echo "   unauthenticated root command execution. Present on the DPH-151 and still"
echo "   present in DPH-153 images. Status on the DPH-154 is unknown -- a negative"
echo "   there is a result worth publishing, not a failure."
sudo nmap -sU -p 14677 --host-timeout 60s "$TARGET" 2>/dev/null | grep -E "^14677|PORT" | sed 's/^/   /'

echo "-- management ports --"
echo "   ⚠️ -Pn is REQUIRED: at least one of these units drops ICMP echo, and without"
echo "      -Pn nmap skips it as down -- a confident false negative on a live device."
echo "   8090 = ip.access DMI console (try this first; if open and unauthenticated,"
echo "          you may never need a root shell).  7547 = TR-069 connection request."
sudo nmap -Pn -sT -p 22,23,80,443,7547,8080,8090,20000 --host-timeout 60s "$TARGET" 2>/dev/null \
  | grep -E "^[0-9]+/|PORT" | sed 's/^/   /'

echo "-- full TCP sweep (slower; finds anything unexpected) --"
sudo nmap -Pn -sT -p- --host-timeout 300s "$TARGET" 2>/dev/null | grep -E "^[0-9]+/" | sed 's/^/   /'

echo "-- HTTP banners, if any --"
for p in 80 443 8080 8090; do
  b=$(timeout 6 curl -sk -o /dev/null -w "%{http_code}" "http://$TARGET:$p/" 2>/dev/null)
  [ -n "$b" ] && [ "$b" != "000" ] && echo "   :$p -> HTTP $b"
done

hr
echo "Next: docs/ACCESS.md. If the network side is closed, docs/ACCESS.md route 4"
echo "(serial console) -- and use a 3.3 V-ONLY adapter."
echo
echo "⛔ REMINDER: settle the PLMN before you enable any radio. A unit that ran on a"
echo "   carrier's network still carries that carrier's MCC/MNC, and broadcasting it"
echo "   is impersonating a real network operator. See docs/CONFIG.md."
