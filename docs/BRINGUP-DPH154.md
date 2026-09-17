# Bring-up: Cisco DPH-154 — the provider-emulation route, and the one bit that stops it

> ## 1️⃣ **BEFORE STEP ONE — CONFIRM WHICH UNIT YOU ARE HOLDING: [`MATRIX.md`](MATRIX.md)**
> **This guide is for the DPH-154: **no config banks at all** · **579** train · ⛔ JP: DO NOT OPEN IT**
> ⇒ ⛔ **If your unit is not that, STOP — the other models differ in ways that have cost this
> project days: bank numbering is REVERSED between the 151 and the nano3G, the 154 has no banks
> at all, and a 579 measurement is not a 563 fact.**
> ✅ **[`MATRIX.md`](MATRIX.md) is the identification table** — `## Identity`, `## Silicon and RF`,
> `## Capability`, `## Access and state`. **Read it first; it is 166 lines and it is the only
> document that tells you WHICH machine you have before you type anything.**
> 📌 **POINTER, NOT A COPY.** `[Wired in 2026-09-14: MATRIX.md existed and NO guide referenced it —
> the identification step was written and orphaned.]`


> ### 📋 EVIDENCE CLASS — and it is genuinely two different answers
> ✅ **ACCESS IS SOLVED.** There is a working route into a DPH-154 that needs **no memory-corruption
> exploit, no JTAG, no case opening and no serial console** — you stand up the management server the
> unit is already looking for, and let its own provisioning path do the work.
> ⛔ **THE RADIO IS SEPARATELY GATED, and on the unit measured here that gate is CLOSED.**
> `X_00000C_Tampered = 1` — **14 readbacks** — and `FAPService.Enabled` is refused with
> **FAULT 9003/9007.**
> ⇒ ⭐ **That is a per-unit condition, not a model-level wall.** A 154 with the bit clear should go
> all the way. **We do not have one, so the last phase is unproven and is labelled as such.**
>
> ⚠️ **An earlier revision of this page said "there is no route in."** That was written from an
> out-of-date reading of the corpus and **was wrong** — the access work had already been done. It is
> corrected here rather than quietly replaced, because *"we could never do X"* is exactly the kind of
> claim that survives past its own refutation.

---

## Why this route exists at all

The 154 is the hardened one. Every direct door is shut, and each of these was **measured**:

| door | state |
|---|---|
| the `wizard` **UDP** backdoor (works on older siblings) | ✅ **tested, did not work — and the image does not ship the handler** |
| anything listening | **13 ports probed, 13 closed** — and they are **ICMP-unreachable rejects**, the signature of a **firewall rule**, not of absent listeners |
| catching it phone home and answering as its server | **initiated nothing at all in 60 s of passive capture** |
| a public firmware dump to analyse | none exists, and the only software dump path **requires the access it would provide** |
| the software-download path, tried directly | ✅ **tested by JP, did not work** — see the fenced section at the foot of this page |

⇒ **Public exploits are 2012–2018 and target the 151/153. This is a 2019 build.**

