# Bring-up: DPH-151 — from a boxed MicroCell to a call

> ## 🔴 **WHICH RALINK BUILD IS THIS PROCEDURE FOR? — READ THIS BEFORE YOU LOG IN**
> **Everything below that uses `guest` / `1qaz@WSX` describes a Ralink running `FW:1.0.34`.**
> ⛔ **THE ACCOUNT SETS ON THE TWO BUILDS ARE *DISJOINT*, NOT OVERLAPPING:**
> ```
> FW:1.0.34   guest:…:1001:1001:guest:/tmp:/bin/sh   <- THE ENTIRE FILE. No root. No sshd.
> FW:1.0.31   root:…:0:0:  +  sshd:…:0:0:            <- THE ENTIRE FILE. NO `guest` AT ALL.
> FW:1.0.29   root + sshd, same as 1.0.31
> ```
> ⇒ ⛔ **On a 1.0.29/1.0.31 unit, `guest`/`1qaz@WSX` DOES NOT EXIST and the login is refused.**
> ⇒ ☠️ **AND A FAILED LOGIN ON THIS DEVICE'S SINGLE-CLIENT `telnetd` IS INDISTINGUISHABLE FROM A
> BRICKED BOARD** — so the first conclusion available to you is the worst one, and it is wrong.
> ✅ **On 1.0.29/1.0.31 log in as `root`. On 1.0.34 log in as `guest`.**
>
> ### ✅ **CHECK THE UNIT IN FRONT OF YOU — ONE COMMAND, AND IT CANNOT GO STALE:**
> ```sh
> cat /etc_ro/version      # -> FW:1.0.34 --  Fri Apr 20 20:43:20 CST 2012
> ```                      #    or FW:1.0.31 --  Thu Oct  6 09:37:21 CST 2011
> ⭐ **The IMAGE states its own identity. This document cannot.** An undated, unversioned
> procedure is *undetectably* stale: there is no anchor for a reader to compare against the
> device, so nothing in the text can contradict a unit that has been re-flashed or bank-flipped.
> ⚠️ **Dates in this file certify WHEN something was measured, never WHETHER IT STILL HOLDS.**


> ## 1️⃣ **BEFORE STEP ONE — CONFIRM WHICH UNIT YOU ARE HOLDING: [`MATRIX.md`](MATRIX.md)**
> **This guide is for the DPH-151: two SoCs (Ralink `.185` + picoChip `.186`) · live bank `config_bank_1` · **563** train**
> ⇒ ⛔ **If your unit is not that, STOP — the other models differ in ways that have cost this
> project days: bank numbering is REVERSED between the 151 and the nano3G, the 154 has no banks
> at all, and a 579 measurement is not a 563 fact.**
> ✅ **[`MATRIX.md`](MATRIX.md) is the identification table** — `## Identity`, `## Silicon and RF`,
> `## Capability`, `## Access and state`. **Read it first; it is 166 lines and it is the only
> document that tells you WHICH machine you have before you type anything.**
> 📌 **POINTER, NOT A COPY.** `[Wired in 2026-09-14: MATRIX.md existed and NO guide referenced it —
> the identification step was written and orphaned.]`


**Scope: written from a DPH-151 (ip.access train `563.21.8`) brought up against an Osmocom
core, carrying voice and SMS for four handsets and recovering unattended from a power cut.**
**This page is the DPH-151 guide.** Every phase below was executed on one.

