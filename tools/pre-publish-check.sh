#!/usr/bin/env bash
# THE GATE. Run before every commit in this repo. Exit non-zero = do not commit.
#
# WHY A GATE AND NOT CARE: this repo exists because ~/Projects/microcell CANNOT be
# published -- it carries working private keys, device IMEIs and ~50 MB of vendor
# firmware. Content is copied here BY HAND from that tree, and a hand-copy is
# exactly where a secret rides along unnoticed.
#
# ⭐ AND THE ORDERING IS WHY IT MUST RUN BEFORE THE COMMIT, NOT AFTER:
#    a leak must be AMENDED OUT, not FIXED FORWARD -- a commit that scrubs a
#    secret publishes it in the diff that removes it. Once this repo is pushed,
#    the window is shut. Everything is cheap until the first push and expensive
#    forever after.
#
# ⚠️ THE CENSUS RUNS FROM THE SECRET STORE TOWARD THE REPO, never from the repo
#    toward a guess. `git grep` cannot find a secret you did not know was there,
#    because you do not know what to grep for.
#
# ✅ THIS FILE NO LONGER EXCLUDES ITSELF, because it no longer contains any
#    identifier to hide. That exemption was the defect, not the workaround.
#
# ⚠️ TWO DEFECTS FOUND BY A REVIEWER ON 2026-09-10, BOTH IN THIS FILE, BOTH MINE.
#
# 1. EVERY scan line read `grep -rl -- "$pat" . --exclude-dir=.git`. `--`
#    TERMINATES OPTION PARSING, so `--exclude-dir=.git` was passed as a FILE
#    OPERAND. `.git/` was scanned, git's own reflog carries the committer
#    address, and section 4 therefore tripped PERMANENTLY the moment the repo
#    had its first commit. ⭐ TAKEN LITERALLY, THE GATE FORBADE EVERY COMMIT IN
#    THE REPO IT GUARDS -- the alarm-nobody-can-act-on shape, which trains its
#    reader to wave past a 🔴, and the next 🔴 is a real one.
#    ⚠️ All FIVE scan lines had it, INCLUDING THE POSITIVE CONTROL. The control
#      still fired, so its correctness was accidental.
#
# 2. `grep` said so, out loud, on stderr -- `--exclude-dir=.git: No such file or
#    directory` -- and `2>/dev/null` swallowed it. THE TOOL REPORTED ITS OWN
#    FAILURE AND THE HABITUAL REDIRECT HID IT. stderr is now captured and any
#    output on it FAILS the gate, because a scanner that errored is a scanner
#    whose zeros mean nothing.
#
# ⭐ AND WHY MY OWN "TESTED BOTH DIRECTIONS" MISSED IT: I tested on a repo with
#   ZERO COMMITS. The failure needs a reflog to exist. The test was correct and
#   structurally incapable of seeing this -- so a guard must be re-tested AFTER
#   the state it guards actually exists, not only before.
set -uo pipefail
# ⚠️ THE PEM HEADER IS ASSEMBLED, NEVER WRITTEN WHOLE. Once this file scans
#    ITSELF, a literal "-----BEGIN ... PRIVATE KEY-----" in the detector trips
#    the detector. Same defect as the hardcoded identifiers one section up,
#    recursed: A DETECTOR FOR A STRING MUST CONTAIN THE STRING, so either it
#    exempts itself (which is what made the identifier leak invisible) or it
#    builds the needle at runtime. Building it is the one that keeps the scan
#    honest.
PEM_HEAD="-----BEGIN"; PEM_TAIL="PRIVATE KEY-----"
ERRLOG=$(mktemp)
trap 'rm -f "$ERRLOG"' EXIT
cd "$(dirname "$0")/.."
FAIL=0
say() { printf '  %-52s %s\n' "$1" "$2"; }

# --- 1. SIM key material, read from the private store on this machine ---------
CSV=~/Projects/2g/sim/usim-cards.csv
if [ -r "$CSV" ]; then
  n=0
  while IFS=, read -r imsi msisdn name ki opc adm iccid; do
    [ "$imsi" = "imsi" ] && continue
    for v in "$ki" "$opc" "$adm"; do
      [ -z "$v" ] && continue
      # -F: a key can contain characters that are regex metacharacters
      if /usr/bin/grep -rlF --exclude-dir=.git -- "$v" . 2>>"$ERRLOG" | /usr/bin/grep -q .; then
        say "🔴 KEY MATERIAL from $imsi" "PRESENT"; FAIL=1
      fi
      n=$((n+1))
    done
  done < "$CSV"
  say "SIM secrets checked ($n values)" "$([ $FAIL -eq 0 ] && echo '✅ none present' || echo '🔴 SEE ABOVE')"
else
  say "⚠️ $CSV unreadable" "CANNOT VERIFY — treat as FAIL"; FAIL=1
fi