> ### ✅ **RESOLVED 2026-09-16 — THE CONCLUSION HOLDS, AND IT NOW HAS EVIDENCE THAT SUPPORTS IT**
> **JP, who ran the attempts:** *"the wizard UDP backdoor → port 14677 closed, we tested this and we
> tested the software download and got neither to work — but yes, if you can't find the test then we
> can't mark it tested."*
> ⇒ ⭐⭐⭐ **And the reason it could not have worked is now measured STATICALLY, with a passing
> positive control and without probing any device:**
> ```
> "BackdoorPacketCmdLine"  (the fail0verflow protocol verb), via strings(1):
>    a Ralink rootfs that HAS the backdoor    2 hits   ✅ POSITIVE CONTROL
>    the DPH-154's own rootfs                 0 hits   ⬅ A REAL ABSENCE
> ```
> ⇒ ✅ **The 154 image does not contain the wizard backdoor's protocol handler.**
> ⛔ **BOUNDS: that rootfs is ONE filesystem from a 12-partition NAND dump, and a REIMPLEMENTATION
> under a different verb is not excluded.** **It shows the fail0verflow verb is absent — not that no
> UDP door exists.**
>
> ### ☠️ **AND TWO INSTRUMENTS FAILED ON THE WAY TO THAT LINE — BOTH SILENTLY**
> ```
> 1. the ORIGINAL wall:  TCP 22 23 80 443 7547 8080 8090 14677 -> all closed
>    ⛔ the wizard backdoor is UDP. A TCP scan of a UDP service reads "closed" either way —
>       AND ITS CONTROL PASSED (RST not filtered), because the scanner genuinely worked.
> 2. grepping for the PORT: "14677" -> 0 hits on EVERY tree, INCLUDING ones that have the listener.
>    ⛔ the port is a compiled integer (0x3955), not ASCII. That zero looks like corroboration
>       and carries nothing.
> 3. and grep -rl for the VERB -> 0 even on the control tree. strings(1) found it. Use strings.
> ```
> ⇒ ⭐⭐⭐ ***A CONTROL PROVES YOUR INSTRUMENT WORKS. IT SAYS NOTHING ABOUT WHETHER YOU AIMED IT AT
> THE RIGHT THING — OR WHETHER THE THING YOU SEEK SURVIVES COMPILATION AS TEXT.***
> ⭐ **The protocol VERB is a string and survives; the PORT is an integer and does not. Same target,
> two searches, only one of them can answer.**
> **The `wizard` backdoor is UDP.** `dph151-backdoor.py` sends `sock.sendto("BackdoorPacketCmdLine_Req …", (ip, 14677))`.
> ```
> what was actually run:   TCP 22 23 80 443 7547 8080 8090 14677  ->  all closed
>                          (RST not filtered, so the scanner demonstrably worked)
> ```
> ⇒ ⛔ **A TCP scan of a UDP service returns "closed" whether the UDP service is there or not.**
> ⭐⭐ **And the control PASSED — the scanner was working perfectly, on the wrong protocol.** ⇒
> ***A positive control proves your instrument works; it says nothing about whether you pointed it
> at the right thing.***
> ✅ **AND IT IS DOUBLY SHUT:** the wizard backdoor lands on the **Ralink**, and a 154 has none
> ([`Trap 73`](TRAPS.md#73-dph-151-vs-dph-154--three-exploits-share-one-name-the-cwmp-label-is-on-the-telnet-one-and-which-are-even-available-depends-on-the-model)).
> ⚠️ **The lesson kept: "tested and it failed", "measured closed" and "structurally impossible" are
> three different claims. This table asserted the second on evidence for none of them — and the
> first and third are both true, which is why nobody noticed.**
⭐ **So you do not attack the PERIMETER. You become the thing it is waiting for — and then you
attack ONE FIELD, from inside the conversation it opened to you voluntarily.**
⚠️ **Both halves matter.** Phase 1 alone gets you a management session and nothing more; Phase 2
alone has no channel to arrive on. **The provider emulation is not the exploit — it is what makes
the exploit reachable.**

---

## Phase 0 — Isolate, as always

The general caution in [`BRINGUP.md`](BRINGUP.md#before-you-plug-anything-in) applies. ⚠️ **On this
model it is doubly true**, because the whole route depends on the unit talking to *your* server
rather than reaching the internet and finding nothing.

---

## Phase 1 — Become AT&T, exactly

**This is the phase that takes the time, and it is the one JP names when he describes the access:**
*"we got it all configured like att."* ⭐ **Phase 2 is four lines. Phase 1 is a week.**

**Nothing here is an exploit.** You are answering a protocol the device initiates, with the identity
it expects. ⛔ **But "the identity it expects" is far more specific than it sounds, and every one of
the following was found the hard way.**

### 1️⃣ **The name and port come from the DEVICE, not from you — read `hw_description.dat`**

```
REDIRECTOR_URL = https://Femtocell.wireless.att.com:7547/acs
```
> ### ☠️☠️ **PORT 7547, NOT 443. WE LISTENED ON 443 ONLY, FOR A WEEK.**
> ⇒ ⭐⭐⭐ **While you listen on the wrong port, *"the device never dialled CWMP"* and *"the device
> dialled a CLOSED PORT"* are INDISTINGUISHABLE FROM EVERY MEASUREMENT YOU CAN TAKE.** **Both look
> like silence.** ⇒ **Bind the port the device's own config names, before concluding anything about
> its behaviour.**

### 2️⃣ **DNS must answer those names — and the device validates them**

```
femtocell.wireless.att.com  ->  your ACS address      (dnsmasq address= record)
```
✅ **Measured, with the exact check the device performs — name validation, no `-k`:**
```
curl --cacert <chain> https://femtocell.wireless.att.com:8443/logs
   subjectAltName: "femtocell.wireless.att.com" matches      HTTP 200   ✅
CONTROL, same command against the bare IP:                   000        🔴
```
⭐ **One variable — the hostname — and it flips the outcome.**

### 3️⃣ **The certificate CN must be the name it ACTUALLY dials, which is not the obvious one**

```
🔴 CN = femtocell.wireless.att.com        <- the name in REDIRECTOR_URL. IT NEVER ASKS FOR THIS.
✅ CN = dpewe-santa-clara.wireless.att.com <- DPE = Cisco Device Provisioning Engine, the CWMP tier
```
> ### ⚠️ **AND PUT BOTH CAPITALISATIONS IN THE SAN**
> `REDIRECTOR_URL` spells it **`Femtocell`** with a capital F. ⇒ **Carry `femtocell` AND `Femtocell`
> in the SAN so a client-side string compare cannot miss.** 📌 **A CN mismatch here cost a week on
> the CMHS leg, and it presents as silence, not as an error.**

### 4️⃣ **ACS and CMHS must live on DIFFERENT IP ADDRESSES**

⛔ **This is a hard requirement, not a preference.** The server selects its certificate context by
`getsockname()[0]` — **the address the device connected TO.** ⇒ **One IP cannot serve both roles,
because there is nothing left to discriminate them by.**
```
your ACS   ->  one address     (CWMP / TR-069, port 7547)
your CMHS  ->  a different one (the log/management tier)
```

### 5️⃣ **Give it a clock**

⚠️ **These units check certificate validity dates.** A device with no time source and a
2026-dated certificate rejects it — ⭐ **and the rejection is silent in exactly the same way
everything else here is.** 📌 **Y2K-dated leaf certificates are what worked; see the 2g corpus.**

---

### 🎯 **WHAT YOU HAVE AT THE END OF PHASE 1**

**A device that opens a CWMP session to you and accepts your instructions inside it.**
⛔ **That is NOT root, and it is NOT persistent** — it lasts exactly as long as you keep standing
where AT&T stood. ⇒ **Phase 2 is what converts a session into a shell.**

> ### ⚠️ **THE CWMP STORE AND THE NV ENVIRONMENT ARE DIFFERENT PLACES, AND CONFUSING THEM COSTS A DAY**
> ```
> our ACS writes  ->  the CWMP store only   (/var/ipaccess/cisco/dslg_cur_cfg.xml.gz)
>                     the TR-069 client has NO path to /var/ipaccess/nv_env.sh
> ```
> ⇒ **You cannot write the NV environment directly over CWMP.**
> ### ⭐⭐⭐ **NOT DIRECTLY. BUT ONE CWMP-WRITABLE FIELD IS COPIED INTO IT VERBATIM — AND THAT IS THE ROUTE.**
> **You do not need a path to `nv_env.sh`. You need a field the device itself copies there**, and
> `crlServerBaseUrl` is one. ⇒ **Phase 2 is that field.**

---

## Phase 2 — ⭐⭐ The lever: `X_00000C_LogUpload.Tuning`, which writes straight into `nv_env.sh`

> ### 🔴 **THIS PAGE HAS NAMED THE WRONG ROUTE THREE TIMES. THE TRAIL IS KEPT BECAUSE EACH WRONG VERSION IS ONE SOMEONE ELSE WILL REACH FOR.**
> ```
> v1  "serve a firmware image; FS_VARIANT unhardens it"   NEVER DONE -- and it rewrites both U-Boot banks
> v2  "rewrite ManagementServer.URL to point at you"      wrong mechanism: a pointer, not an injection
> v3  "crlServerBaseUrl (2203)"                           RIGHT SINK, WRONG FIELD -- that is the 151's
>                                                          DMI attribute. The 154 has no DMI console.
> ✅  X_00000C_LogUpload.Tuning, over CWMP                 <- the field. JP called it "the serverurlpath thingy".
> ```

**The device dials OUT to your ACS.** ⭐⭐⭐ **That single fact is why this route works on a 154 and
nothing else does:** the session is an **ESTABLISHED flow**, so the 154's wholesale inbound REJECT —
the thing that closes every other door — **is irrelevant to it.**

### 🔧 **THE CHAIN, EACH LINK NAMED**

```
device DIALS OUT (CWMP)
  ACS answers with SetParameterValues on   Device.X_00000C_LogUpload.Tuning
     -> DslmSsp
     -> sysctrlUpdateEnvVar
     -> setnv_env.sh:46      echo "export $1=\"$2\"" >> nv_env.sh     ⭐ NO ESCAPING. THE WHOLE BUG.
  => /var/ipaccess/nv_env.sh gains:    export ENV_XKINIT="$(<command>)"
  => the next time ANY of its 22 ROOT CONSUMERS sources that file, the $( ) RUNS AS ROOT
```

> ### 🎯 **AND `/etc/profile:69` SOURCES IT — SO A LOGIN IS ENOUGH**
> **No reboot. No service restart.** ⭐ **Compare the 151, where the equivalent needs TWO reboots** —
> the subshell cannot change the parent environment, so the flag must be written to the file and the
> box booted again. **Here, anything that opens a shell fires it.**

### 📋 **THE FIELD'S NORMAL, DOCUMENTED USE — and this part is PROVEN**

**`Tuning` takes a `KEY: VALUE; KEY: VALUE` string and writes those into the NV environment.** That
is its *intended* function, and it is how the unit was configured:
```
ENV_FIREWALL_DISABLED: TRUE; ENV_VERBOSE_CONSOLE_ENABLED: TRUE;
ENV_SERIAL_CONSOLE_ENABLED: TRUE; ENV_CRASH_REPORT_URL: http://<you>:8082/crash;
ENV_DIAG_FILE_LIST: /var/ipaccess/.tamperInfo /var/ipaccess/nv_env.sh …
```
> ### ⚠️ **`Tuning` IS A WHOLE-STRING REPLACE, NOT A MERGE**
> ⛔ **Re-sending a stale copy of that string silently reverts every key you are not currently
> thinking about** — including the one holding your own access open. ⭐ **A DROPPED key is a visible
> omission; a STALE key looks like diligence — present, correctly spelled, and wrong.**

> ### ⛔⛔ **THE HONEST STATE OF THE ESCAPE — AND THE PAYLOAD IS IN THE TOOL, DATED AND ATTRIBUTED**
> ```
> ✅ the payload EXISTS, queued through this exact field, with its authorisation recorded in code:
>       Tuning <- "ENV_XKINIT: $(mkdir -p /var/ipaccess/root_home/.ssh && <key install>)"
>       log("*** DPH-154 ENV_XKINIT INJECTION QUEUED (JP authorised; his key, his device) ***")
> ✅ JP, who ran it:  "we were able to get into the 154 that way, but then the tamper timer went off"
> ⚠️ a corpus lane:   "THE PRIMITIVE IS DESIGNED, NOT DEMONSTRATED. Do not price it as proven."
>                     one logged attempt FAULTED 9003/9007; 0 of 663 readbacks contained ENV_XKINIT
> ```
> ⭐ **So three things are settled: the field is the right one, the payload was written, and it was
> authorised.** ⛔ **What is NOT settled is whether that particular queued write ever executed** —
> the readback evidence says that one did not. ⚠️ **Recorded, not adjudicated: the likeliest reading
> is different moments on different units, and nobody has established it.**
> ✅ **Beyond doubt either way: the `Tuning` write lands, the NV variables it sets take effect, and
> the field reaches `setnv_env.sh` unescaped.**

> ### ✅ **THE PRECONDITION IS MEASURED, AND IT IS WHY THIS SUITS A 154 AND NOT A 151**
> ```
> a DPH-154   889 CWMP Informs, 60-second cadence, for hours   <- it TALKS to our ACS
> a DPH-151     0 CWMP bodies EVER, 0 of 355,325 log lines     <- it never speaks
> ```
> ⇒ ⭐ **JP's *"completely configuring the AP and getting it all set up"* IS the precondition.** The
> injection needs a live CWMP session, and a 154 gives you one.

> ### ☠️☠️ **THREE DIFFERENT MECHANISMS IN THIS CORPUS GET CONFLATED INTO "THE RCE". THEY ARE NOT THE SAME.**
> ```
> A  rroot.py          TELNET to the Ralink as guest -> rmm_client cs_cmd -> root on the RALINK
> B  the SPV injection CWMP SetParameterValues -> unescaped nv_env.sh write -> root on the PICO  ⬅ THIS
> C  persistent_ssh.sh POST-exploitation persistence; assumes you ALREADY have A or B
> ```
> ⇒ ⛔ **A is telnet, B is CWMP — opposite transports, different chips.** ⚠️ **And the "CWMP RCE"
> label in the upstream README sits on the TELNET one.** ⭐ **A DPH-154 has no Ralink at all, so A
> cannot apply to it under any circumstances** — see [`MATRIX.md`](MATRIX.md).

### 📌 **IT IS ONE MECHANISM WITH TWO DOORS — AND THE OTHER DOOR IS DMI**

```
CWMP  Device.X_00000C_LogUpload.Tuning       needs a CWMP SESSION   <- the 154's door
DMI   diagnosticTuning  (attribute 2320)     needs a DMI CONSOLE    <- the 151/nano3G door
        set diagnosticTuning=({name=ENV_VERBOSE_CONSOLE_ENABLED,value=TRUE})
```
⇒ ⭐⭐⭐ **Same sink, same lack of escaping, same `setnv_env.sh`.** **The 154 is not a harder target —
it is the same target with the DMI console removed, and CWMP is the console it still answers on.**
> ### ⚠️ **BOTH ARE WHOLE-COLLECTION REPLACES, NOT MERGES**
> **`Tuning` is a whole-STRING replace; `diagnosticTuning` is a whole-LIST replace.** ⛔ **Read the
> current value before writing, or you will silently drop every key you are not thinking about —
> including the one holding your own access open.**

### 🚪 A second, WEAKER door on the same sink — and why it is weaker

```
crlServerBaseUrl (2203, ac=1 WRITABLE)  ->  export ENV_CRL_BASE_SERVER="<your value>"
```
⇒ **Also unescaped, so it also injects.** ⛔ **But it writes ONE FIXED VARIABLE: you inject into the
VALUE of a variable you did not choose.** ⭐ **`Tuning` takes `NAME: value; NAME: value` — you
choose the variable NAME, which is why `ENV_XKINIT`, `ENV_FIREWALL_DISABLED` and
`ENV_VERBOSE_CONSOLE_ENABLED` can all come from a single write.**
> ### ☠️ **AND IF YOU GO LOOKING FOR `2203`, THE ATTRIBUTE MAPS IN CIRCULATION DISAGREE BY ONE ROW**
> ```
> the STALE map       2201 crlServerBaseUrl  ·  2203 crls
> the CORRECTED map   2201 certificates      ·  2203 crlServerBaseUrl   ac=1   ⬅ right
> ```
> ⇒ ⛔ **A NAME-SHIFTED map is worse than a wrong one: every id resolves, every name looks
> plausible, and you write a URL into a certificate-revocation-list field with nothing to tell you.**
> ✅ **Probe BY NUMBER and read back the name the device returns.** 📌 **Full 151 write-up including
> the two-reboot payload: the 2g corpus, `DEVICE-ACCESS.md` Steps 3–4.**

---

## Phase 3 — What you configure, and ALL of it goes through the ACS

> ### ⭐⭐⭐ **THIS IS THE PART THAT SURPRISES PEOPLE. ON A 154 THE ACS IS NOT JUST THE WAY IN — IT IS THE ENTIRE CONTROL SURFACE.**
> **JP:** *"there are many things we did to get it all configured using just our ACS."*
> ⇒ **On a 151 or a nano3G you do this work at a DMI console. The 154 has none.** ⭐ **Every knob
> below is reached by `SetParameterValues` over the session the device itself opened.**
> 📌 **49 distinct parameters are exercised by the ACS in the 2g corpus. Grouped by what they do:**

### 🆔 Identity and inventory — *read these first; they tell you what you are holding*
```
Device.DeviceInfo.SerialNumber · ModelName · SoftwareVersion · HardwareVersion
Device.DeviceInfo.ProvisioningCode
Device.DeviceInfo.X_00000C_RouterModuleVersion
Device.DeviceInfo.X_00000C_Tampered          ⬅ ⛔ READ THIS BEFORE ANYTHING ELSE. See Phase 4.
```

### 📞 Management-session control
```
Device.ManagementServer.PeriodicInformInterval    ⬅ the dial cadence. Shorten it to iterate faster.
Device.ManagementServer.ParameterKey
Device.ManagementServer.X_00000C_ProvisioningStatus
```

### 🌐 Core network identity — *this is where you tell it it is YOUR network*
```
Device.Services.FAPService.1.CellConfig.UMTS.CN.X_00000C_MCC     ⬅ 999
Device.Services.FAPService.1.CellConfig.UMTS.CN.X_00000C_MNC     ⬅ 99
Device.Services.FAPService.1.CellConfig.UMTS.CN.LACRAC
Device.Services.FAPService.1.CellConfig.UMTS.CN.SAC
Device.Services.X_00000C_FAPService.Cell.OTACellID
Device.Services.X_00000C_FAPService.Cell.RNCIdentity
```
⭐ **This is the CWMP equivalent of the `iapc-gw-shim` identity problem on the other models** — the
cell must present an identity your core will accept, or RRM tears it down seconds after it comes up.

### 🔗 Where it connects
```
Device.Services.FAPService.1.FAPControl.UMTS.Gateway.SecGWServer1  ⬅ the security gateway
Device.Services.X_00000C_FAPService.FGW.Fqdn · FGW.Status          ⬅ the femto gateway
Device.Services.FAPService.1.Transport.Tunnel.IKESA.1.IPAddress · .Status
```
📌 **`IKESA` is the IPsec SA.** ⚠️ **The DPH-153 route documented by others works by DISABLING IPsec
and repointing these** — same idea, reached differently. See [`BRINGUP-DPH153.md`](BRINGUP-DPH153.md).

### 📡 Radio control — *and the gate that stops this page*
```
Device.Services.FAPService.1.FAPControl.AdminState · OpState · RFTxStatus
Device.Services.X_00000C_FAPService.Enabled          ⬅ 🔴 refused 9003/9007 while tampered
Device.Services.X_00000C_FAPService.Radio.Status
```

### 🚪 Access control — *the 154's version of the CSG trap*
```
Device.Services.FAPService.1.AccessMgmt.AccessMode
```
> ⛔ **On the nano3G, the equivalent pair (`accessDecisionMode` + `csgAccessMode`) is the single
> nastiest failure in this whole corpus: set one without the other and you get a SILENT DENY-ALL
> that every instrument reads as healthy.** ⭐ **Assume the same class of trap here and verify with
> a handset, not with a readback.** 📌 [`TRAPS.md`](TRAPS.md).

### 🛰 GPS
```
Device.Services.FAPService.1.Capabilities.GPSEquipped · Device.Services.X_00000C_FAPService.GPS.
```
⚠️ **Many carrier femtocells refuse to radiate without a GPS fix** — a location-compliance gate,
separate from the tamper gate. **Check it before concluding the tamper bit is your only blocker.**

### 📝 Logs, diagnostics — *and the injection surface from Phase 2*
```
Device.X_00000C_LogUpload.Tuning              ⬅ ⭐ THE LEVER. Also the legitimate NV-config channel.
Device.X_00000C_LogUpload.OnDemand.URL · OnDemand.Triggered
Device.X_00000C_LogUpload.Periodic.URL · Periodic.Enable · Periodic.Interval
```
⭐⭐ **`OnDemand.Triggered` makes the unit upload a diagnostic bundle to a URL you choose** — ⇒ **a
read primitive that needs no shell at all**, and `ENV_DIAG_FILE_LIST` (set through `Tuning`) chooses
what goes in it. **Point it at your own HTTP server and read the device's own files.**

### 💓 The CMHS / heartbeat tier
```
X_00000C_MHS.Config.MaxStatsInterval · UpperHeartbeatInterval
X_00000C_MHS.Conn.ConnectionAttemptsBeforeUnavailable · GracefulShutdownWaitTime
```
📌 **CMHS is a SEPARATE server from the ACS, on a SEPARATE IP** (Phase 1, item 4) — and a unit can
be happily informing the ACS while failing CMHS entirely.

---

### ✅ **SO: WHAT YOU HAVE AFTER PHASE 3**

**A unit whose identity, core, gateway, access mode and NV environment you set — all through a
session it opened to you.** **From here the software half of [`BRINGUP.md`](BRINGUP.md) Phases 4–8
applies**: point it at your core, give it radio parameters, unlock, connect.

⛔ **Except on this unit it stops, and the next phase is why.**

---

## 🔴 Phase 4 — The tamper bit, and why this page stops here

**The radio has its own gate, and it is enforced independently of everything above.**

```
X_00000C_Tampered = 1         14 readbacks, consistent
FAPService.Enabled            REFUSED — FAULT 9003 / 9007
```

⇒ **A tampered unit will provision, accept configuration, and refuse to transmit.** Every other
instrument reads healthy. ⭐ **This is the failure that looks exactly like a configuration mistake
and is not one.**

> ### ⛔ AND THE MOST IMPORTANT THING ON THIS PAGE: **THE BIT CAN BE SET BY YOU, AND IT IS ONE-WAY**
> [`Trap 41`](TRAPS.md#41-opening-the-case-can-destroy-a-factory-configuration) is the full entry.
> **Opening the case and guessing the jumper pattern trips a one-way tamper latch in flash.** The
> pattern is **one-hot — one real jumper among blanks, six candidates** — so a guess is far more
> likely wrong than right.
> ✅ **Leaving jumpers off is safe. Restoring a pattern from memory is not.**
> ⇒ 🎯 **If you buy a 154, buy one that has never been opened, and do not open it.** The route above
> needs no case access at all — **and the case is where the radio gets lost.**

---

## What would finish this guide

**One DPH-154 with `X_00000C_Tampered = 0`**, taken through Phases 1–3 and then the software half of
[`BRINGUP.md`](BRINGUP.md). Specifically still unknown:

- **Whether `FAPService.Enabled` is accepted** once the tamper bit is clear — **the fault codes are
  the only evidence we have, and they were taken on a tampered unit.**
- **Whether the tamper bit is clearable at all.** ⛔ **Assume not.** Nothing here has cleared one, and
  a one-way latch in flash is exactly the sort of thing that is not meant to be.
- **Which config-bank layout applies.** The 154 selects **named UBI volumes, not numbered banks** —
  U-Boot reads a 4-byte `default_bank` value, and `config_bank_1`/`config_bank_2` **do not exist on
  it at all.** ⇒ [`Trap 2`](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
  does not apply to this model in the same form.

---

## Two model-specific facts worth having

- **Its U-Boot environment sets `consoledev=/dev/null`** ⇒ **Linux never opens that UART**, and a
  serial capture goes silent after `Starting kernel`. ⚠️ Two people spent ~20 minutes on baud sweeps
  before finding it — **97 % `0x00` is a line held LOW, not misframed data.**
  ⛔ **Do not carry this to another model.** It was measured on the **154's** environment; applying
  it elsewhere has already caused one serial route to be written off wrongly on a different device.
  ⭐ **And note what it does *not* say: U-Boot's own console is a separate stage, and nobody has
  confirmed it dead on a 154.**
- **The external antenna port was deleted** relative to the 151's MCX. ⇒ **The "one room, heavily
  attenuated, remote antenna" deployment is not available on this model.**

> ### ✅ **SETTLED 2026-09-16 BY THE DEVICE'S OWN KERNEL — IT *IS* picoChip, AND IT IS A SINGLE SoC**
> ~~*"The DPH-154 is not picoChip" is not established … the 154's SoC identity is genuinely
> unsettled."*~~ 🔴 **That stood on two third-party attributions. The unit answers it itself:**
> ```
> its serial boot log      Image Name: Linux-3.0.0-ip30xxff-xc-245.0
> its own NAND rootfs      ip30xxff-xc-239.0
> ```
> ⇒ ⭐ **`ip30xx` is ip.access's platform designation for the picoChip PC30xx.** **Two independent
> surfaces on the device, agreeing.**
> ### ⭐⭐ **AND THE OLD BLOCK'S RECONCILIATION WAS RIGHT — IT JUST STOPPED ONE STEP SHORT**
> **The AD9365 is the RF TRANSCEIVER; the PC30xx is the SoC/baseband. Different components, both
> present, no contradiction.** ⇒ **The reasoning was sound and the conclusion was stale.**
> ### 🔴 **AND THE CONSEQUENCE IS STRUCTURAL, NOT TRIVIA — IT IS *ONE* PROCESSOR, NOT TWO**
> ```
> DPH-151   Ralink + picoChip PC202   TWO SoCs   <- the Ralink is the LAN-facing one, with telnet
> DPH-154   picoChip PC30xx           ONE SoC    <- NO RALINK. AT ALL.
> ```
> ⇒ ⛔ **Every Ralink-side route — `rroot.py`, the telnet-as-guest path, anything addressed to
> `192.168.157.185` — is STRUCTURALLY DEAD on a 154.** ⚠️ **The three `192.168.157.185` strings that
> DO appear in its rootfs (`iptables-customerA-rules`, `opt/cisco/reset`, `opt/cisco/DslmSsp`) are
> INHERITED FROM THE 151/153 LINEAGE and name a peer this product does not have.**
> ⭐⭐ **A leftover string naming a nonexistent host reads exactly like evidence that the host
> exists** — and it is in the firewall rules, which is the most convincing place for it to be.


---

## 🔀 Choose your route by WHAT YOU ALREADY HAVE — three of the four are free

> ### ⭐⭐⭐ **THE TRAP IS NOT THAT THE EXPENSIVE ROUTE IS WRONG. IT IS THAT THE EXPENSIVE ROUTE IS THE ONE THAT WORKS REGARDLESS OF PRECONDITIONS — SO IT IS THE ONE THAT GETS WRITTEN DOWN.**

| mechanism | cost | you must already have |
|---|---|---|
| `wizard` UDP/14677 backdoor | free — no reboot, no flash | a unit that **has** it. 151/153 generation. ⚠️ **status on a 154 is UNMEASURED** |
| **`diagnosticTuning` (2320) over DMI** | free — no reboot, no flash | **a DMI console** — which a 151 or nano3G has |
| **`X_00000C_LogUpload.Tuning` over CWMP** | free — no reboot, no flash | **a CWMP session** — which a 154 gives you ⬅ **PHASE 2** |
| **software download, type `0x5007` "sdphook"** | **free — no bank write at all** | the ability to **serve a package** ⬅ ✅ **THIS IS HOW THE DPH-151 GOT ROOT** |
| software download, a **full firmware image** | ⛔ **rewrites both U-Boot banks. Irreversible.** | the ability to serve an image |

### 🎯 **AND THE TWO GOALS HAVE DIFFERENT PRICES — ASK WHICH ONE YOU ARE HERE FOR**

```
GET ROOT / SET NV VARIABLES     any of the top three. FREE.
CHANGE FS_VARIANT PERSISTENTLY  the software download, and ONLY that -- because FS_VARIANT comes
                                from sw_description.dat, re-exported by /etc/profile every boot.
```
> ⭐⭐ **`/etc/profile:56` reads `FS_VARIANT` from the software description and `:63` exports it, and
> `/etc/profile` is the ONLY file in the whole rootfs that assigns it** — `rcS:53` even says so in
> its own comment: *"done after sourcing /etc/profile so FS_VARIANT is set"*.
> ⇒ ✅ **So the irreversible section below is RIGHT about its own goal.** ⛔ **It is only wrong as an
> answer to *"how do I get in"*, which is what it used to be presented as.**

⇒ **If you want a shell and your NV variables, you are done at Phase 2 and you should not read the
next section as instructions.**

---

> ### 🔴🔴🔴 **"SOFTWARE DOWNLOAD" IS TWO COMPLETELY DIFFERENT OPERATIONS, AND THIS PAGE WAS TREATING THEM AS ONE**
> `[JP: "we used the software download for the 151 I thought." He is right — and it is the CHEAP one.]`
>
> | | **`0x5007` "sdphook"** | **a full firmware image** |
> |---|---|---|
> | payload | **a shell script** | a filesystem |
> | what the device does | `post_swdl_hook` **SOURCES IT AS ROOT** | `activate_bank` → `uboot-install` |
> | bank / bootloader write | ⭐ **NONE — a trailing `exit 0` returns from the sourced script and skips `post_swdl_hook`'s `delete_config` / `switching_bank` tail** | ⛔ **BOTH U-Boot banks rewritten** |
> | reversible | ✅ **yes — "it never writes a firmware bank, so the active image stays verifiable"** | ⛔ **no** |
> | status here | ✅ **the route that rooted a DPH-151** | ⚠️ **tested on the 154 by JP; did not work** |
>
> ⇒ ⭐⭐⭐ **The irreversibility belongs to the IMAGE variant, not to "software download".** ⛔ **A
> reader who learns *"software downloads rewrite bootloaders"* will avoid the cheap one too — which
> is the one that actually worked on a sibling model.**
> ### ✅ **WHY `0x5007` NEEDS NO SIGNATURE**
> **Image signing is OFF on these builds (`verifyflash` disabled)** — the package needs only its
> three internal CRCs and a well-formed header. ⇒ **That is the property the whole route rests on.**
> ### ⚠️ **AND THE ONE DETAIL THAT MAKES IT LOOP FOREVER IF YOU MISS IT**
> **The ACS `Download` RPC's `FileSize` MUST EQUAL THE SERVED BYTE COUNT EXACTLY**, or the unit
> fetches a truncated image, the apply fails, and **it retries in a loop.** ⭐ **`stat -c%s` the file
> and put that number in the RPC.**
> ⛔ **DO NOT install the published `cwmp_rce_key`** — its private half is in a public GitHub
> repository. **Mint your own pair.**
> 📌 **The 151's full procedure: [`BRINGUP.md`](BRINGUP.md) ROUTE 3.**

## 📕 THE **FULL-IMAGE** DOWNLOAD ROUTE — NOT USED HERE, AND IT IS THE IRREVERSIBLE VARIANT

> ### ⛔⛔ **DO NOT RUN THIS TO "GET IN". PHASE 2 IS HOW YOU GET IN.**
> **This section stood as Phase 2 until 2026-09-16 and was wrong about what was done.** It is kept
> because **the analysis is sound and the lever is real** — and because a route that vanishes cannot
> be recognised when someone rediscovers it and assumes it is the supported path.
> ⚠️ **It rewrites BOTH U-Boot banks.** A reader who follows a deleted-and-replaced walkthrough
> would have taken an irreversible step for access they already had.

**There is exactly one CWMP-reachable writer of the NV environment, and it is the software-download
path.** Serve the unit a firmware image and it runs, unprompted:

```
CWMP Download -> swdl_client -> activate_bank -> activate_fs -> set_hardened_state
      (loop-mounts OUR fs.bin, reads FS_VARIANT from its /etc/sw_description.dat)
   -> init_nv_env -> setnv_env.sh <variables>
```

> ### 🎯 **THE LEVER IS NOT THE FILE WRITE. IT IS `FS_VARIANT`, AND IT COMES FROM THE IMAGE YOU SUPPLY.**
> `set_hardened_state` loop-mounts the filesystem **you served** and reads `FS_VARIANT` out of its own
> `/etc/sw_description.dat`. The hardening decision is then **a pure function of the 4th character**:
> ```
> rcS:48   FS_LETTER=$(echo $FS_VARIANT | cut -c4)   ->  DEFAULT_UNHARDENED
>          hardened only for:  A C E G I W X Z
> ```
> ⇒ ⭐ **You choose that character.** The unit hardens or unhardens *itself*, on your say-so, through
> its own vendor code path.

> ### ⚠️ A LATENT DISAGREEMENT BETWEEN TWO IMPLEMENTATIONS OF THE SAME TEST
> ```
> rcS:84-93          A C E G I W X Y Z   (9 letters — INCLUDES Y)
> swdl init_nv_env   A C E G I W X   Z   (8 letters — NO Y)
> ```
> ⇒ **A `…Y…` variant is treated as UNHARDENED by `rcS` and as HARDENED by `swdl_client`.** **Someone
> will trip over it** — and a unit in that state disagrees with itself about what it is.

⛔ **`-noswap` is never passed** (the operation type is hardcoded), so `activate_bank` **does** run —
which means **`uboot-install` rewrites both U-Boot banks first.** ⇒ **This is not a reversible probe.
It rewrites bootloaders.**

📌 **And do not expect `ENV_FIREWALL_DISABLED` in `nv_env.sh` to do anything on its own** — that
value is **dead state** for the running environment. The firewall follows `FS_VARIANT`, not the file.
**The file write is inert; the variant letter is the lever.**