> ### 🧭 FOUR TARGETS, FOUR GUIDES — pick yours before you read further
> | target | guide | evidence class |
> |---|---|---|
> | **Cisco DPH-151** | **this page** | ✅ **proven here, end to end** |
> | **ip.access nano3G S8** | [`BRINGUP-NANO3G.md`](BRINGUP-NANO3G.md) | ✅ **proven here, end to end** |
> | **Cisco DPH-153** | [`BRINGUP-DPH153.md`](BRINGUP-DPH153.md) | ⚠️ **published route by someone else; not reproduced here** |
> | **Cisco DPH-154** | [`BRINGUP-DPH154.md`](BRINGUP-DPH154.md) | ⚠️ **access SOLVED here; radio gated by a per-unit tamper bit** |
>
> ⭐ **Phases 4–8 below are the ip.access software stack and transfer between models** — attributes,
> the unlock order, the transmission gate, power-cut recovery. **Phases 0–3 are hardware and access,
> and those are where the models genuinely differ.** ⛔ **[`Trap 2`](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
> is a worked example of a correct instruction for one model destroying another.**

Read [`TRAPS.md`](TRAPS.md) first. Most of the time this takes is spent on the traps, not
on the steps.

---

> ## 2️⃣ 🎯 **THE GOAL OF PHASES 0–3 IS ROOT SSH ON BOTH CHIPS. EVERYTHING ELSE WAITS ON IT.**
> `[JP, 2026-09-13: **"get root ssh on both chips is the first step"** · **"you have to get shell
>  in order to make them work so the guide is wrong"**]`
> ```
> Ralink   192.168.157.185   /32 host route + rroot.py        ✅ WORKS — done on .106
> pico     192.168.157.186   <- Phase 3's real job. Harder.
> ```
> ### ⛔ **A CELL DOES NOT SERVE WITHOUT A SHELL. THIS IS NOT ONE OF TWO OPTIONS.**
> **This guide used to ask *"do you want a configured cell, or a shell?"* as though they were
> alternatives. THAT WAS WRONG AND IT IS REMOVED.** `[confirmed in code, not taken on authority:
> `bringup-full.sh:82` drives EVERY step through `ap.sh`, an SSH exec on the device · the
> `iapc-gw-shim` is a BINARY that must be compiled and installed · `picoinit` programs the
> picoArray ON THE BOX · `findings-cmhsclient.md:1338`: **"NO CWMP PATH TO THAT FILE."**]`
> ```
> CWMP / CMHS  gets you  reads (543 parameters), identity/PLMN writes, and — via PATH D —
>                        THE ROUTE TO A SHELL.  It is the MEANS, not an alternative to the end.
> A SHELL      gets you  IUH_ENABLE in the live config bank · the iapc-gw-shim installed ·
>                        picoinit programming the picoArray · bringup-full.sh at all.
> ⇒ EVERY PATH ENDS AT A SHELL. They differ only in HOW THEY REACH IT.
> ```
> ⚠️ **The corpus says *"CWMP gives read AND write"* and that is true and narrower than it sounds:
> it retires the shell requirement FOR READING CONFIG. It does not retire it for making a cell
> serve.** ⭐ **That gap — documenting what CWMP CAN do in detail and never stating its LIMIT — is
> how the wrong framing grew.**

> ## ✅ **WHAT "DONE" LOOKS LIKE — MEASURED ON `.244`, A WORKING DPH-151**
> `[read live 2026-09-13 while it was serving, uptime 3h22m. Diff your unit against this rather
>  than guessing whether you are finished.]`
> ```
> live bank      /var/ipaccess/config -> config_bank_1     ⚠️ BANK 1 — the OPPOSITE of the nano3G.
>                                                             ALWAYS read it, never assume.
> IUH_ENABLE     uplayerapp.cfg = 1  AND  3gcntrl.cfg = 1  ⚠️ BOTH FILES, and they PARSE
>                                                             DIFFERENTLY — see Phase 7.
> iapc running   /opt/ipaccess/Iapc/iapc.563.21.8          ⚠️ the STOCK path. A DPH-151 is NOT
>                                                             transplanted. The nano3Gs run
>                                                             /var/ipaccess/iapc/ — DO NOT CARRY
>                                                             THAT ACROSS.
> persistence    /var/ipaccess/root_home/.ssh/authorized_keys
> device config  /var/ipaccess/cisco/{DefaultFileVersion, cmhs.dat, cmhs_def_cfg.txt}
>                ⭐ the EIGHT CMHS hostnames live ON THE DEVICE, in the WRITABLE partition —
>                  live config you can change, not a firmware artefact you must work around.
> ```

## 3️⃣ ⛔ **WHAT IS MEASURED SHUT — READ BEFORE YOU SPEND AN EVENING**

**Every row is a MEASUREMENT on a DPH-151, with its date and who took it. None is an inference.**
⭐ **The point of this section is that a settled NO is worth more than an open maybe: it converts
*"try X"* from an afternoon into a closed question, and names what would have to CHANGE to reopen it.**

| route | verdict | measured | what would reopen it |
|---|---|---|---|
| **DMI `:8090` listener** | ⛔ **never started** | `opnormal:258` gates it on `${ENV_START_DMI_TELNET:-"FALSE"}`; absent from every `nv_env.sh` held. Probed with a **port-forward in place** and still closed `[team-lead 2026-09-14]`; **also not listening on `.244`** `[lucid-console154]` ⇒ **151-wide, not a `.106` fault** | writing `ENV_START_DMI_TELNET TRUE` — which needs the shell this route was meant to get you |
| **`:80` commissioning-UI upload** | ⛔ **refused** | DNAT'd through to the pico, which refuses it exactly as `:22` `[lucid-console154 2026-09-14]` | unknown — the refusal is the pico's |
| **`init.dmi` runner** | ⛔ **unreachable** | needs a FILE on the pico; **the Ralink cannot reach the pico's filesystem by any route** — no mount, no nfs/cifs/9p client, tftp times out with the local file never created `[team-lead 2026-09-14, with root]` | a filesystem path to the pico, or serial |
| **`init_nv_env` clobbering your flags (PATH A)** | ✅ **cannot fire** | reachable only via `activate_fs`, gated on `case $FNAME in fs.bin)`; a hook-only SDP has no filesystem image `[morpheus-iuh154 2026-09-14]` ⚠️ **579 tree; 563 copy unread** | a download that installs a filesystem |
| **every certificate theory** (CN · chain · issuer · vintage) | ⛔ **excluded STRUCTURALLY** | the device FINs with **no TLS alert** ⇒ TLS succeeded and the refusal is ABOVE it `[acs_tr069.py:91, in the file since 2026-09-11]` | nothing — **a chain swap cannot fix a layer that already succeeds** |
| **cert CN specifically — tried EMPIRICALLY, by someone else** | ⛔ **failed 3 / 3** | **the previous owner tried THREE CNs — exact match, a different exact name, and a wildcard — ACROSS TWO DAYS. ALL THREE FAILED IDENTICALLY.** `[donor README, 2026-09-05]` | nothing — **this is a shut door with somebody else's two days behind it** |

> ### ⚠️ **AND ONE THAT IS *NOT* SHUT, RECORDED SO NOBODY RETIRES IT BY MISTAKE**
> **The cert-CN swap was attempted 2026-09-14 and MEASURED NOTHING** — the dial cited as its result
> predated the swap by three minutes, and during the window the cert was live the device did not
> connect at all. ⇒ ***UNTESTED, not refuted.*** **It is excluded by the structural argument above,
> not by that experiment.**

### ✅ **AND ITS COMPLEMENT — WHAT IS STILL *OPEN*. A SHUT-LIST ALONE TELLS YOU WHERE NOT TO GO.**
`[surfaces enumerated by lucid-console154, 2026-09-14, in 2g/docs/findings/PLAN-106-post-reboot.md
 §4 "so nobody re-derives it". Lifted here because that file is a SESSION PLAN and this is the
 durable home — a surface list in an ephemeral document is lost the moment the session closes.]`
```
udp 1024:65535   THE ONLY UNEXPLORED RANGE. The pico firewall permits it from .185.
                 ⛔ needs a real UDP client ⇒ do it FROM THE PICO. The Ralink's tftp gives
                    REACH, NOT ENUMERATION — an RRQ is answered only by a TFTP server.
tcp 20000        🔴 RETRACTED 2026-09-14 — NOT A SURFACE ON .106. It is a .244 forward.
                 Probed live: 10.0.6.106:20000 REFUSED, identically to the :9999 control.
                 See the per-unit block below; do not put it back.
tcp 3016 · 2345  OBSERVED LISTENING ON 0.0.0.0 — not loopback — on .244's pico.
                 ⇒ what becomes reachable on .106 the MOMENT its firewall opens.
udp 5050         netannounce. ⚠️ CMHS-side (present in cmhs, absent in DslmSsp) ⇒ a hit is
                 NOT progress on the Inform problem. Reachability only.
```
### 🔴 **`tcp 20000` RETRACTED AS A `.106` SURFACE — AND WHAT REPLACES IT IS WORTH MORE THAN THE PORT**
`[lucid-console154, live nat table AND a probe on .106, 2026-09-14, with BOTH controls passing:
 192.168.157.185:23 succeeded (known-open) · 10.0.6.106:9999 refused (known-closed) ⇒ the
 instrument discriminates. Device scope independently confirmed at the source by nebula-librarian3.]`
```
                  .244  (DPH-151 #1)        .106  (DPH-151 #2)
  DNAT forwards   80, 22, 8080, 20000       80, 22, 8080          <- THREE RULES, NOT FOUR
  source          findings-dph151.md:113    live nat table, measured 2026-09-14
```
⇒ ⛔ **`10.0.6.106:20000` refuses EXACTLY AS `:9999` DOES — because it IS like `:9999`: with no
DNAT it lands on the Ralink, which has no listener and RSTs.**
⇒ ⭐⭐⭐ **THE TWO UNITS DIFFER, AND *THAT* IS THE DURABLE FINDING: THE FORWARD TABLE IS PER-UNIT
CONFIGURATION, NOT A MODEL PROPERTY.** ⇒ **NO PORT LIST TRANSFERS BETWEEN THESE UNITS.**
✅ **Enumerate it on the unit in your hand:** `iptables -t nat -L PREROUTING -n` on its Ralink.
⇒ ⭐ **AND IT TELLS US SOMETHING ABOUT A VERB NOBODY HAS DARED CALL:** somebody, at some point,
set a forward on `.244` that `.106` lacks. ⇒ **`set_port_fwd` WORKS and its effect PERSISTS —
learned from a difference between two units, without touching the verb.**
☠️ **PROVENANCE, BECAUSE IT IS THIS CORPUS'S MOST-REPEATED ERROR: `findings-dph151.md` IS A `.244`
FILE.** Its own header reads *"Lane: lucid-dph151 · 2026-09-04"* and its §1 reads `IP 10.0.6.244`.
⇒ **A `.244` fact was read into a `.106` surface list, and I lifted it into this guide on that
list's word — inside a document whose stated purpose is to stop people re-deriving things.**
⭐ **It was caught ONLY BECAUSE IT WAS LIFTED** — i.e. read by someone other than its author.
⇒ ***Copying a claim into a second home is not just propagation; it is the only review it gets.***

> ### 📌 **THE THREE DMI DOORS IN DETAIL ARE IN PHASE 3 — POINTER, NOT A COPY**
> **Each is closed for its own reason, which is the useful part: not one assumption carried across
> three ports.** ⇒ **See Phase 3 item 6.**
> ⭐ **AND A POSITIVE-CONTROL WARNING FOR ANYONE MINING THE DONOR CAPTURES:** ⛔ **`151prov.pcapng`
> and `151full.pcapng` are NOT a positive control** — 150 mutual-TLS handshakes, **zero application
> bytes**, device-initiated FIN 8.7 ms after the server's `Finished`. ***An instrument that has
> never once shown a success.*** `[nebula-provpcap 2026-09-05, donor README]`

---

## ⛔ Before you plug anything in

**Isolate the unit.** On first boot the firmware does: DHCP → DNS lookups for its
operator's management hostnames → IPsec to a security gateway → TR-069 to a management
server → retry forever. Those endpoints are dead, so nothing will answer — but **the DNS
queries and IPsec attempts leave your network**. Put the unit on an isolated VLAN or
segment with no route to the internet before you power it on. This is configuration, not
a purchase.

**Do not enable the radio yet.** Everything up to Phase 5 is passive. The PLMN question
(below) is a hard gate: settle it before anything transmits.

---

## Phase 0 — Identify the unit

Record, from the label: model, FCC ID, part number, hardware revision, MAC, and **the PSU
voltage**. Do not guess the PSU.

Then decide which model you have and read the matching section of
[`HARDWARE.md`](HARDWARE.md) — the three are not interchangeable, and **firmware from one
will not load on another** (the image loader gates on PCB number and rejects a mismatch).

## Phase 1 — Find it on the network, and knock

> ### ⛔ **READ THIS BEFORE YOU SCAN. A PORT SCAN OF THE LAN ADDRESS MEASURES THE WRONG CHIP.**
> `[MEASURED 2026-09-13 on .106 and .244. This cost a lane an evening on 2026-09-13 — it scanned
>  the LAN face for an hour while the management side sat behind it needing ONE ROUTE.]`
>
> **A DPH-15x is TWO PROCESSORS on a `192.168.157.184/30` point-to-point link — exactly two
> usable addresses:**
> ```
> 192.168.157.185   Ralink    OWNS THE LAN ADDRESS. Answers your ping. Runs the firewall.
>                             DNATs 22/80/8080 onward to .186. ⚠️ THE LIST IS PER-UNIT:
>                             .244 also forwards 20000; .106 does NOT. Read your own nat table.
> 192.168.157.186   picoChip  management + radio. THE CHIP YOU ACTUALLY WANT.
> ```
> ⇒ ⭐⭐⭐ **`nmap <lan-ip>` interrogates the RALINK'S face, where the firewall is up.** A filtered
> or closed result is a fact about the Ralink, **not** about the management processor behind it.
> ⇒ **So the scan is not a decision procedure. It is a measurement of the wrong chip.**

### Step 1a — get the DHCP lease

Power on with Ethernet and find the lease. Call it `<ip>` below.

### Step 1b — ⭐ ADD THE HOST ROUTE, AND TALK TO THE RALINK DIRECTLY

**This is the step that was missing from every guide here until 2026-09-13.**

```sh
sudo ip route add 192.168.157.185/32 via <ip>
```

`[MEASURED — this is how .106 was rooted on 2026-09-13, over the network, no serial.]`
**It is additive and it is reversible** (`sudo ip route del 192.168.157.185/32`). It does not touch
the unit; it only teaches *your* host where the Ralink's internal address lives.

> ### ⚠️ **WHY THIS WORKS WHEN `ACCESS.md` USED TO SAY IT COULD NOT**
> The Ralink's `telnetd` is bound `-b 192.168.157.185` — its INTERNAL address. That is true, and
> the inference everyone drew from it — *"so every path to it goes through the picoChip"* — is
> **FALSE**. ⭐⭐ **A bind address decides which packets a daemon ACCEPTS. ROUTING decides which
> packets ARRIVE.** The Ralink owns the LAN address *and* `.185`, so a `/32` via the LAN address is
> delivered locally, straight to `telnetd`, **with no picoChip involved.**

Then:

```sh
telnet 192.168.157.185
```

> ### 🔴 **THE LOGIN DEPENDS ON THE BUILD, AND THIS STEP USED TO NAME ONLY ONE OF THEM**
> **This line read `# login: guest password: 1qaz@WSX` until 2026-09-17 — which contradicted the
> banner at the top of THIS FILE, where the account sets are recorded as DISJOINT.**
> ```
> FW:1.0.34            guest / 1qaz@WSX      <- no root account at all
> FW:1.0.31 · 1.0.29   root  / gemtekro      <- NO `guest` account at all
> ```
> ⇒ ⛔ **A reader on a 1.0.31 unit was being handed the one credential pair that cannot work there,
> and a failed login on this single-client `telnetd` is indistinguishable from a bricked board.**
> ⭐ **Read `cat /etc_ro/version` FIRST and pick the pair.** `[verified 2026-09-17 on a FW:1.0.31
> unit: `root`/`gemtekro` opens a BusyBox v1.8.2 shell; the banner's account table is correct.]`
> 📌 **`gemtekro` is a CRACKED HASH, not a vendor-published default** — Gemtek is the ODM, `ro` is
> `ro`(ot). ⚠️ **It is not guaranteed on every unit; if it fails, the hash is per-build, not per-device.**
> ☠️ **This is this corpus's own law firing on this file: a correction that updates one mention of a
> fact leaves the others reading as confirmation.** **The banner was added and this step was not.**

> ### ⚠️ **AND THE BIND ADDRESS IS *INTERNAL ONLY* — MEASURED, BECAUSE IT LOOKS LIKE A DEAD UNIT**
> ```
> 10.0.6.106:23        closed      <- the LAN address. Nothing listens here.
> 192.168.157.185:23   OPEN        <- the SAME CHIP, its internal address
> ```
> ⇒ ⭐ **Port-scanning the unit's LAN address tells you telnet is shut. It is not — it is bound
> elsewhere on the same silicon**, which is why Step 1c comes AFTER this and not before.

⇒ **If that opens, you have a shell on the gateway SoC and you do not need serial, the port scan,
or the backdoor.** For a clean root shell in one step, the corpus already ships the tool:

```sh
~/Projects/microcell/keys/dph151/rroot.py 'id'
```

`[MEASURED 2026-09-13 on .106: root, BusyBox v1.8.2 (2012-04-20).]`
Root without it: `rmm_client 192.168.157.185 cs_cmd "<command>"`.

### 🚪 **THREE NETWORK DOORS INTO THE RALINK, AND THEY ARE NOT INTERCHANGEABLE**

**All give root ON THE RALINK. None gives you the picoChip.** ⭐ **Pick by what you have.**

> ### 🔴 **THIS SECTION SAID "TWO DOORS" FOR ITS FIRST HOUR. IT IS THREE.**
> **I split `telnet` and `wizard` out of a one-line summary and left the THIRD mechanism inside
> it** — `rmm_client <ralink> cs_cmd "<command>"`, which ACCESS.md's route table calls *"IPC
> injection"*. ⇒ ☠️ **I fixed a conflation at one level and reproduced it one level down**, which
> is this corpus's own *"a correction that updates one mention leaves the others reading as
> confirmation"*, committed inside the correction itself.
> ⭐ **And `rroot.py` is NOT a fourth door** — it is a wrapper around `cs_cmd`. **Counting it
> separately inflates the list the same way the summary line deflated it.**

| | **telnet** | **the `wizard` UDP backdoor** |
|---|---|---|
| port | **tcp 23**, bound to the **internal** address | **udp 14677** |
| needs credentials | ✅ **yes** — and they are **build-dependent** (see above) | ⛔ **no. None.** |
| you get | ⭐ **an INTERACTIVE shell, with OUTPUT** | ⚠️ **BLIND execution — one command, no reply to you** |
| why blind | — | **it answers to hardcoded multicast `234.2.2.7`, NEVER to the sender** |
| proving it worked | you read the output | ⛔ **by SIDE EFFECT only** — fail0verflow's own method was *making the device ping them* |
| a port scan sees | `closed` on the LAN address, **open on the internal one** | **`open\|filtered` — and it can never read otherwise** |
| present on | every build here | `/bin/wizard` — **present on FW:1.0.31, verified 2026-09-17** |

### 🚪 **THE THIRD DOOR: `rmm_client … cs_cmd` — "IPC injection"**

```
rmm_client 192.168.157.185 cs_cmd "<command>"        runs as root on the Ralink
~/Projects/microcell/keys/dph151/rroot.py 'id'       a WRAPPER around the same verb, not a 4th door
```
⭐ **No telnet credentials needed, and unlike the wizard it is not blind.** ⛔ **But `rmm_client`'s
verb list also contains `factory_reset` and `crash`** — [`Trap 71`](TRAPS.md) — **so a typo in the
verb field is a different category of accident from a typo in a shell.**
⚠️ **This project prohibits firing `rmm_client` verbs for that reason.** **It is documented because
it works and because a reader will find it; it is not the door to reach for first.**

### 📻 **AND TWO PHYSICAL DOORS, FOR COMPLETENESS**
```
serial console  ttyS1 57600     UART header  (fail0verflow, 2012)
```
⚠️ **Both need the case open, which on a DPH-154 trips a one-way tamper latch — not an issue on a
151, but do not carry the habit across.**

> ### ⭐⭐ **PREFER TELNET WHENEVER YOU HAVE THE CREDENTIALS.**
> **An interactive shell with output is strictly better than blind execution on the same chip with
> the same privileges.** ⇒ ⛔ **The wizard is for the case telnet is NOT available** — wrong build,
> unknown password, or a unit whose `telnetd` is not running.
> ⚠️ **Do not reach for the backdoor because it sounds more capable. It is less capable.**

> ### ⛔ **AND NEITHER ONE REACHES THE picoChip**
> **`wizard` is a MIPS binary on the Ralink's filesystem, and the Ralink cannot reach the pico's
> filesystem by any route** `[measured with root, 2026-09-14]`. ⇒ **The pico is Phase 3, and its
> routes are a SEPARATE SET** — CMHS/XMPP, `rmm_client`, or the ACS software-download path.
> 📌 **Tool for the wizard path, already written:** `microcell/tools/dph151-backdoor.py`
> (negative control first, denominators printed, execution proven by side effect).

> ### 📌 **A U-BOOT VARIABLE NAMED `backdoor` IS NOT THIS, AND PROBABLY NOT WORTH TOUCHING**
> **`.106`'s U-Boot env carries `backdoor=0`** `[read 2026-09-17]`. ⛔ **NOTHING in the Ralink's
> userland reads it** — `grep -rl backdoor /etc_ro /sbin /bin /usr` is empty, against a passing
> control — **and it is absent from `/proc/cmdline`.** ⇒ **It is consumed by U-Boot itself, at
> bootloader stage.** ⚠️ **So setting it changes how the unit BOOTS, on hardware whose recovery is a
> serial console at `ttyS1 57600`** — **in exchange for, at most, a door you already have.**

---

### Step 1c — only now, knock — and know what each answer means

```sh
nmap -sT -p 22,23,80,443,8080,8090,20000 <ip>
nmap -sU -p 14677 <ip>
```

- **TCP 22** — DNATed through to the picoChip's `sshd`. See [`ACCESS.md`](ACCESS.md); the daemon is
  ancient and a modern client will refuse it three times for three different reasons.
  > ⛔ **PORT 22 HAS TWO GATES AND `nmap` CANNOT TELL THEM APART.** `[MEASURED, from `etc/init.d/sshd`
  > and `rcS`]`
  > ```
  > firewall REJECT            -> icmp-port-unreachable   ("filtered")
  > ACCEPT + loopback-only bind -> TCP RST                 ("closed")
  > ACCEPT + 0.0.0.0 bind       -> SYN/ACK                 ("open")
  > ```
  > ⭐ **Only the ICMP error text separates gate 1 from gate 2.** A RST means the packet REACHED the
  > picoChip and `sshd` was listening on `127.0.0.1:22` — `etc/init.d/sshd:64-68` binds to loopback
  > unless `ENV_VERBOSE_CONSOLE_ENABLED = TRUE`. **That is not a firewall and no firewall edit fixes it.**
- **TCP 8090** — the ip.access **DMI** management console. If this is open and
  unauthenticated you may be able to do everything below without a root shell.
- **UDP 14677** — the fail0verflow `wizard` backdoor (unauthenticated root command
  execution). Present on the 151 and reported still present on the 153. **A negative on a
  154 is a result worth writing down**, not a failure.
  > ⚠️ `[MEASURED]` **The literal `14677` appears NOWHERE in the bank3/bank4 initramfs images** —
  > decimal, hex `0x3955`, or byte-packed. Controls in the same search: `wizard` 8/10 hits, `bin`
  > 118, `sh` 254. **The `/bin/wizard` ELF and its `telnetd -b %s` ARE present.** ⇒ The off switch
  > is real (`cs_client set wizard/enable 0`); **the PORT NUMBER is not established from the image.**

## Phase 2 — Serial console — ⚠️ **NOT THE PATH WE USED, AND PROBABLY NOT YOURS**

> ### 🔴 **JP, 2026-09-13: *"my guide is wrong we didn't use serial we just did everythin gover the netowrk"***
> **Every unit brought up here — `.244` and `.106` — was reached OVER THE NETWORK.** `.244` via the
> CWMP/ACS path; `.106` via the Phase 1b host route + telnet. **No serial console was used on either.**
> ⇒ **Do Phase 1b before you open the case.** This section is kept for a unit that will not
> DHCP or answer on any port — a genuinely different failure from the one this guide used to send
> you here for.

Locate the UART pads. On the 151, fail0verflow used header **JP1** at **56700 baud** (try
57600 as well). **Use a 3.3 V-only adapter.**

Capture the whole boot log to a file. It is the single richest artefact you will get: it
names the boot order, the configuration mechanism, the inter-processor link, and exactly
what fails when the operator's infrastructure is unreachable.

## Phase 3 — Get a shell on the picoChip

**Three candidate routes. They are not "ways to manage the device" — they are three ways to reach a pico shell.**

> ### 🎯 **WHAT TO DO, IN ORDER. Stop at the first one that answers.**
> ```
> ROUTE 1  CMHS / XMPP        ✅ DEMONSTRATED on a DPH-151. Start here.
> ROUTE 2  rmm_client telnetd ⚠️  only if Route 1 is dead. Its verb list is a loaded menu.
> ROUTE 3  ACS / TR-069       📋 last. Via PATH D it also ends at a shell.
> ```

> ## 🎯 **AND IF YOUR UNIT REBOOTS AND SENDS NO INFORM — STOP HERE. IT IS PROBABLY NOT BROKEN.**
> ### **⇒ [`microcell/docs/findings/findings-106-never-provisioned-2026-09-13.md`](../../microcell/docs/findings/findings-106-never-provisioned-2026-09-13.md)**
> **A unit with a BOOTSTRAP pointer and no MANAGEMENT pointer asks the redirector *"where is my
> management server?"*, gets answered as though the redirector IS the server, and closes with
> nothing to say.** ⇒ ***A DECISION WITH NO WORK, not a timeout — and no number of power cycles
> changes it.***
> ### ✅ **THE DISCRIMINATOR IS ONE DNS OBSERVATION, FREE, NO SHELL, NO DEVICE CONTACT:**
> ***Does the unit EVER ask for a `cmhs*` name?*** ⛔ **NOT *which* names differ — an unprovisioned
> and a provisioned unit BOTH query `femtocell.*`.** ⭐ **The asymmetry lives in the part nobody
> lists.** 📌 **A provisioned unit also dials THREE hosts; an unprovisioned one dials ONE.**
> ⚠️ **POINTER, NOT A COPY — the evidence, the bounds and the two fix routes are in that file.**
> ### 🔴🔴 **ITS CENTRAL CLAIM IS NOW CONTRADICTED — 2026-09-14. DO NOT ACT ON IT.**
> `[team-lead, reading 151#1's OWN stored config — the WORKING unit.]`
> ```
> 151#1 (.244, WORKING)   management-server fields: EMPTY   ← the same "missing pointer"
> 151#2 (.106, SILENT)    management-server fields: EMPTY
> ⇒ IF BOTH ARE EMPTY, AN EMPTY MANAGEMENT POINTER CANNOT BE THE DIFFERENCE BETWEEN THEM.
> ```
> ⇒ ⛔ **The finding's cause — *"it has a bootstrap pointer and no management pointer"* — is refuted
> BY THE WORKING UNIT.**
>
> ### ✅ **AND THE CANDIDATE THAT REPLACES IT — [trap 72](TRAPS.md#72-two-physically-identical-dph-151s-one-registers-and-one-never-has--because-only-one-of-the-two-firmware-banks-ships-the-management-client)**
> **A DPH-151 carries TWO complete firmware banks, and on the image examined only ONE of them
> ships the management client** — the binary, its init script and its boot symlink are all
> absent from the other. ⇒ **A unit booted from that bank cannot contact a management server no
> matter how the network is arranged**, which predicts *every* symptom here including the empty
> fields on BOTH units. ⚠️ **It is a CANDIDATE, not a diagnosis: which bank a particular silent
> unit is running must be read from that unit's own boot log or filesystem.** ⚠️ **`dslg_cur_cfg` on `.244` is almost entirely the device describing
> ITSELF** — module versions, GPS firmware, tamper flag — **not operator provisioning.**
> ### ✅ **WHAT SURVIVES, AND IT IS STILL REAL — THE *OBSERVATION*, NOT THE *EXPLANATION***
> **`.244` queries `cmhs*` names and dials three hosts; `.106` queries only `femtocell` and dials
> one.** ⇒ **That asymmetry is measured and unexplained.** ⛔ **What is dead is the account of WHY.**
> ⇒ ⭐⭐ ***A finding can have a correct discriminator and a wrong cause, and the discriminator keeps
> working after the cause dies*** — which is exactly why this block is qualified rather than deleted.
> 📌 **And a unit-history difference is alive but currently unreadable:** `.244` carries a previous
> owner's stored GPS fix at a real Washington State deployment site ⇒ **it was deployed somewhere.**
> **The equivalent read on `.106` needs a shell we do not have.**
>
> ### 📕 **THE EARLIER QUALIFICATION, KEPT — ITS TIER POINT STILL STANDS INDEPENDENTLY:**
> ### 🔴 **QUALIFIED 2026-09-14, WITHIN THE HOUR — READ IT AS A CANDIDATE, NOT A CONCLUSION.**
> `[nebula-librarian3, who added this pointer and then found the gap. Findability is not neutral —
>  it AMPLIFIES whatever it points at, so a pointer to an untested conclusion is worse than none.]`
> ⛔ **THAT FINDING'S DISCRIMINATOR IS BUILT ENTIRELY ON `cmhs*` NAMES AND NEVER CONSIDERS `dpe*`**
> (`'dpe'` → 0 hits in it; `'cmhs'` → 3, so the reader works). **And the corpus is explicit that
> these are DIFFERENT TIERS:**
> ```
> cmhs*   = the CMHS / XMPP MANAGEMENT tier
> dpewe-* = Cisco DPE = Device Provisioning Engine = THE CWMP/ACS TIER — the one that carries Download
>           findings-lead-cwmp-breakthrough.md:18-20  "dpewe- is not one of them"
> ```
> ⇒ ⭐⭐⭐ ***"Does it ever ask for a `cmhs*` name?" CANNOT answer "can it do CWMP?"*** **A unit that
> never asks for `cmhs*` may be perfectly capable of CWMP.**
> ### ⚠️ **AND A SECOND EXPLANATION FITS EVERY OBSERVATION IN THAT FILE, UNTESTED:**
> **151#1 came to talk because TWO BUGS ON OUR SIDE were fixed — `dpewe-santa-clara` resolving to the
> CMHS box, and an ACS cert with the WRONG CN.** `[findings-lead-cwmp-breakthrough.md]` ⇒ **NOT
> provisioning history, NOT anything installed on the device.** ⇒ ***So "never provisioned" and "hitting
> the same our-side bug class" are BOTH consistent with the data, and only the first was tested.***
> ✅ **THE THREE QUESTIONS THAT SEPARATE THEM, none needing a power cycle:**
> **1.** does the unit query a `dpe*` name at all? **2.** does our DNS answer it, and to the RIGHT box?
> **3.** does that box's cert carry the CN the unit expects?
> **This block exists only so you arrive there before spending an evening, which is what it cost
> twice.** `[2026-09-13: written that morning, named for its conclusion, and re-derived that night
> at the cost of a power cycle. The corpus knew; nobody could find it.]`

### ⛔ READ THIS FIRST — IT COST US TWO SEPARATE EVENINGS

**1. The device only re-reads DNS and re-dials AT BOOT.**
⇒ **Every DNS change you make is INERT until you power-cycle the unit.** Change everything you
intend to change, *then* reboot once. `[measured — "~24 hours of null results" in the corpus]`

**2. ⛔ ~~`femtocell.wireless.att.com` is NOT a management server… answering it gets you a completed
TLS handshake, zero application bytes, and a hang-up.~~ RETRACTED 2026-09-13.**
`[lucid-console154, 0437e55, disproving their own mechanism; verified independently.]`
```
385 CWMP Informs in 9 days, ALL of them [ACS/femtocell] on 10.0.6.21
⇒ the address that name resolves to here IS A FULLY WORKING CWMP ENDPOINT.
.244 (WORKING) shows 19,352 silent closes AND 100 Informs
⇒ a completed TLS handshake followed by a silent close is NORMAL. It is a POLL, not a rejection.
```
⭐ **What is still true:** `femtocell.wireless.att.com` **IS** `CDPBaseURL` in the device's own
`cmhs_def_cfg.txt`. ⇒ ⭐⭐ ***But a name's role in the VENDOR'S CONFIG and the role of whatever YOU
POINT IT AT are different facts, and this guide conflated them.***
⛔ **Do not diagnose a fault from a single silent connection.** The healthy unit produced 19,352.

**3. The femto sends NO TLS SNI.** ⇒ The server picks **handler AND certificate by DESTINATION
IP**. **Each role needs its own address.** A name pointed at the wrong IP lands on the wrong
handler and closes silently.

---

**4. ⛔ `:22 CONNECTION REFUSED` IS THE *EXPECTED HEALTHY STATE* OF AN UNPROVISIONED UNIT — NOT A FAULT, AND NOT A FIREWALL.**
`dropbear` is **always running**. It is bound to **`127.0.0.1:22`** because `ENV_VERBOSE_CONSOLE_ENABLED`
is not `TRUE`. ⇒ ⭐⭐ **A refusal means "sshd is alive and listening on loopback", which is the
*success* state for a factory unit — not "the port is closed."**
```
SYN/ACK  -> sshd bound 0.0.0.0:22   (you have already won)
RST      -> sshd bound 127.0.0.1:22 (NORMAL. this is what a fresh unit does)
silence  -> filtered/dropped        (a firewall, a different problem)
```
⛔ **Do not spend an evening proving the RST came from the Ralink rather than the pico. Either way
this is the predicted reading.** `[cost: one full session, 2026-09-13]`

**5. ⛔ TWO REBOOTS ARE REQUIRED, AND ONE REBOOT LOOKS EXACTLY LIKE A FAILED PAYLOAD.**
```
reboot 1   the payload runs as root: key installed, flags written.  sshd STILL on loopback.
reboot 2   sshd reads TRUE at startup, binds 0.0.0.0:22.            SSH works.
```
**Why: `$( )` runs in a SUBSHELL, so an `export` inside it cannot reach the parent — and `sshd`
had already started with the old value.** ⇒ ⭐⭐⭐ **Anyone who checks for SSH after ONE reboot will
record a WORKING payload as a failure and go looking for a bug that is not there.**

**6. ⭐⭐⭐ `dmistart()` IS AN `if`/`else` — THE `init.dmi` RUNNER **XOR** THE `:8090` LISTENER. NEVER BOTH.**
```sh
if [ -f /var/ipaccess/init.dmi ]; then ipa-dmi -c "call init.dmi" &   # the RUNNER
else if [ "$ENV_START_DMI_TELNET" == TRUE ]; then ipa-dmi -u 8090 &   # the LISTENER
```
⇒ **This single line explains every *"the `:8090` listener will not start"* result, including
`dmistart start` appearing to do nothing.** **An `init.dmi` sitting on disk SUPPRESSES the listener.**
⇒ 🎯 **AND IT IS ALSO A ROUTE IN THAT NEEDS NO `:8090` AT ALL: upload an `init.dmi`** through the
commissioning UI's file field, carrying the same `set` lines. ✅ **Use this when `:8090` is closed —
which on a DPH-151 it is.**
> ### 🔴 **CORRECTED — "no DNAT" IS TRUE AND IS *NOT* THE BINDING CONSTRAINT. THE LISTENER WAS NEVER STARTED.**
> `[nebula-librarian3 2026-09-14, verified on the 563 tree — OUR train — not inferred from the 154.]`
> ```
> etc/init.d/opnormal:258-259   (563, apcfg-x)
>   # init.dmi script not present - check to see if ENV_START_DMI_TELNET is defined
>   if [ ${ENV_START_DMI_TELNET:-"FALSE"} == "TRUE" ]; then     ⬅ DEFAULTS TO FALSE WHEN UNSET
> ENV_START_DMI_TELNET in every nv_env.sh we hold: pico-fs 0 · femto-ssh/stage 0 · 154 rwstore 0
> ```
> ⇒ ⭐⭐⭐ **UNSET ⇒ `"FALSE"` ⇒ `ipa-dmi -u 8090` NEVER STARTS ⇒ NOTHING IS LISTENING — from the LAN
> *or from inside the unit*.** ⇒ ⛔ **EVEN WITH A DNAT THERE IS NOTHING ON THE OTHER END.**
> ⇒ ☠️ **So "no DNAT" sends you to the FIREWALL when the fault is in the BOOT SCRIPT.** ⭐ ***A true
> statement one level above the real constraint is worse than a false one: it survives checking.***
> ✅ **AND IT RELOCATES THE QUESTION:** the `init.dmi` RUNNER branch needs **no listener, no
> `ENV_START_DMI_TELNET`, and no port** — only a FILE at `/var/ipaccess/init.dmi` on the pico.
> ⇒ **With Ralink root the question becomes *"can the Ralink WRITE to the pico's filesystem?"***
> ### 🔴 **AND THAT QUESTION IS NOW ANSWERED: NO. MEASURED 2026-09-14 WITH ROOT ON `.106`'s RALINK.**
> `[team-lead: "The Ralink cannot reach the pico's filesystem by any route." A clean measured no,
>  taken from inside the unit with root — not inferred.]`
> ⇒ ⛔ **SO THE `init.dmi` ROUTE IS CLOSED ON A DPH-151 TOO, for a different reason than `:8090`:**
> ```
> :8090 listener   -> never started (ENV_START_DMI_TELNET defaults FALSE)   ⛔
> :80  upload UI   -> DNAT'd to the pico, which REFUSES it                  ⛔
> init.dmi RUNNER  -> needs a FILE on the pico; the Ralink CANNOT WRITE IT  ⛔ ← measured
> ```
> ⇒ ⭐⭐ **ALL THREE DMI DOORS ARE MEASURED SHUT ON AN UNPROVISIONED DPH-151.** **Not inferred, not
> one at a time by assumption — each closed by its own measurement, for its own reason.**
> ⭐ **THAT IS WORTH MORE THAN A WORKING ROUTE WOULD HAVE BEEN TO THE NEXT READER:** it converts
> *"try DMI"* from an open-ended afternoon into a settled no, **and names what would have to change
> for each door to open.** ⇒ **The remaining paths need SERIAL or a SHELL — and those are decisions,
> not experiments.**
> ⛔ **BOUND: `opnormal` read from the 44-file 563 subset and the 579 tree; `nv_env.sh` absence is
> from DONOR/DUMP copies. `.106`'s own files are UNREAD.** ⇒ **Strong prediction, not a measurement
> of the unit.**
⭐ **Once root persists, DELETE `init.dmi`** and `:8090` listens natively.

> ### ⛔ **BOUND ON ROUTE B, MEASURED ON `.106` THE SAME NIGHT — THE DOOR MAY BE SHUT TOO.**
> `[lucid-console154, live measurement on 151#2. I wrote this route from the nano3G guide; they
>  measured its precondition on the unit it was aimed at.]`
> **The commissioning-UI file upload rides `:80`. On a DPH-151 that port IS DNAT'd through to the
> pico — and `.106`'s pico REFUSES it exactly as it refuses `:22`.**
> ⇒ ⚠️ **So *"use Route B when `:8090` is closed"* is a real route with an UNMET PRECONDITION on
> this unit.** ⭐ **Reachability is MEASURED; the upload itself is UNTESTED.**
> ⇒ ⭐⭐ **The honest statement: `:8090` and `:80` are DIFFERENT doors, and on `.106` BOTH are shut.
> Route B is not refuted — it is BLOCKED HERE, for the same reason `:22` is.**
> 📌 **The bound is INSIDE the claim rather than beneath it, deliberately:** ***a bound in an
> adjacent sentence is not attached to the number.*** **A route recovered from ANOTHER DEVICE'S
> guide arrives with its preconditions unmeasured on yours** — *same sink, different door, and the
> second door needs its own measurement.*

> ### ⚠️ **DEVICE SCOPE ON ITEMS 4-6 — READ BEFORE RELYING ON THEM**
> **These three are measured on the ip.access nano3G and are written up in
> [`BRINGUP-NANO3G.md`](BRINGUP-NANO3G.md) Phase 3.** ⭐ **The transfer case is unusually strong and
> it is STATED, not assumed: the nano3G runs `563.16.0` and the DPH-151 runs `563.21.8` — the SAME
> `563` TRAIN** (`HARDWARE.md:143`). ⇒ **The DPH-153's `579` is a different train and these should
> NOT be carried there.**
> ⛔ **What does NOT transfer is the TRANSPORT.** The nano3G reaches the DMI console on `:8090`
> directly; **the DPH-151's Ralink has no DNAT for `:8090`** — ⚠️ **and that is TRUE but NOT the binding constraint: THE LISTENER IS NEVER STARTED. See the correction above in this same file (§ *"CORRECTED — 'no DNAT' IS TRUE AND IS NOT THE BINDING CONSTRAINT"*).** ⇒ ***Same sink, same attribute, same
> train — different door.*** **That is exactly why item 6's `init.dmi` route matters here.**

### ⭐ ROUTE 1 — CMHS / XMPP  `[✅ DEMONSTRATED on a DPH-151]`

**The management channel is the EIGHT `cmhs*` servers in the device's own config**
(`/opt/cisco/cmhs_def_cfg.txt`, `…MHS.Config.DefaultServerURLs`):

```
cmhsse-decatur        cmhsse-lake-mary          <- SE      cmhsce-carrollton   cmhsce-hazelwood   <- CE
cmhsne-rochelle-park  cmhsne-columbia           <- NE      cmhswe-santa-clara  cmhswe-santa-ana   <- WE
                                    all .wireless.att.com
```

**DO THIS:**
1. Point **all eight** names at your CMHS endpoint.
2. Serve `certs/cmhs/cmhs-multisan.pem` + `.key` (covers all eight).
   ⛔ **Do NOT regenerate it.** `mk-cmhs-cert.sh` mints a NEW key every run, which pairs with
   nothing already deployed.
3. **POWER-CYCLE THE UNIT.** Nothing above takes effect until you do.

**✅ WHAT SUCCESS LOOKS LIKE** `[measured on the wire, held >100 s]`:
```
SASL EXTERNAL -> <success>
bind -> jid = <OUI>-<SN>@cmhsce-carrollton/wan     *** BOUND ***
presence / CMHSStatus received
ping -> pong
```

> ⚠️ **`XMPPDomainName` is EMPTY, so the client derives its XMPP domain from the FIRST LABEL of
> the FQDN it dialled.** ⇒ **Answer the wrong name and it derives the wrong domain** — which
> predicts the silent-close symptom exactly.

---

### ROUTE 2 — `rmm_client <pico> set_telnetd`   ⚠️ only if Route 1 is dead

> ### ☠️ **PASTE THIS VERB. NEVER TYPE IT.**
> `rmm_client`'s verbs live in one flat list with no confirmation and no `--force`:
> ```
> reset  factory_reset  clear_tamper  do_software_download  get_software_status
> set_bandwidth  get_bandwidth  switch_fw_boot  set_telnetd  set_port_fwd
> get_uptime  cs_cmd  sleep  crash
> ```
> ⛔ **`factory_reset` and `crash` are neighbours of the verb you want.** `switch_fw_boot` is a
> **sticky** bank flip the AP does not recover from on its own. Full detail: [`TRAPS.md`](TRAPS.md) trap 71.

⚠️ **This route may not exist on your unit.** The RMM responder on tcp/3001 was recorded **DOWN**
on one DPH-151 — **every `rmm_client` verb failed while the port stayed open.**
⭐ **Open and RSTing is not the same as serving.** A successful connect does not mean a responder.

---

> ### ⚠️ **THE ACS LOG LIES REASSURINGLY — READ THIS BEFORE YOU TRUST IT**
> `[restored 2026-09-13: my own edit 507ae00 deleted this block while replacing a neighbouring one.]`
> **`TLS-OK clientcert=len=1006` is the loudest success line in the ACS log — printed 1,375× in six
> hours — and it certifies THE TRANSPORT ONLY.** ⇒ **The log reads healthy while nothing provisions.
> Every one of those sessions ends `peer closed (state=init)`.**
>
> ### ⭐ **THE PRECISE SHAPE, AND IT IS THE SAME ON BOTH UNITS** `[measured 2026-09-13]`
> **BOTH units COMPLETE the TLS handshake, send ZERO APPLICATION BYTES, and hang up.**
> ⇒ **Two handlers, two log strings, one silence.**
> ⛔ **There is NO TLS fault.** An earlier *"29 % of handshakes fail"* reading was **refuted**:
> every apparent failure is the lower port of a concurrent pair the device abandons, and **every
> solo connection succeeds.**
> ⇒ ⭐ **So do not debug the transport. It works perfectly and carries nothing.**

> ## 🔴🔴 **A DEVICE THAT COMPLETES TLS AND SENDS NOTHING — WHAT IS MEASURED, AND WHAT WAS RETRACTED**
> ### ⛔⛔ **RETRACTED 2026-09-13 ~23:57: THE 12–17 ms "TLS-OK THEN CLOSE" IS *NORMAL*. THE WORKING DEVICE DOES IT TOO.**
> `[lucid-console154, 0437e55, disproving their own earlier mechanism. Verified independently here.]`
> ```
> .244 (WORKING)   19,352 peer-closed events   AND   100 CWMP Informs
>                  one traced tuple: TLS-OK 15:48:37.062 -> closed .077 (15 ms, nothing sent)
>                  ...5.5 min later, SAME endpoint -> CWMP Inform -> ACS sends GetParameterNames
> ⇒ a silent close is an IDLE/POLL CONNECTION, NOT A REJECTION.
> ```
> ⇒ ⛔ **So "completes TLS and says nothing" is NOT by itself a fault.** **Do not diagnose from a
> single silent connection — the healthy device produced 19,352 of them.**
>
> ### 🔴 **AND `10.0.6.21` IS THE ACS, NOT A "FILE-DOWNLOAD HOST". THIS GUIDE SAID OTHERWISE.**
> ```
> 385 CWMP Informs in 9 days   ALL of them  [ACS/femtocell]   ⇒ .21 is a FULLY WORKING CWMP endpoint
> ```
> ⚠️ **`femtocell.wireless.att.com` IS `CDPBaseURL` in the device's own `cmhs_def_cfg.txt` — that
> part is measured and stands.** ⛔ **But the IP it resolves to here is our working ACS, so
> "answering that name is the wrong role" was WRONG.** ⇒ ***A name's role in the vendor's config
> and the role of whatever you point it at are different facts.***
>
> ### ✅ **WHAT SURVIVES, AND IT IS THE ANOMALY RATHER THAN THE EXPLANATION**
> ```
> .106   0 Informs in 9 days      .244  100      .127  284
> .106   never resolves a cmhs* name, ever                    [openwrt-f8]
> .106   ONE destination          .244  THREE
> ```
> ⇒ ⭐ **`.106` is dialling a FULLY WORKING CWMP ENDPOINT AND DECLINING TO SPEAK ON IT.** **The
> asymmetry was never in doubt; the *why* was wrong.**
> ### 🔑 **THE LEADING CANDIDATE — team-lead's, and STILL UNMEASURED**
> **`ipaSslValidateTa` checks whether the peer sent a copy of one of the device's OWN TRUST
> ANCHORS — chain MEMBERSHIP, not identity — and it runs AFTER the handshake, which is exactly
> where `.106` stops.** ⚠️ **The 2026-09-04 experiment that "definitively closed" server-cert
> identity varied CN and SAN, which `ipaSslValidateTa` never looks at.** ⛔ **Stated as a
> candidate. Nobody has measured it.**
> ### ⛔ **AND "IT ACCEPTED OUR CERTIFICATE" IS UNSUPPORTED EITHER WAY**
> **In TLS the client sends its certificate AFTER receiving the server's — so completing a
> handshake is not evidence the device accepted your chain.**
> `[measured 2026-09-13 on a factory DPH-151: completes mutual TLS with a valid factory Cisco
>  certificate and closes 12–17 ms later having sent ZERO APPLICATION BYTES. Endpoint, handler,
>  server cert, full chain, all three trust anchors, client cert, DNS, routing, NTP and firewall
>  were each tested and each eliminated.]`
>
> ### ⭐⭐⭐ **A FACTORY UNIT HAS A *BOOTSTRAP* POINTER, NOT A *MANAGEMENT* POINTER**
> ```
> hw_description.dat  REDIRECTOR_URL  — where to ask "WHERE IS MY MANAGEMENT SERVER?"
> provisioning        converts that into an actual management server URL
> ⇒ a unit that never completed provisioning dials its REDIRECTOR and expects a REDIRECT.
>   Answer it as though you ARE the management server and it closes without speaking.
> ```
> ### ⚠️ **AND `REDIRECTOR_URL` IS DEFINED TWICE IN `hw_description.dat`, WITH DIFFERENT VALUES**
> ```
> line 57-60   https://Femtocell.wireless.att.com:7547/acs
> line 73-76   https://Femtocell.wireless.att.com            <- NO PORT ⇒ defaults to :443
> ```
> ⭐ **MEASURED 2026-09-13: the device dials `:443`** (16 observed connections) ⇒ **the loader takes
> the SECOND, portless duplicate.** `[this settles a question findings-segw-trigger.md:223
> explicitly left open: "whether the loader takes the first or the last duplicate is not
> established here."]`
> ⇒ ⛔ **Until that was measured, *"the device never dialled CWMP"* and *"the device dialled a
> CLOSED PORT"* were indistinguishable from every observation anyone had taken.**
>
> ### ✅ **THE DISCRIMINATOR: DID THIS UNIT EVER GET PROVISIONED?**
> **A unit that HAS been provisioned asks for its management server BY NAME** (on this family, a
> `cmhs*` name from `DefaultServerURLs`). **A unit that has NOT only ever dials its redirector.**
> ⇒ ⭐ **Check which names it asks for in DNS. That one read separates the two cases** — and it
> needs no shell, no reboot, and nothing on the device.
>
> ### ⛔⛔ **AND IF THE ANSWER IS "NEVER PROVISIONED", THE DOCUMENTED PATH ENDS HERE.**
> **This is an OPEN DECISION, not a procedure. It is written down so the next reader inherits the
> decision rather than re-deriving it at 23:30.** `[state as of 2026-09-13]`
> ```
> WHAT IS KNOWN
>   the device asks its redirector and accepts no other conversation on that endpoint
>   every transport-layer variable has been tested and eliminated (endpoint, handler,
>     server cert, full chain, all three trust anchors, client cert, DNS, routing, NTP, firewall)
>   .244 IS provisioned and .106 is not — so the difference is history, not hardware
>
> WHAT IS NOT KNOWN
>   what a correct redirector RESPONSE looks like to this firmware. Nobody here has seen one.
>   whether the device would accept a management URL it was handed, or only one issued
>     by a party it already trusts
> ```
> ### 🔑 **THE DECISION, STATED PLAINLY**
> ***Do you emulate the operator's REDIRECTOR — a protocol nobody here has observed — or do you
> obtain a shell by a route that does not need the management plane at all?***
> ```
> EMULATE THE REDIRECTOR   no case opening, no hardware risk, works at scale if it works at all.
>                          ⛔ BUT: an unobserved protocol, reverse-engineered against one unit,
>                            on JP's production ACS.
> A NON-MANAGEMENT ROUTE   serial/UART is the only one not yet eliminated on a cold unit.
>                          ⛔ Case opening. ⚠️ Measure the pin voltage first — only the
>                            Ralink's 3.3 V is established. See Phase 2.
> ```
> ⚠️ **Both are real options and this guide does not choose between them.** ⭐ **What it does say:
> every CHEAP avenue is now closed by measurement rather than assumption, so whichever is picked
> starts from a tested position instead of a hopeful one.**

### 🔀 **BEFORE ROUTE 3: IF YOU ALREADY HAVE THE DMI CONSOLE, THERE IS NO RACE TO RUN**

> ### ⭐⭐⭐ **ADDED 2026-09-16. ROUTE 3 IS A 30–60 SECOND RACE AND IT IS NOT THE ONLY WAY TO THAT SINK.**
> ```
> ROUTE 3 (below)          reboot + a running catcher + a served package + WIN A RACE
> diagnosticTuning (2320)  one DMI write. No reboot, no race, no package, no window.
> ```
> ⇒ **Both end in the same place: an `export` line in `/var/ipaccess/nv_env.sh`, sourced as root.**
> ### 🔴🔴 **BUT ON A DPH-151 THE CALM ROUTE IS *NOT AVAILABLE*, AND I ALMOST TOLD YOU IT WAS.**
> `[caught before publication, from this repo's own nano3G guide, which states it as measured]`
> ```
> DMI :8090   nano3G   ✅ LISTENS AND WORKS — it is the route that rooted that unit
>             DPH-151  ⛔ NEVER STARTED. opnormal:258 gates it on ${ENV_START_DMI_TELNET:-"FALSE"},
>                         which is absent from every nv_env.sh held. Shut on BOTH 151s, and shut
>                         even with a port-forward.
> ```
> ⇒ ☠️☠️ **AND THE DEPENDENCY IS CIRCULAR: to use `diagnosticTuning` you need the DMI console; to
> start the DMI console on a 151 you must set `ENV_START_DMI_TELNET` in `nv_env.sh`; and writing
> `nv_env.sh` is the thing you were trying to achieve.**
> ⇒ ✅ **SO ON A DPH-151, ROUTE 3 REALLY IS THE WAY IN. Run the race.**
> ⭐ **The calm route is for the nano3G, and for a DPH-154 it is CWMP instead** —
> 📌 [`ACCESS.md`](ACCESS.md) Route 6 → the third write path · [`BRINGUP-DPH154.md`](BRINGUP-DPH154.md) Phase 2.
> ### ⭐⭐⭐ **KEPT VISIBLE BECAUSE THE NEAR-MISS IS THE LESSON**
> **I found a cheaper mechanism, confirmed it reaches the same sink, and wrote "if you have the
> console, take the calm route" — WITHOUT CHECKING WHETHER THIS MODEL HAS THE CONSOLE.** ⇒ ***A
> route's PRECONDITION is per-model, and a mechanism that is real on one unit is not thereby
> available on another.*** **That is this corpus's per-device scoping rule, firing on the edit
> written to document a per-device availability trap.**

> ### ⚠️ **AND WHICHEVER ROUTE YOU TAKE, THE NV WRITE IS DORMANT ON ARRIVAL**
> **Writing `nv_env.sh` APPENDS and does nothing else** — no source, no restart, no signal.
> ⇒ **You write it, you watch, and nothing happens, because it is sitting armed.** ⛔ **That reads
> as failure and sends people back to riskier methods.**
> ✅ **Trigger it deliberately: a LOGIN is the cheapest** — `/etc/profile` sources the file
> unconditionally, and on these units a login is a root login (one uid-0 account, no non-root
> interactive account). 📌 **Ten consumers source it, so it fires eventually anyway — but
> "eventually" is not a step.**

### ⭐ ROUTE 3 — ACS / TR-069 → **PATH D**   `[✅ THIS IS HOW .244's PICOCHIP GOT ROOT]`

⭐ **CWMP gives READ *and* WRITE** — 543 parameters, identity and PLMN. ⛔ **It does NOT reach
`IUH_ENABLE`, the `iapc-gw-shim`, or `picoinit`, so it cannot make a cell serve.**
⇒ ✅ **Its value is PATH D — the CWMP route TO a shell, and it is the ONLY documented route that
reaches the picoChip from scratch:**
```
reboot -> device sends "1 BOOT", re-reads DNS -> management session completes
       -> ACS issues Download RPC -> femto fetches the sdphook package (type 0x5007)
       -> post_swdl_hook SOURCES IT AS ROOT -> enables sshd + installs a key
       -> ssh root@192.168.157.186
```

> ### ⭐⭐⭐ **WHAT THE `0x5007` PACKAGE ACTUALLY IS — AND WHY IT IS *NOT* THE DESTRUCTIVE KIND OF DOWNLOAD**
> **`0x5007` "sdphook" is a package whose payload is A SHELL SCRIPT**, and `post_swdl_hook`
> **sources it as root BEFORE its own destructive teardown.**
> ```
> your script runs as root
>   ... do the payload ...
> exit 0      ⬅ ⭐ RETURNS FROM THE SOURCED SCRIPT and SKIPS post_swdl_hook's
>                delete_config / switching_bank tail
> ```
> ⇒ ✅ ***"It never writes a firmware bank, so the active image stays verifiable."***
> ⛔ **Do not confuse this with serving a full firmware IMAGE**, which runs `activate_bank` →
> `uboot-install` and **rewrites both U-Boot banks irreversibly.** ⭐ **Same machinery, two package
> types, opposite risk** — 📌 [`BRINGUP-DPH154.md`](BRINGUP-DPH154.md) has the side-by-side table.
> ### ✅ **WHY IT NEEDS NO SIGNATURE**
> **Image signing is OFF on these builds (`verifyflash` disabled).** ⇒ **The package needs only its
> three internal CRCs and a well-formed header** — no key, no vendor cooperation.
> ### ⚠️ **THE DETAIL THAT PUTS THE UNIT IN A RETRY LOOP IF YOU MISS IT**
> **The `Download` RPC's `FileSize` MUST EQUAL THE SERVED BYTE COUNT EXACTLY.** ⛔ **Otherwise the
> femto fetches a truncated image, the apply fails, and it loops.** ✅ **`stat -c%s` the package and
> put that number in the RPC.**
> ### 📋 **AND THE HOOK HAS A JOB BEYOND THE PAYLOAD — LEAVE NO PENDING UPGRADE**
> ```
> 1. kill the upgrade transaction:  rm cisco/UpgradeBeforeReboot cisco/VersionBeforeReboot
>    fw_setenv bank <good> · bootcount 0 · flip Upgrade.Current.InProgress true->false
>    ⚠️ busybox sed needs UPPERCASE N for the {N;s|...|} join — lowercase n silently no-ops
> 2. the payload: setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED TRUE, install YOUR key (root-owned,
>    dir 700 — dropbear REJECTS group-writable)
> 3. exit 0
> ```
> ⛔⛔ **MINT YOUR OWN KEYPAIR. The `cwmp_rce_key` referenced by the upstream tooling has its
> PRIVATE half in a public GitHub repository** — installing it authorises the internet.
`[findings-dph151-root-baseline.md:1-4 — "first root baseline, measured 2026-09-05 21:59Z…
 read off the device over SSH as uid=0 on the pico"]`

> ### ⏱️⏱️ **THE WINDOW IS 30–60 SECONDS AND THE UNIT CLOSES IT ITSELF. THIS IS A RACE.**
> **SSH opens, then the unit AUTO-REBOOTS and shuts it off again.** ⇒ **Everything below must be
> STAGED AND RUNNING BEFORE you power-cycle. You cannot set it up once the window is open.**
> ```
> 1. A CATCHER, already running: poll :22 every second, and TRY BOTH KEYS the instant it answers.
> 2. On connect, IMMEDIATELY write the key to  /var/ipaccess/root_home/.ssh/authorized_keys
>    ⭐ jffs2 — it SURVIVES the self-reboot. The rootfs does NOT.
> 3. Set the two nv_env flags so sshd stays bound across later reboots:
>       ENV_VERBOSE_CONSOLE_ENABLED=TRUE      ENV_FIREWALL_DISABLED=TRUE
> ```
> ### ⛔ **KILL ONLY THESE THREE. NOT `DslmSsp`.**
> ```
> ✅ killall rmmwd swdl_client post_swdl_hook
> ⛔ DslmSsp is THE MAIN APPLICATION. The upstream persistent_ssh.sh kills it — that list is
>    written for a unit ABOUT TO REBOOT from a pending SWDL transaction, where killing it
>    PREVENTS the reboot. On an otherwise-healthy unit it PLAUSIBLY CAUSES the reboot it is
>    meant to prevent.   [findings-dph151-root-baseline.md:33]
> ```
> ### ⛔ **INSTALL BOTH PUBLIC KEYS — THE v7 RUN FAILED ON EXACTLY THIS**
> ### 🔴🔴 **BUT NOT *THOSE* TWO KEYS — READ THIS BEFORE THE BLOCK BELOW.**
> `[nebula-librarian3, 2026-09-13. This file CONTRADICTS ITSELF twelve lines apart and BOTH sides
>  are marked ⛔ — the hazard has the better story, so it is the one that gets followed.]`
> ```
> :424 (this line)  "INSTALL BOTH PUBLIC KEYS"        <- an imperative, with a worked failure case
> :436 (12 lines on) "the upstream hook installs a PUBLISHED private key ... mint a fresh pair"
> ⇒ OPPOSITE INSTRUCTIONS ABOUT THE SAME KEY. The reader who obeys the first installs a key
>   whose private half is downloadable from a public GitHub repo.
> ```
> ⭐⭐ **THE v7 LESSON IS REAL AND IS NOT WHAT IS WRONG HERE.** A key MISMATCH between what the hook
> installs and what you authenticate with gives `rc=255` and is indistinguishable from a lost race.
> **Install BOTH halves of the pair you intend to use.** ⛔ **The error is in WHICH pair.**
> ```
> b22d85d26763594a  "cwmp_rce_proof pounce-rce"  🔴 private half = microcell/tmp/DPH153-AT/cwmp_rce_key
>                                                   origin github.com/nickvsnetworking/DPH153-AT  PUBLIC
> 38cb81eb65f12ad1  "dph151-jp"                  ✅ JP's own
> ```
> ✅ **USE JP'S KEY PLUS THE FRESH PAIR MINTED FOR THIS** —
> `~/Projects/microcell/keys/dph151/dph151_nebula_2026-09-13` (RSA-2048, `0600`, private half has
> never left katana). **That is `:436`'s "mint a fresh pair" instruction, already carried out.**
> ⛔ **Strike `pounce-rce` from any hook before serving it.** 📌 Full banner: `ACCESS.md`.
> ```
> the retry authenticated with  cwmp_rce_key   the hook had installed  dph151-jp
> DIFFERENT KEYS -> rc=255, six consecutive times.
> ⭐ A LOST RACE AND A REJECTED KEY ARE INDISTINGUISHABLE FROM OUTSIDE — both are "no shell".
>   Only the RETURN CODE separates them, and it was visible only because the catcher logged rc.
> ✅ v8 installs BOTH. Log the rc, always.   [findings-dph151-root-baseline.md:47]
> ```

⛔ **Assert the payload's HASH before serving it — never select it by path.** Three paths carry the
unversioned name `rmm-selfclean.sdp` and two hold a **superseded** payload; the current one carries
its version in the name, so a glob on the bare name **cannot reach it**.
⛔ **And the upstream hook installs a PUBLISHED private key** (tracked in a public third-party
repo). **Mint a fresh pair before ever driving this.**

---

### ONCE YOU HAVE A CHANNEL — verify the transport before trusting any silence

You need to issue **DMI** get/set/action commands on the radio processor; everything in Phases
4–6 is expressed in those terms. See [`ACCESS.md`](ACCESS.md).

> ⚠️ **Use the transport that answers, not the one that looks right.** On our DPH-151 the
> `-u 8090` telnet front end **accepts input and never answers a `get`** — bare LF, CRLF and
> Telnet linemode negotiation all return a banner and a `dmi>` prompt and no result — while the
> local one-shot client returns answers to the identical commands. **The commands are
> byte-identical; only the transport differs.**

✅ **Positive control:** read an attribute you know exists — `get hnbGwAddress`. If it comes back,
a later miss means the attribute NAME is wrong. **If it does not, your transport is dead and every
subsequent "not found" is meaningless.**

> ### ⚠️ **A SEPARATE, REAL DEFECT ON `.106`: IT HAS NO TIME SOURCE** `[measured 2026-09-13]`
> ```
> .106   418 x NTP attempts to AT&T servers — correctly BLOCKED by our egress rules. No clock.
> .244   uses a LOCAL source (10.0.6.1), taken from hw_description.dat.       Clock OK.
> ```
> ⛔ **NOT the cause of the provisioning silence** — ⭐ *a clock fails CONSISTENTLY, and this
> symptom is intermittent across units that share it.* **Recorded as a standalone defect so the
> next reader does not adopt it as an explanation, and does not re-discover it either.**
>
> ### ☠️ **AND THE OBVIOUS FIX DOES NOT SURVIVE A REBOOT — MEASURED THE HARD WAY, 2026-09-13**
> **A live `iptables -t nat -I` redirect on the RALINK fixes the clock and then EVAPORATES.**
> `[the Ralink's root filesystem is an INITRAMFS EMBEDDED IN THE KERNEL — ACCESS.md:283. Nothing
>  written at runtime survives. A lane applied the redirect, reported the clock fixed, and the
>  next reboot wiped the NTP redirect, the MASQUERADE and the access rules together.]`
> ⇒ ⭐⭐ ***On the Ralink, "I fixed it" and "I fixed it until the next reboot" are the same
> action.*** **Any rule you need to keep must be re-applied by something that runs at boot.**

## Phase 3b — 🔑 **MAKE ROOT SURVIVE A REBOOT — do this BEFORE anything else**

**`[Recovered live off 151#1 by team-lead, 2026-09-14, after JP said "we somehow lost the info".
It was never written down as a PROCEDURE — `mtdblock4` and `rsa_host_key` appeared NOWHERE in any
guide. This section exists so it cannot be lost a third time.]`**

> ### ⭐⭐⭐ **WHY IT WORKS ON THE PICO AND NOT ON THE RALINK — learn this or the rest is cargo**
> ```
> pico    /var/ipaccess  =  jffs2 on mtdblock4   ⇒ REAL FLASH. Survives a reboot.
> Ralink  /var, /tmp     =  ramfs (initramfs)    ⇒ RAM. Wiped every boot, and the firmware
>                                                   ships NO sshd and NO dropbear at all.
> ```
> ⇒ **Persistence on the pico is a FILE. Persistent SSH on the Ralink would be a FIRMWARE CHANGE** —
> or a re-push from the pico every boot, proposed and unbuilt
> (`microcell/docs/findings/findings-morpheus3gkeep-ralink-ssh.md`).
> ### ⭐⭐⭐ **BUT DO NOT READ THAT AS "RALINK ACCESS IS LOST AT REBOOT" — IT IS NOT.**
> > ***"The telnetd is not persistent. THE MEANS OF CREATING IT IS."***
> > `[findings-nebulatopology-ralink-ssh.md:91 — `wizard` is in the firmware image]`
> ```
> MEASURED   telnetd open on .185:23 AFTER a reboot · telnetd -b 192.168.157.185, PID 986
>            guest / 1qaz@WSX is FIRMWARE-CLASS — it is in the image, a reboot cannot remove it
> ⛔ UNEXPLAINED  telnetd is ramfs-resident, AND `#telnetd` is COMMENTED OUT in rcS on BOTH
>            Ralink rootfs images held here (rootfs3:54 · rootfs4:56), whose inittabs run
>            rcS as sysinit. ⇒ THE FIRMWARE I CAN READ DOES NOT START IT, AND IT IS RUNNING.
> ```
> ### 🔴 **REFUTED 2026-09-14 — IT IS **NOT** INIT-STARTED AND **NOT** THE INITRAMFS. IT WAS REPARENTED.**
> `[lucid-console154 closed their own bound against their own claim, on the live box.]`
> ```
> LIVE .106:  telnetd PPID = 1        AND   #telnetd IS commented out in the LIVE rcS
> ⇒ init did NOT start it. A daemon whose launcher EXITED is REPARENTED to init and
>   is indistinguishable from an init-started one by PPID alone.
> ```
> ⇒ ⛔ **So *"started by init, therefore firmware-restored"* is DEAD, and with it *"a reboot cannot
> remove it."*** ⭐ **PPID 1 is not evidence of parentage — it is evidence of ORPHANHOOD OR parentage,
> and the two are identical from outside.**
> ### ⭐⭐ **THE NEW CANDIDATE, AND IT CHANGES THE CLASS OF THE ANSWER**
> **`rmm_client`'s verb list contains `set_telnetd`** ⇒ **persistence would be via the CONFIG STORE,
> not the firmware image.** ⇒ ⚠️ ***A config-store value CAN BE CHANGED. A firmware binary cannot.***
> **So the durability of our only foothold on that chip rests on a stored setting, not a guarantee —
> and nobody has read that setting.** ⛔ **UNMEASURED. Do not plan on it either way.**
> ### ✅ **WHAT SURVIVES, AND IT IS STRONGER THAN BEFORE**
> **telnetd returned after TWO reboots today, both times as PID 986** ⇒ **whatever starts it is
> deterministic and boot-time.** ⭐ **The empirical claim gained a second observation while the
> mechanism lost its explanation** — ***which is the normal shape of progress, not a setback.***
> 📌 **And a note on my own part in this: my `rcS` images agreed with the live box — and they were
> still the WRONG SPECIMEN** (2011 Ralink OEM firmware). ⇒ ***Being right for the wrong reason is
> not being right***, and I withdrew that evidence correctly even though its conclusion held.
> `[lucid-console154, 25ad49f, live. This closes the discrepancy flagged below — which was real,
>  and whose resolution is that I was reading the wrong startup path.]`
> ```
> ✅ MEASURED TWICE   telnetd present AFTER a reboot — the ~15:50 reboot, and again after the
>                    2026-09-14 power cycle. It CAME BACK BOTH TIMES.
> ✅ MEASURED         #telnetd IS commented in rcS  ⇒  rcS is NOT what starts it
> ⚠️ INFERRED         that it comes from the INITRAMFS specifically. The "started by init" reading
>                    was taken from `ps` WITHOUT CHECKING PPID — and a daemon whose launcher has
>                    exited is REPARENTED to init and looks identical.
> ```
> ⇒ ✅ **WHAT YOU CAN RELY ON: something in the boot path restarts it, and it has survived two
> reboots.** ⛔ **WHAT IS NOT ESTABLISHED: that the something is the initramfs.** ⚠️ **The
> difference is operational — an initramfs binary is firmware-guaranteed and unremovable; a boot
> script or a stored OEM state could be CHANGED.**
> ⭐ **So do not plan on *"a reboot cannot remove it"*. Plan on *"it has come back twice."***
> ⇒ ⭐⭐⭐ **SO THE TWO HALVES SEPARATE CLEANLY, AND THIS IS THE SENTENCE TO REMEMBER:**
> ```
> ✅ persistent Ralink ACCESS   ALREADY EXISTS — telnetd from the signed image + a firmware credential
> ⛔ persistent Ralink SSH      IMPOSSIBLE as a file install — no sshd/dropbear shipped; / is
>                              initramfs, /var + /tmp are ramfs; the config store persists
>                              VALUES, NOT BINARIES
> ```
> ### ⭐⭐⭐ ***"SAME PATH NAME, OPPOSITE STORAGE"*** `[lucid-console154 — the most reusable line of the night]`
> **pico `/var/ipaccess` = jffs2 on `mtdblock4`, REAL FLASH · Ralink `/var` = RAM.** ⇒ **One asymmetry
> explains why an identical recipe persists on one chip and evaporates on the other.**
> ⛔ **AND IT IS WHY "PERSISTENT SSH ON BOTH CHIPS" NEEDS ITS WORDING SETTLED:** persistent
> **access** to the Ralink exists today; persistent **SSH** there does not and cannot be installed
> as a file.
>
> ### 📕 **THE DISCREPANCY AS FLAGGED, KEPT SO THE RESOLUTION IS LEGIBLE:**
> ### ⚠️ **THE OBSERVATION IS SOLID; THE MECHANISM IS OPEN. DO NOT INHERIT A REASON.**
> **Three candidates, none eliminated:** ① **those rootfs images are the wrong specimen** — they sit
> under generic names and their device is unconfirmed · ② **a different BANK boots a different `rcS`**
> — the two banks are known to differ, and which one the live Ralink booted is explicitly unsettled
> · ③ **something enabled it at runtime, possibly us.**
> ⭐ **`PID 986` with parent `init` does not settle it either: a daemon whose launcher has exited is
> REPARENTED to init and looks identical to one init started.**
> ⇒ ✅ **What you can rely on TODAY: telnet access was there after a reboot, and the CREDENTIAL is
> firmware-class.** ⛔ **What you cannot yet rely on: that it will be there after the NEXT one.**
> ### ⭐⭐⭐ **AND THE REFRAME THAT COLLAPSES TWO PROBLEMS INTO ONE: THE RALINK HALF IS NOT SEPARATE WORK.**
> **If you want REAL SSH on the Ralink, the designed route is not a Ralink change at all — it is the
> PICO pushing a static `mipsel`/uClibc dropbear into the Ralink's ramfs on every boot, using
> `opmode.sh` + the 30-second watchdog that already run from flash we already own.**
> ⇒ ***The persistence mechanism already exists; it would just need to reach one hop further.***
> ⇒ 🎯 **So "persistent SSH on BOTH chips" has exactly ONE blocker, and it is the same blocker as
> everything else on this device: ROOT ON THE PICO.** ⛔ **Do not plan the Ralink half as separate
> work.**
> ### ⭐⭐ **AND A THIRD REASON, WHICH REVERSES AN ASSUMPTION WORTH NAMING: THE TOOLING IS ON THE PICO.**
> `[lucid-console154, 2026-09-14, after an evening blocked on the Ralink's missing utilities]`
> ```
> Ralink   busybox v1.8.2 — NO nc · NO timeout · no id/tr/head/tail/awk/find. tftp only, and
>          TFTP GIVES REACH, NOT ENUMERATION (an RRQ is answered only by a TFTP server).
> pico     nc · ssh · telnet · wget
> ```
> ⇒ ⛔ **"Use the Ralink as the platform to scan the pico from" is BACKWARDS.** ⇒ **The Ralink is the
> chip with root and no tools; the pico is the chip with tools and no access.** ⇒ ⭐ **Every tooling
> problem on this device dissolves the moment there is a pico shell — so tool-building on the Ralink
> is work that a successful pico root makes unnecessary.**
> ⚠️ **Three prerequisites, ONE now cleared:** ✅ the telnet path works (measured on `.106`,
> 2026-09-14) · ⛔ **a static mipsel/MIPS-II/uClibc dropbear actually BUILDING — UNVERIFIED** ·
> ⛔ **free ramfs space on the Ralink — UNMEASURED.**
> 📌 `microcell/docs/findings/findings-morpheus3gkeep-ralink-ssh.md`.
>
> ⇒ ⭐⭐ ***"We do not know why it survives" is a better thing to carry in a guide than a wrong
> reason*** — a wrong reason gets dismissed the moment someone checks it, and takes the true
> observation down with it.
> ⇒ ✅ **SO "persistent SSH on the Ralink" is a COMFORT GOAL, not a capability one.** **If the aim is
> durable access to that chip, you already have it: telnet + a firmware-class credential.**
> ⛔ **AND THE DISTINCTION THAT KEEPS BITING:** ***an account is not a service, and a service is not
> its means of creation.*** **All three are separately present or absent here, and conflating any
> two of them has produced a wrong answer tonight.**

### THE THREE PARTS — all on the pico, all in `/var/ipaccess` (persistent)
```
1. /var/ipaccess/root_home/.ssh/authorized_keys        1461 B, mode 0600
2. /var/ipaccess/opmode.sh          ← sourced at boot; carries the ROBUST_SSH block below
3. /var/ipaccess/nv_env.sh          ← the two exports below
```
**`opmode.sh` — the `ROBUST_SSH` block:**
```sh
/opt/ipaccess/bin/setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED TRUE 2>/dev/null
if ! /bin/netstat -ltn 2>/dev/null | grep -q 0.0.0.0:22; then
    killall dropbear 2>/dev/null
    /usr/bin/dropbear -r /etc/ssh/rsa_host_key -p 22 2>/dev/null
fi
```
**`nv_env.sh` — the two lines that matter:**
```sh
export ENV_VERBOSE_CONSOLE_ENABLED="TRUE"
export FS_VARIANT="224A"     # dev-variant override: 4th char 'A' is in the UNHARDENED set
```
⭐ **`FS_VARIANT="224A"` is NOT cargo.** `rcS` computes `FS_LETTER` with `cut -c4` and `A` is in
`{A,C,E,G,I,W,X,Z}` ⇒ `DEFAULT_UNHARDENED=TRUE`. **A stock `205F` unit gives `F`, which is in no
set.** ⇒ **The override is what makes the boot-path default fall the right way.**
⛔ **It covers the BOOT path only** — the software-download path calls `init_nv_env` with the
*incoming* variant and never reads this file. **That is why part 2 exists.**

### ⭐ **THE DESIGN NOTE WORTH KEEPING: `ROBUST_SSH` IS IDEMPOTENT BY CONSTRUCTION**
**It checks whether `0.0.0.0:22` is ALREADY listening and only then restarts dropbear.** ⇒ **It can
run every boot without fighting a healthy sshd**, and it repairs the case where something reset the
flag. ⭐ ***A persistence mechanism that is not idempotent becomes a fight with itself on boot two.***

### ✅ **VERIFY — and check the BIND ADDRESS, not just that a daemon exists**
```
netstat -ltn | grep ':22'
  0.0.0.0:22     ✅ persistent SSH is live
  127.0.0.1:22   ⛔ dropbear is running and UNREACHABLE — ENV_VERBOSE_CONSOLE_ENABLED is not TRUE
```
⇒ ⭐⭐ **A loopback bind is the DEFAULT, not a fault** (`sshd:64-68`), and it is what an
unprovisioned unit does. ***"dropbear is running" is not the test; the bind address is.***
⚠️ **And expect TWO reboots** — see Phase 3 item 5: `$( )` runs in a subshell, so a payload that
sets the flag cannot change the already-started sshd. **Reboot 1 lands it, reboot 2 binds it.**

---

## Phase 4 — Point it at your core

> ### 🎯 **DO THIS**
> ```
> set ipsecEnable FALSE
> set apNtpServerInfo ("<NTP-IP>")     # OPERATIONAL NTP tier
> set defaultNtpServer ("<NTP-IP>")    # FACTORY-DEFAULT tier — a DIFFERENT tier, not a duplicate
> set hnbGwAddress "<HNBGW-IP>"        # your osmo-hnbgw. read-write, max length 260
>
> get ipsecEnable                      # read back
> get hnbGwAddress                     # read back
> ```
> ### ⚠️ **THE FOUR THINGS THAT BITE HERE — details below, but know these now**
> ```
> 1. SET BOTH NTP ATTRIBUTES.  Without working NTP the device does not even ATTEMPT the
>    HNB-GW connection. Writing only one tier fails SILENTLY and looks like a broken gateway.
> 2. DO NOT get apNtpServerInfo.  It errors on this hardware, and an erroring read is not a
>    failed setting. Verify NTP BEHAVIOURALLY: is the gateway connection attempted at all?
> 3. READ BACK THE BARE NAME, never a prefixed tier. A get of the tier you just wrote returns
>    your value cheerfully and says NOTHING about what the device is doing. A night went into
>    exactly that.
> 4. AN NTP ADDRESS THAT RESOLVES IS NOT ONE THAT SYNCS. With no internet route a public NTP
>    name resolves fine and never syncs. Point it somewhere the unit can actually reach.
> ```
> ⇒ ⭐ **Then REBOOT before you believe any of it** — an *empty* `lkg*` tier is not neutral and
> has silently discarded a correctly-set value. [Phase 7](#phase-7--surviving-a-power-cut).

**Read every setting back afterwards** — **the caller's log line that it sent a command is not
evidence the callee accepted it.**

<details><summary><b>Why each of those four matters — the measured detail</b></summary>


> ### ⭐ NTP is not a nicety — it gates the whole thing
> Without working NTP the device **does not even attempt the HNB-GW connection**. And there
> are two NTP attributes at different tiers: the factory-default one is applied after a
> reset and **is not necessarily the value in force**. Writing only the factory tier fails
> **silently** and looks exactly like the HNB-GW step being broken.
> **Set both.**
>
> ⚠️ **But do not verify by reading the operational tier back** — on our DPH-151 that attribute was
> **rejected in every form tried**, so the read tells you nothing either way. **Verify
> behaviourally instead: does the gateway connection get attempted at all?** That is the thing NTP
> gates, and unlike the attribute it is observable.
>
> ⚠️ If your unit has no route to the internet, an NTP address that resolves publicly will
> resolve fine and **never sync**. Point it at an NTP server it can actually reach.

> ### ⭐⭐ Those two NTP writes are one setting at two TIERS — and reading back the one you wrote proves nothing
> They are not belt-and-braces. Several settings here exist at four parallel tiers and **the
> prefix is the tier**; the model, and the caveat that precedence between the tiers is inferred
> rather than traced in code, is in [`CONFIG.md`](CONFIG.md#the-four-tier-value-model). **`defaultNtpServer` above is one of
> those prefixed names on a DPH-151** — which is how we know the structure is not specific to
> the sibling hardware.
>
> ⛔ **What matters at this step is that it defeats the "read it back" rule the rest of this
> guide runs on.** A `get` of the tier you just wrote returns your value, cheerfully, and says
> **nothing** about what the device is doing. A night went into exactly that: writing the
> `local*` tier while the **operational** tier drove behaviour. *Every readback passed.*
> ⇒ ⭐ **Read back the bare name. That is the tier that acts.**

> ⚠️ **Reboot survival is a separate question with a measured surprise in it:** an *empty*
> `lkg*` tier is not neutral, and a correctly-set value vanished at a reboot because of it —
> detail in [`CONFIG.md`](CONFIG.md#the-four-tier-value-model). ⇒ **Reboot the unit before you believe your bring-up.**
> [Phase 7](#phase-7--surviving-a-power-cut) is where that lands.

</details>

## Phase 5 — Give the radio parameters, then unlock, then connect

> ### ⛔ STOP. This is the step that puts a transmitter on licensed spectrum.
> Everything before this point was passive. From here the cell radiates.
>
> **Go and read the “Before you transmit: spectrum” section of the [README](../README.md)
> now, if you have not.** Band 2 and Band 5 are refarmed and in active use; empty of the old
> technology is not the same as vacant. There is a clean route (an experimental licence) and a
> pragmatic one (minimum power, minimum antenna, one room) — and **you cannot have house-wide
> coverage and RF containment at the same time.**
>
> **And settle the PLMN before this step, not after.** A unit that ran on a carrier's network
> still carries that carrier's MCC/MNC. See [`CONFIG.md`](CONFIG.md), and verify it **on the
> air** — trap 15 in [`TRAPS.md`](TRAPS.md) is a store that reads back correctly while the
> broadcast never changes.

> ### 🔴 The step everyone misses: set the selection METHOD, then the list
> With no usable radio parameters the select action **acknowledges and selects nothing** — you
> get `uarfcnDownlink = -1`, `scramblingCode = -1`, `operationalState = DISABLED`, and an HNBAP
> association **with no radio**. The core shows the cell registering. No handset can attach.
> The symptom is "the core says it's up and the phones say no service", and it will send you
> to debug the core for a day.
>
> ⚠️ **Populating `rfParamsCandidateList` is only half of it — and an earlier revision of this
> page said it was all of it.** `AUTO` reads **network-listen scan results**, not your list;
> `CONFIGURED` reads the list. **A unit in `AUTO` that has never scanned selects nothing no
> matter what the list contains**, which is indistinguishable from the write not landing.
> ⇒ **Set the method first, and read it back before you unlock.** Full detail — including a
> transmit-power attribute whose *meaning* changes with the method — in
> [`CONFIG.md`](CONFIG.md#rfparamscandidatelist--the-one-nobody-sets-and-the-cell-dies-without-it).

```
set cellParameterSelectionMethod CELL_PARAMETER_SELECTION_METHOD_CONFIGURED
set rfParamsCandidateList ({<uarfcn>, <scrambling-code>, 1})
get cellParameterSelectionMethod     # read it back BEFORE the unlock action
action <selectCellParams>
action <unlock>
action establishPermanentHnbGwConnection
```

Substitute a UARFCN legal for you, in a band the unit supports and your handsets support.
The action IDs are numeric and firmware-specific; find them in your unit's action table
rather than copying ours. Two anchors that helped us cross-check: the **lock** and
**unlock** actions are adjacent numeric inverses, and
`establishPermanentHnbGwConnection` is present **by name** in the binary.

⚠️ **Issue one command per invocation.** A single bad attribute aborts an entire DMI batch,
so a perfectly valid attribute sitting in a batch with a bad one reads as *"does not
exist"*.

⚠️ **Put a timeout on every call.** A `get` can hang indefinitely even when it is the only
client on the box; without a bound, one hung call stalls everything after it. A killed call
must not abort the run — continue to the next command.

⛔ **Never kill the management daemon** to "clean up". On this firmware it owns the TR-069
session, the data model *and* the DMI action path — killing it destroys the channel you are
working over, and on our unit it caused a reboot.

## Phase 6 — Confirm, without lying to yourself

> ### 🎯 **DO THIS — on the core**
> ```sh
> printf 'enable\nshow hnb\n' | nc -q1 127.0.0.1 4261
> ```
> ### ✅ **ACCEPT THE CELL ONLY WHEN ALL FOUR HOLD AT ONCE**
> ```
> 1. the output contains the literal token   HNB connected      (never judge by byte count)
> 2. RemAddr <ip> ... State == SCTP_ACTIVE   an ALLOW-LIST — see below, this one is subtle
> 3. operationalState = ENABLED
> 4. uarfcnDownlink > 0
> ```
> ⇒ **A registration is not a working cell. Then attach a handset and check for a subscriber** —
> with a control on the read, because **a zero from a failed read looks exactly like a real zero.**

> ### ☠️☠️ **TEST `SCTP_ACTIVE` AS AN ALLOW-LIST. "NOT INACTIVE" IS WRONG AND THIS GUIDE USED TO SAY IT.**
> `[corrected 2026-09-13 — the kernel enumeration is COMPLETE and has FIVE members, not two]`
> ```
> SCTP_INACTIVE · SCTP_PF (== SCTP_POTENTIALLY_FAILED) · SCTP_ACTIVE ·
> SCTP_UNCONFIRMED · SCTP_UNKNOWN (0xffff)
> ```
> ⇒ ⛔ **A deny-list built from the two states anyone has OBSERVED renders `SCTP_UNCONFIRMED` — a
> path never confirmed — as GREEN.** ⭐ ***An allow-list is correct under ignorance, and you cannot
> tell from inside how ignorant you are.***
> ### ⛔ **AND THE ASSOCIATION STATE IS NOT THE PATH STATE — THEY DISAGREE, AND ONLY ONE IS LIVE**
> `[measured: a cell at 100% packet loss with ARP failing, while show hnb read healthy]`
> ```
> SCTP-ASSOC: State SCTP_ESTABLISHED                      <- the ASSOCIATION's view. SURVIVES THE PEER.
>  RemAddr 10.0.6.x:29169 State SCTP_POTENTIALLY_FAILED   <- the PATH's view. FAILS FIRST. USE THIS.
> Uptime 1h01m · "3 HNB connected"                        <- none of these moved
> ```
> ⇒ **Read the indented `RemAddr … State`, not the association line above it.**

> ### ⛔ `show hnb` alone is NOT sufficient. It fails in **both** directions.
> - It reports the **context**, not the device: ours counted uptime for **three minutes**
>   (and in another run nearly ten) on a cell that had been **unplugged from the wall**.
> - Roughly **one read in seven** returns the **welcome banner only** — a few hundred bytes
>   of confident-looking text with no answer in it. A classifier based on byte count scores
>   every one of those as a good read.
>
> ✅ **Require the literal token `HNB connected`, never a size.** Then confirm, one line
> below in the *same* output, that the peer's `RemAddr … State` is **exactly `SCTP_ACTIVE`**
> (allow-list — see the box above; *"not INACTIVE"* is the form that was wrong here).
> Retry on a token miss — a single clean read of that port means nothing.

📌 **The acceptance criteria are in the box at the top of this phase.** One addition worth its own
line: **the core must accept an `HNB-REGISTER-REQ` AFTER THIS BOOT** — a registration from a
previous boot generation proves nothing about the unit in front of you.

## Phase 7 — Surviving a power cut

> ### ⏱️ **BEFORE ANYTHING ELSE: DO NOT CALL A COLD BOOT OF *THE AP* FAILED BEFORE T+20 MINUTES.**
> `[measured across TEN cold boots OF THE AP. ⛔ SCOPE ADDED 2026-09-13 — see the box below;
>  this curve does NOT describe a restart of the CORE.]`
> ```
>  ~5 min   the core reaps the stale SCTP association from the previous life
> ~11 min   NAT state clears and the AP's SCTP INIT finally gets through
> ~16 min   the cell registers; handsets follow within about a minute
> ```
> ⇒ **A unit that looks dead at T+8 is behaving normally.** ⭐ **The ~11 min term is remarkably
> stable; the FIRST one is what varies (3m09s–5m22s). If a boot runs long, that is the term that
> moved — quote both, never just the total.**
> ⚠️ One 2006-era handset was consistently last and **could not be hurried**: 96 s to 609 s
> behind the others.
>
> ### ⛔⛔ **THIS CURVE IS FOR AN *AP* REBOOT. A *CORE* RESTART RECOVERS IN ABOUT A MINUTE.**
> `[measured 2026-09-13: exchange restarted; "1 HNB connected" at T+3, and one AP re-registered
>  INSIDE A MINUTE. I quoted the T+20 figure at that event and it was the wrong curve.]`
> ```
> AP cold boot    the AP's OWN stale association must be reaped BY THE CORE, NAT must
>                 clear, then the AP re-INITs                              -> ~16 min
> CORE restart    the APs never went down. They re-INIT against a core with NO stale
>                 state to reap, because it just lost all of it            -> MINUTES
> ```
> ### 📋 **THE WARM-REBOOT CURVE, MEASURED** `[lucid-console154, 2026-09-13, exchange restart]`
> ```
>  +75 s     all five osmo units ACTIVE
>  +1.5 min  first AP re-registered
>  +4 min    both APs up
> +14 min    both SCTP_ESTABLISHED *AND* per-path SCTP_ACTIVE — FULLY LIVE
> ```
> ⇒ ⛔ **"~1 minute" is as wrong as "~16 minutes", in the other direction.** **A cell APPEARS at
> ~1.5 min and is not FULLY LIVE until ~14.** ⭐ **Which number you quote depends on which
> question you are answering: *"is it back?"* is minutes; *"can I trust it?"* is ~14.**
> ⚠️ **I first wrote `~1 min` here from a single observation of the first cell returning. That is
> the healthiest-interval error: I sampled the fastest term and called it the recovery.**
> ⇒ ⭐⭐⭐ **The ~5 min reap term is about state THE RESTARTING SIDE IS HOLDING. A core that has
> just rebooted holds none — so the term that dominates the AP curve does not exist.**
> ⇒ ⭐⭐ ***SCOPE A RECOVERY CURVE TO WHICH SIDE REBOOTED.*** **This is the per-device scoping rule
> with a different axis: a measured, honest number applied to the wrong EVENT CLASS.**
> ✅ **WHAT HOLDS ON BOTH CURVES: do not intervene, and do not let a bring-up fire into the
> recovery window** — re-running one against a recovering cell tears it down either way.

> ### 🎯 **DO THIS**
> ```
> 1. Put every script under  /var/ipaccess/   — the ONLY writable store that survives a power
>    cycle (jffs2). /var/run is tmpfs and clears at boot.
> 2. Make the script LOG that it ran, and when.
> 3. Make it REFUSE to run if a healthy association already exists (with an override flag).
> ```

Whatever you script, put it somewhere durable. On our DPH-151 the only writable store that
survives a power cycle is a **jffs2 partition mounted at `/var/ipaccess`**; anything under
`/var/run` is tmpfs and clears at boot (which is what you want for a lock file, and exactly
what you do not want for your scripts).

⚠️ **The device's own configuration files live under that same path, in a *bank* it can
regenerate without asking you.** Two traps apply directly to anything you write there, and both
are model-dependent:
[trap 1](TRAPS.md#1-iuh_enable--two-config-files-two-parsers-one-silent-failure) — one key, two
files, two different parsers, one silent failure — and
[trap 2](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell),
where **which bank is live differs per model**, and guessing kills the cell. **Read the live
bank; never assume it.**

Two things worth building in, both learned the hard way:

- **Log that your recovery script ran, and when.** A self-healing fix that acts silently
  destroys the evidence for whether it was needed — "the setting persisted" and "my script
  fixed it" produce identical readings. A pre-NTP 1970 timestamp in the log is also proof a
  run was automatic and not someone at a keyboard.
- **Refuse to run if a healthy association already exists**, with an override flag. Re-running
  a bring-up against a working cell tears it down.

## Phase 8 — A call

> ### ✅ **YOU ARE DONE WHEN ALL OF THESE ARE TRUE**
> ```
> root SSH on BOTH chips          Ralink .185 and pico .186        <- Step 1, the whole point
> the .244 table matches          see "WHAT DONE LOOKS LIKE" above
> show hnb                        HNB connected + RemAddr State == SCTP_ACTIVE
> operationalState = ENABLED  ·  uarfcnDownlink > 0
> a handset attaches              and the core shows the subscriber
> it survives a power cut         re-check at T+20, not T+8
> ```

**At this point the cell is an ordinary HNB on your core.** Everything else — subscribers,
voice, SMS, packet data — is core-network work and belongs to the Osmocom documentation,
not to this repo.

⚠️ **One thing that is NOT core-network work and does belong here:** if calls stop later with no
other explanation, **check `IUH_ENABLE` before anything else.** The AP regenerates the config bank
on a bank failover, a software download, or a factory restore — and the key goes with it. See
[trap 1](TRAPS.md#1-iuh_enable--two-config-files-two-parsers-one-silent-failure).