# --- 2. handset IMEIs, BOTH digit forms --------------------------------------
# ⚠️ THE 14-DIGIT TRAP: the MSC prints an IMEI without its Luhn check digit, so
#    a 15-digit search returns a clean, complete-looking ZERO for a device that
#    is present. This was measured on 2026-09-10: an audit reported 2 IMEIs in
#    microcell and the true figure was 3.
INV=~/Projects/2g/docs/inventory.json
if [ -r "$INV" ]; then
  imeis=$(python3 -c "
import json;d=json.load(open('$INV'))
print(' '.join(h['imei'] for h in d['handsets'] if h.get('imei')))" 2>/dev/null)
  c=0
  for i in $imeis; do
    for form in "$i" "${i:0:14}"; do
      if /usr/bin/grep -rlF --exclude-dir=.git -- "$form" . 2>>"$ERRLOG" | /usr/bin/grep -q .; then
        say "🔴 IMEI $form" "PRESENT"; FAIL=1
      fi
    done
    c=$((c+1))
  done
  say "IMEIs checked ($c handsets x 2 forms)" "$([ $FAIL -eq 0 ] && echo '✅ none present' || echo '🔴 SEE ABOVE')"
else
  say "⚠️ $INV unreadable" "CANNOT VERIFY — treat as FAIL"; FAIL=1
fi

# --- 3. private keys, by CONTENT not by filename -----------------------------
# ⚠️ A secret-shaped FILENAME is not a secret and a harmless one can hide one.
#    microcell tracks a 0-byte `ipsec.secrets`; it also tracks real keys named
#    `.pem`, which most people read as "certificate, therefore public".
k=$(/usr/bin/grep -rlE --exclude-dir=.git -- "$PEM_HEAD (RSA |EC |OPENSSH |ENCRYPTED )?$PEM_TAIL" . 2>>"$ERRLOG" | wc -l)
[ "$k" -gt 0 ] && { say "🔴 files containing a PRIVATE KEY block" "$k"; FAIL=1; } \
               || say "private-key blocks" "✅ 0"

# --- 4. internal names, personal identifiers, real numbers -------------------
# ⛔ THE PATTERNS LIVE OUTSIDE THIS FILE, AND THAT IS THE WHOLE POINT.
#
# 🔴 THIS FILE USED TO CONTAIN THEM, AND THAT MADE IT THE LEAK. A real PSTN
#    number, a personal git address and two private domains were hardcoded here
#    -- and because a detector for an identifier must contain the identifier,
#    the file had to be EXCLUDED from its own scan. So the one file guaranteed
#    to hold every identifier at once was the only file never checked, and the
#    gate printed ✅ SAFE while carrying them. Committed in 18f5878, whose
#    entire purpose was to establish the gate.
#
# ⭐⭐ THE GENERALISATION, and it is the most useful thing in this script:
#    THE HIGHEST-RISK ARTEFACT IS WHICHEVER ONE IS EXCLUDED FROM THE CHECK.
#    An exclusion is never arbitrary -- it is CAUSED BY the density of what it
#    hides. Same shape as a wildcard DNS answer masking corrupt names, and as a
#    log level that made every surviving sample a failure: the filter ends up
#    correlated with the thing you are looking for.
#
# ⭐ SO THE FIX IS NOT "EXCLUDE MORE CAREFULLY" -- IT IS TO REMOVE THE REASON
#    THE EXCLUSION EXISTS. With the patterns external, this file holds nothing
#    and needs no exemption. It also makes the script useful to a stranger:
#    before, it was a scanner hardcoded for one person's network.
#
# ⚠️ AND IT FAILS CLOSED. A MISSING PATTERN FILE IS NOT "NO PATTERNS TO CHECK",
#    it is a BLIND SCANNER, and a blind scanner that prints ✅ is the worst
#    outcome this script can produce.
PATTERNS="${PUBLISH_CHECK_PATTERNS:-$HOME/.config/dph-femtocell/patterns.txt}"
if [ ! -r "$PATTERNS" ]; then
  say "🔴 pattern file unreadable" "$PATTERNS"
  echo "      Copy tools/patterns.example.txt to that path and put YOUR identifiers in it."
  echo "      A missing list is a BLIND scanner, not a clean one — refusing to pass."
  FAIL=1
else
  npat=0; nhit=0
  while IFS= read -r pat; do
    case "$pat" in ''|\#*) continue ;; esac
    npat=$((npat+1))
    n=$(/usr/bin/grep -rl --exclude-dir=.git -- "$pat" . 2>>"$ERRLOG" | wc -l)
    if [ "$n" -gt 0 ]; then
      say "⚠️ internal identifier (pattern $npat)" "$n file(s)"
      /usr/bin/grep -rl --exclude-dir=.git -- "$pat" . 2>/dev/null | sed 's/^/      /'
      nhit=$((nhit+1)); FAIL=1
    fi
  done < "$PATTERNS"
  # ⚠️ ZERO PATTERNS READ IS ALSO A BLIND SCANNER. An empty file must not pass.
  if [ "$npat" -eq 0 ]; then
    say "🔴 pattern file has NO patterns" "$PATTERNS"; FAIL=1
  else
    [ "$nhit" -eq 0 ] && say "internal identifiers ($npat patterns)" "✅ none present"
  fi
fi

# --- 5. bulk that must never be here ----------------------------------------
big=$(find . -path ./.git -prune -o -type f -size +2M -print 2>/dev/null | wc -l)
[ "$big" -gt 0 ] && { say "⚠️ files over 2 MB (firmware? evidence?)" "$big"; find . -path ./.git -prune -o -type f -size +2M -print | sed 's/^/      /'; FAIL=1; } \
                 || say "files over 2 MB" "✅ 0"

# --- POSITIVE CONTROL: prove the scanner can see a planted secret ------------
# ⭐ Without this, every ✅ above is indistinguishable from a broken scanner.
T=.__gate_control__
printf -- '%s RSA %s\n' "$PEM_HEAD" "$PEM_TAIL" > "$T"
ctl=$(/usr/bin/grep -rlE --exclude-dir=.git -- "$PEM_HEAD (RSA |EC )?$PEM_TAIL" . 2>>"$ERRLOG" | wc -l)
rm -f "$T"
[ "$ctl" -gt 0 ] && say "CONTROL (planted key found)" "✅ scanner works" \
                 || { say "CONTROL" "🔴 SCANNER IS BLIND — every result above is void"; FAIL=1; }

# --- 5b. VENDOR FIRMWARE AND BINARIES ---------------------------------------
# ⛔ NOTHING ip.access AUTHORED MAY BE COMMITTED HERE. Owning the device does not
#    carry a right to republish its firmware, and this repo is derived from a
#    private tree holding 33 MB of flash dumps, extracted vendor binaries and a
#    20 MB vendor package. That material is exactly what a "just copy the useful
#    bits over" pass drags along.
# ⭐ THE SAFE PATTERN, AND IT LOSES NOTHING: reference firmware by NAME, VERSION
#    and SHA-256 so a reader can verify what is on their OWN device. They already
#    have the bytes; they need to know which bytes are right.
# ⚠️ The size check above is not sufficient on its own -- a 300 KB extracted
#    binary is small and just as unpublishable. This checks SHAPE, not size.
badbin=$(find . -path ./.git -prune -o -type f \
   \( -name '*.bin' -o -name '*.img' -o -name '*.exe' -o -name '*.ko' \
      -o -name '*.zip' -o -name '*.tgz' -o -name '*.tar.*' -o -name '*.mp4' \
      -o -name 'fs[0-9]*' -o -name 'kernel[0-9]*' \) -print 2>/dev/null | wc -l)
if [ "$badbin" -gt 0 ]; then
  say "🔴 vendor-firmware-shaped files" "$badbin"
  find . -path ./.git -prune -o -type f \
    \( -name '*.bin' -o -name '*.img' -o -name '*.exe' -o -name '*.zip' -o -name '*.mp4' \) \
    -print 2>/dev/null | sed 's/^/      /'
  FAIL=1
else
  say "vendor-firmware-shaped files" "✅ 0"
fi
# ELF binaries regardless of extension -- an extracted binary often has none
elf=$(find . -path ./.git -prune -o -type f -size +8k -print 2>/dev/null \
      | while read -r f; do head -c4 "$f" 2>/dev/null | grep -qP '^\x7fELF' && echo "$f"; done | wc -l)
[ "$elf" -gt 0 ] && { say "🔴 ELF binaries" "$elf"; FAIL=1; } || say "ELF binaries" "✅ 0"

# --- 6. COMMITTER IDENTITY -- a surface no content gate can reach ------------
# ⚠️ `git log` carries an author and committer on EVERY commit, and no
#    working-tree edit can change one. It is fixable ONLY by setting the repo's
#    identity BEFORE the history exists, or by rewriting history afterwards.
#    ⭐ So this is reported as a DECISION, not as a blocker: an alarm the reader
#      cannot act on is worse than no alarm, because it teaches them to ignore
#      the panel.
ident=$(git config user.email 2>/dev/null || true)
glob=$(git config --global user.email 2>/dev/null || true)
if [ -n "$ident" ] && [ "$ident" != "$glob" ]; then
  say "committer identity (repo-local)" "✅ $ident"
else
  say "committer identity" "⚠️ inherits global ($glob) — set a repo-local one"
  echo "      git -C \"$(pwd)\" config user.email <publishing address>"
  echo "      Do it BEFORE there is history to rewrite. Not a blocker."
fi

# --- stderr check: a scanner that errored has meaningless zeros --------------
if [ -s "$ERRLOG" ]; then
  say "🔴 a scan wrote to stderr" "its results are VOID"
  sed 's/^/      /' "$ERRLOG"
  FAIL=1
else
  say "scanner stderr" "✅ silent"
fi

echo
[ $FAIL -eq 0 ] && echo "  ✅ SAFE TO COMMIT" || echo "  🔴 DO NOT COMMIT — fix the items above first"
exit $FAIL
