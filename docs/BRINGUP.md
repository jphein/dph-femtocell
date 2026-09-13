# Bring-up: DPH-151 — from a boxed MicroCell to a call

**Scope: written from a DPH-151 (ip.access train `563.21.8`) brought up against an Osmocom
core, carrying voice and SMS for four handsets and recovering unattended from a power cut.**
**This page is the DPH-151 guide.** Every phase below was executed on one.

> ### 🧭 FOUR TARGETS, FOUR GUIDES — pick yours before you read further
> | target | guide | evidence class |
> |---|---|---|
> | **Cisco DPH-151** | **this page** | ✅ **proven here, end to end** |
> | **ip.access nano3G S8** | [`BRINGUP-NANO3G.md`](BRINGUP-NANO3G.md) | ✅ **proven here, end to end** |
> | **Cisco DPH-153** | [`BRINGUP-DPH153.md`](BRINGUP-DPH153.md) | ⚠️ **published route by someone else; not reproduced here** |
> | **Cisco DPH-154** | [`BRINGUP-DPH154.md`](BRINGUP-DPH154.md) | 🔴 **no route in. Four measured walls.** |
>
> ⭐ **Phases 4–8 below are the ip.access software stack and transfer between models** — attributes,
> the unlock order, the transmission gate, power-cut recovery. **Phases 0–3 are hardware and access,
> and those are where the models genuinely differ.** ⛔ **[`Trap 2`](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
> is a worked example of a correct instruction for one model destroying another.**

Read [`TRAPS.md`](TRAPS.md) first. Most of the time this takes is spent on the traps, not
on the steps.

---

> ## 🎯🎯 **STEP 1 IS ROOT SSH ON BOTH CHIPS. EVERYTHING ELSE WAITS ON IT.**
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
>                             DNATs 22/80/8080/20000 onward to .186.
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
telnet 192.168.157.185          # login: guest   password: 1qaz@WSX
```

⇒ **If that opens, you have a shell on the gateway SoC and you do not need serial, the port scan,
or the backdoor.** For a clean root shell in one step, the corpus already ships the tool:

```sh
~/Projects/microcell/keys/dph151/rroot.py 'id'
```

`[MEASURED 2026-09-13 on .106: root, BusyBox v1.8.2 (2012-04-20).]`
Root without it: `rmm_client 192.168.157.185 cs_cmd "<command>"`.

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

### ⛔ READ THIS FIRST — IT COST US TWO SEPARATE EVENINGS

**1. The device only re-reads DNS and re-dials AT BOOT.**
⇒ **Every DNS change you make is INERT until you power-cycle the unit.** Change everything you
intend to change, *then* reboot once. `[measured — "~24 hours of null results" in the corpus]`

**2. `femtocell.wireless.att.com` is NOT a management server.**
It is `Device.ManagementServer.X_00000C_CDPBaseURL` — the **file-download** host.
⇒ **Answering it gets you a completed TLS handshake, zero application bytes, and a hang-up.**
That is the documented wrong role, and it looks exactly like a broken server.

**3. The femto sends NO TLS SNI.** ⇒ The server picks **handler AND certificate by DESTINATION
IP**. **Each role needs its own address.** A name pointed at the wrong IP lands on the wrong
handler and closes silently.

---

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

### ROUTE 3 — ACS / TR-069   `📋 last`

⭐ **CWMP gives READ *and* WRITE** — 543 parameters, identity and PLMN. ⛔ **It does NOT reach
`IUH_ENABLE`, the `iapc-gw-shim`, or `picoinit`, so it cannot make a cell serve.**
⇒ ✅ **Its value here is PATH D — the CWMP route TO a shell:**
```
CMHS/ACS binds -> ACS issues Download RPC -> femto fetches an ip.access package (type 0x5007,
  "sdphook") -> post_swdl_hook SOURCES IT AS ROOT -> enables sshd + installs a key
  -> ssh root@192.168.157.186
```
⛔ **Assert the payload's HASH before serving it. Never select it by path** — three paths carry the
unversioned name and two hold a superseded payload. ⛔ **And the upstream hook installs a PUBLISHED
private key; mint a fresh pair before ever using it.**

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

> ### ⛔ Do not call a cold boot failed before **T+20 minutes**
> Measured across ten cold boots on our unit:
> ```
> ~5 min   the core reaps the stale SCTP association from the previous life
> ~11 min  the NAT state clears and the AP's SCTP INIT finally gets through
> ~16 min  the cell registers; handsets follow within about a minute
> ```
> The second term is remarkably stable; **the first one is what varies** (we saw 3m09s and
> 5m22s). If a boot runs long, that is the term that moved. Quote both, never just the
> total. One 2006-era handset was consistently last and could not be hurried — 96 s to
> 609 s after the others.

Two things worth building in, both learned the hard way:

- **Log that your recovery script ran, and when.** A self-healing fix that acts silently
  destroys the evidence for whether it was needed — "the setting persisted" and "my script
  fixed it" produce identical readings. A pre-NTP 1970 timestamp in the log is also proof a
  run was automatic and not someone at a keyboard.
- **Refuse to run if a healthy association already exists**, with an override flag. Re-running
  a bring-up against a working cell tears it down.

## Phase 8 — A call

At this point the cell is an ordinary HNB on your core. Everything else — subscribers,
voice, SMS, packet data — is core-network work and belongs to the Osmocom documentation,
not to this repo.
