# Traps

Failure modes that cost us days. Each one is written as **SYMPTOM** (what you will see),
**MECHANISM** (why), and **CHECK** (the observation that distinguishes it from what it
resembles).

**Every trap states what it was measured on**, and the ones that matter most for cross-device
safety name a **model**. These models differ, and an instruction correct for one can destroy
another — trap 2 is a worked example of exactly that.

> ### ⚠️ This paragraph used to claim more than the file delivers
> It said *every* trap names its device. **It does not** — a substantial minority name a model,
> some say only "Measured", and most of the rest name a **source** instead: a vendor binary, the
> core, the management library, a 3GPP document. That is the honest answer for a trap that is not
> model-specific, but it is **not the same claim**.
>
> ⚠️ **An earlier revision of this correction gave exact counts. They went stale within the day**,
> because every entry appended after they were written falsified them while the sentence went on
> looking authoritative. ✅ **The counts are therefore deliberately not stated here.** Measure them
> when you need them — this is the answer that cannot rot:
> ```sh
> grep -c '^## [0-9]\+\. ' TRAPS.md                          # total entries
> grep '^\*\*Measured on' TRAPS.md | grep -c 'DPH-15[134]\|nano3G'   # naming a model
> ```
>
> ⇒ **Where an entry does not name a device, do not assume it applies to yours.** The gap is
> left visible rather than closed by attributing hardware we cannot verify after the fact.
>
> **Count it yourself rather than trusting this paragraph — it will go stale exactly the way the
> last one did:**
> ```sh
> grep -c '^## [0-9]' docs/TRAPS.md                               # traps
> grep -A2 '^## [0-9]' docs/TRAPS.md | grep -c 'DPH-15\|nano3G'   # of those, naming a model
> ```

> ### The one habit that would have saved most of this time
> **Name the question your instrument actually answers, and check it is the question you
> asked.** Nearly every entry below is an instrument that was working correctly and
> answering something adjacent: `md5` answers *are the bytes right*, not *will it run*;
> `ps` answers *is it listed*, not *is it running*; `show hnb` answers *do I hold a session
> object*, not *is the peer alive*.

---

## Start here

**You are not going to read them all before you start, so here is the order that matters.**
`(For how many there are, count them: ` `grep -c '^## [0-9]' docs/TRAPS.md` `. A number
written in prose here would be correct exactly once, and this file has already outgrown one.)`

### ☠️ Before you touch the hardware — these are irreversible
| | trap | what it costs |
|---|---|---|
| A | **[#41 — do NOT put the jumpers back](#41-opening-the-case-can-destroy-a-factory-configuration)** | guessing the pattern trips a **one-way tamper latch in flash**. Leaving them off is safe; restoring from memory is not. |
| B | **[#31 — the other firmware bank may have no way in](#31-booting-the-other-firmware-bank-can-remove-every-way-back-in-and-it-is-sticky)** | one bank has no root account and no entry path, and the selection is **sticky**. |
| C | **[#32 — unpacking the firmware overwrites your `/`](#32-unpacking-the-firmware-overwrites-your-filesystem)** | absolute paths in the archive. Only a permission error stopped it. |
| D | **[#33 — correcting the PLMN removes a safety interlock](#33-correcting-the-plmn-silently-removes-a-safety-interlock)** | the wrong PLMN was itself preventing transmission. Nobody chose to remove that. |
| E | **[#49 — the reset button restores sooner than documented](#49-the-reset-button-reaches-factory-restore-sooner-than-the-manual-says)** | measured **3 s** where every document said 5. A press you believe is a reboot can be a **factory restore**. Read your own unit's threshold. |

### 🔴 Before you conclude anything is broken
| | trap | why it is here |
|---|---|---|
| 1 | **[#21 — give a cold boot 20 minutes](#21-a-cold-boot-takes-about-16-minutes-and-every-check-gave-up-sooner)** | ten cold boots scored as failures. The cell was fine. Three confident negatives, **all correct when taken and all early**. |
| 2 | **[#25 — it deregisters after ~15 s, and it is NOT the famous bug](#25-it-registers-de-registers-15-seconds-later-and-it-is-not-the-famous-bug)** | same window as a well-known fault, completely different cause — and the real one is now traced end to end. |
| 3 | **[#5 — two parallel state triplets](#5-a-cold-boot-leaves-the-cell-locked-and-the-obvious-unlock-sets-the-wrong-attribute)** | invisible for months, because the attribute you naturally read is the one that looks healthy. |
| 4 | **[#3 — an address the AP cannot be reached at](#3-the-ap-advertises-an-address-it-cannot-be-reached-at)** | one root cause, four unrelated-looking symptoms. One command finds it. |
| 5 | **[#6 — `show hnb` lies in both directions](#6-show-hnb-on-the-core-lies-in-both-directions)** | it reported a cell connected for three minutes after it was unplugged. |
| 6 | **[#50 — it shows the network and will not connect](#50-the-handset-finds-the-cell-shows-it-and-will-not-connect--because-you-are-lying-to-it-about-your-power)** | looks like access control; is actually **your SIB5 power advertisement**, and the handsets are the ones transmitting too hot. |
| 7 | **[#51 — a staged radio parameter fires at the NEXT reboot, whoever causes it](#51-a-staged-radio-parameter-is-a-loaded-change-and-any-reboot-fires-it)** | the write succeeds and changes nothing visible. A crash or a power cut applies it later, and nobody links the two events. |

### ⏳ Before you spend a week on something
- **[#45 — you may not need a security gateway at all](#45-you-may-not-need-a-security-gateway-at-all)** — the audited unit reached full service without one.
- **[#47 — working on the device changes the device](#47-working-on-the-device-changes-the-device)** — ~2.5 MB free RAM, no swap, and your own debugging can reboot it.
- **[#46 — a second cell removes service rather than adding it](#46-a-second-cell-on-the-same-plmn-removes-service-instead-of-adding-it)** — handsets pick on signal, not on whether the cell works.

---

## 1. `IUH_ENABLE` — two config files, two parsers, one silent failure
**Measured on an ip.access nano3G (train `563.16.0`), same firmware family as the DPH-151.**

**SYMPTOM.** Registration, authentication and call setup all work perfectly. Calls connect,
phones ring — and **no audio bearer ever forms**. This can persist for weeks because the
control plane is entirely healthy.

**MECHANISM.** The flag is read from two different config files by two different parsers:

```
uplayerapp.cfg :  IUH_ENABLE 1        <- ONE line.  Parsed with sscanf("%s%d")
3gcntrl.cfg    :  IUH_ENABLE          <- TWO lines. strcmp on the WHOLE line,
                  1                      then a separate read for the value
```

Appending `IUH_ENABLE 1` to `3gcntrl.cfg` — the form that works in the other file, and the
form the file's own header teaches — **matches nothing, is skipped silently, and is never
logged.** The flag gates nine user-plane behaviours (buffer sizes, frame counts, RTP
payload type, the payload-type filter) and **touches no control-plane path**. That is
precisely why everything else works.

**CHECK.** ⛔ `grep -c IUH_ENABLE` returns 1 for a working *and* a broken config, so it
cannot distinguish them. Check the **runtime** proof — both processes announce it:

```
>>> IUH OPERATION IS ENABLED IN UPLAYERAPP
>>> IUH OPERATION IS ENABLED IN 3GCTRLAPP
```

Both lines, or the flag did not take.

> ### 🔴 BUT THAT CHECK HAS ITS OWN SILENT FAILURE, AND IT IS THE SAME SHAPE AS THE BUG
> **The banner only reaches that log under a developer-mode flag.** So an empty grep is
> **indistinguishable** from *"the flag did not take"* — you cannot tell a real negative from a
> log that was never written.
> ✅ **Pair it with a positive control on the same file**: grep for something you know that process
> logs. Control silent ⇒ your instrument is off, not the flag.

> ### ⚠️ SCOPE IS CONTESTED, AND THE SAFE ACTION IS THE SAME EITHER WAY
> **This defect was measured on an ip.access nano3G.** Two readings of our own corpus disagree
> about whether it applies to a DPH-151: one says that firmware ships the key correctly in both
> forms, the other says **neither those config files nor that key has been confirmed to exist on
> the DPH family at all.** We have not resolved it, and we are not going to pretend we have.
>
> ### ⭐ PARTIALLY RESOLVED, AND IT RESOLVES TOWARD "THIS IS REAL"
> **Both parse styles live in ONE binary** — ten file-open/whole-line-compare/string-to-long
> blocks, plus nine formatted-scan sites clustering separately. ⇒ **That is what makes this a live
> hazard rather than a per-model quirk**: the same program genuinely parses two ways.
>
> ⚠️ **And the parse is INIT-ONLY** — a mid-boot fix changes nothing until the process restarts.

> ⛔ **So do not go hand-appending anything. CHECK FIRST** — look for the key in both files on
> your own unit, and use the runtime banner below rather than the config to decide whether it
> took. The check is cheap and it is correct under either reading.

> ### ⭐ AND THE PART THAT DEFEATS THE OBVIOUS FIX: **the KEY line must end in a newline.**
> The key-matching path **NUL-writes the last character unconditionally**, assuming a trailing
> newline is there to overwrite. ⇒ **A key line with no trailing newline** — because it landed
> last in the file, or a copy lost the final `\n` — **becomes a truncated token and the whole-line
> compare fails.**
> ⭐ **The asymmetry is real and worth knowing: only the KEY line is fragile.** The value line is
> parsed from raw input and is safe either way.
> ⇒ So *"I put it on two lines like the guide said and it still doesn't take"* has a second cause,
> and it is invisible in every editor. **`od -c` the last line** (trap 27's instrument, again).

⚠️ Two smaller bounds: the banner prints on any non-zero value while the Iuh branch takes
only on exactly `1`, so a `2` would print the banner and not take the path; and our
instruction-level evidence is for one point release.

---

## 2. Which config bank is live differs **per model** — and guessing kills the cell
**Measured on a DPH-151 and an ip.access nano3G. They are opposite.**

**SYMPTOM.** You follow a bring-up note that says "point the config symlink at bank 2", and
the cell comes back with **no Iuh, no UARFCN, and no cell at all**.

**MECHANISM.** Configuration lives in two banks with a symlink naming the live one. On our
**nano3G the live bank is 2**; on our **DPH-151 it is 1**, and that unit's **bank 2 is empty —
0 files, directory dated 2014**. A note written for one device is lethal on the other, and
**the note is not wrong — it is unscoped.**

⚠️ **A correction worth carrying, because we published the wrong version first:** an earlier
reading of ours claimed *"14 of 15 config files differ between the banks"*. That was
**retracted by its own author** — the comparison loop hashed a *missing* file (an empty
string) against a real hash and printed DIFFER for each one. **The banks do not differ; the
alternate one is simply empty**, which is incidentally evidence this unit has never failed
over.

⚠️ **The fix for a note like that is a scope line, never a flip.** Reversing it just breaks
the other device instead.

**CHECK.** **Read the symlink. Never assume.**

```sh
readlink -f /var/ipaccess/config    # -> config_bank_N. That N is the answer for THIS unit.
ls /var/ipaccess/config/            # a populated bank = healthy. 0 files = wiped.
ls /var/ipaccess/config_bank_*      # does the ALTERNATE bank hold anything?
fw_printenv bank                    # which bank the bootloader will use NEXT
ls /tmp/booted_from_alt             # proves THIS boot came up on the alternate bank
```

⚠️ **`/tmp/booted_from_alt` is perishable** — `/tmp` clears on the next boot, so the evidence
that a failover happened is destroyed by the very next power cycle. **Read it first.**

> ### ☠️ `fw_printenv` and `fw_setenv` are the SAME BINARY, dispatching on `argv[0]`.
> Identical hashes, both symlinks. **Invoke it by the `fw_printenv` name and never build that
> name programmatically** — the read tool is the write tool, and a variable holding the wrong
> name turns an inspection into a permanent change to the boot environment.

**Three things wipe or switch a bank**, and only the first needs no human:
1. **Bank failover.** The bootloader repoints the symlink at the other bank *and makes it
   sticky* — the device does not come back on its own, and **an image failover drags the
   config with it** (the live bank is derived from the booted rootfs device, not from
   configuration). ⚠️ A *normal* reboot does **not** do this.
   ⚠️ **It takes FOUR consecutive failed boots, not one** — measured `bootcount=1`,
   `bootlimit=4` on our unit. We ranked this hazard far too high on the strength of "one
   failed boot", which was inherited from a different device's notes and retracted.
2. **A software download.** The post-download hook deletes the live bank's contents.
   ⚠️ **Nothing mitigates this — re-apply every hand edit after any software download.**
3. **Factory restore.** Guarded; needs an explicit argument that normal boot never passes.

⚠️ **BOUND: not every config file follows the bank.** For at least one vendor management daemon
the two banks' config files are **byte-identical**, and the file is re-copied from a fixed path on
**every start** — so a bank switch does not change it, and "it must be a bank difference" is not
available as an explanation for that daemon's behaviour. Check the specific file before assuming
the bank explains anything.

> ### ⚠️ And some state is not in a bank at all, so copying banks preserves only part of a cell
> On an **ip.access nano3G**, the radio band is **in neither bank**. No bank holds the UARFCN
> anywhere; it lives in a file at the top of `/var/ipaccess`, **above** the bank directories.
> ⇒ **A bank-to-bank copy can carry your Iuh key and not your carrier**, and a restore that
> looks complete comes back on a band you did not choose.
>
> ⛔ **The bounds are the interesting part here, so they are stated rather than smoothed over:**
> ```
> power cycle         MEASURED surviving, twice
> bank failover       INFERRED from the file's location -- NOT TESTED
> software download   INFERRED from the file's location -- NOT TESTED
> ```
> ⚠️ **We first wrote "a bank failover cannot touch it", which is the inferred half stated as
> certainty** — a claim about *system behaviour* asserted from a *fact about a path*. The
> download hook deletes `config_bank_$BANK/*`, so a file above that directory is **plausibly**
> out of reach. **Plausible is not measured**, and one of three triggers is tested.
>
> ⛔ **Device scope, and this is the one that is genuinely tempting to get wrong:** measured on
> a nano3G. **Whether a DPH-151 or DPH-154 keeps its band in the same place is UNMEASURED.** It
> reads like a firmware-layout fact rather than a per-unit configuration choice, which is
> precisely the reasoning that would carry it across — ⭐ **and this trap is the worked example
> of why that reasoning fails in this exact area**, given the bank numbering is already reversed
> between two of these models and the third has no banks at all.

> ### ⛔ And read this before running any "restore" procedure
> A restore document's natural voice is *"run this to get back to known-good"*, which is
> **indistinguishable from "run this over a working system"**. Branch on a measurable before
> you copy anything: **15 files and the symlink pointing at your live bank ⇒ the bank is
> HEALTHY, do not restore, you have a different fault.**

---

## 3. The AP advertises an address it cannot be reached at
**Measured on a DPH-151. This is the single highest-value entry here.**

**SYMPTOM.** Three or four faults that look completely unrelated:

```
voice uplink     works
voice downlink   silent
packet data      the GGSN rejects the AP's packets as coming from an unknown peer
Iuh registration intermittently never arrives at all
```

**MECHANISM.** The DPH-151 has an internal NAT between its two processors. It signals **its
own internal private address** — the one behind that NAT — as both its **RTP** and its
**GTP-U** transport address, while its packets actually egress from its LAN address. So the
core dutifully sends media to an address that routes to the default gateway and is dropped,
and the GGSN checks the *source address* of arriving packets against the one it was told and
refuses them.

The Iuh symptom is the same root in the other direction: the AP sometimes emits its SCTP
INIT **from** the un-NATted internal address, and that never arrives.

> ### ⭐ Why nobody found this for hours: every counter said the packets left, and every
> ### counter was **correct**. The media gateway reported "sent 246, dropped 0" — both
> ### numbers true. **The kernel drops nothing when it hands a packet to a gateway.**
> Every other instrument trap is about a suspicious zero. This one **reads as success** and
> answers a different question: *did we send it?* rather than *could it arrive?*

**CHECK.** One command, on the core, against the address the AP advertised:

```sh
ip route get <the transport address the AP signalled>
```

If that resolves **via your default gateway** rather than to the AP, you have this fault.
Confirm with `ping` and an ARP-table check.

**FIXES — and they are three different fixes, because the symptoms are three directions.**

| symptom | fix |
|---|---|
| **voice downlink** | a `/32` host route on the core pinning the advertised address to the AP's real LAN address. Touches nothing on the AP. |
| **packet data** | ⛔ the host route does **not** help. The GGSN rejects on the **source address of the arriving packet**, not on a routing decision — so it needs a **stateless header rewrite at PREROUTING**. |
| **Iuh INIT** | neither helps — this is the *source* address of an outgoing packet. A **retry loop** on the establish is what works, which is why one attempt is unreliable and a retried one is not. |

⛔ **`snat` on an nftables `input` hook cannot work** for the data case and we tried it: by the
time the packet reaches `input` it is already being delivered to a local socket, so there is no
egress left to rewrite. Measured ineffective, reverted.

> ### ⚠️ "IT WORKED ON MY OTHER FEMTOCELL" IS A TOPOLOGY DIFFERENCE, NOT A REGRESSION
> **A single-processor sibling is structurally immune** — one device, one address, so whatever it
> advertises is necessarily correct. There is no fault available for it to have. Comparing against
> it tells you nothing, and it makes your two-processor unit look broken.

⚠️ **And the encoding option is not the fix**, though it looks like one: it selects an *encoding*,
not an *address* — re-encoding the private address still yields the private address. On some
builds it is a fatal config parse error. ⛔ **And the log line naming the encoding is the
zero-initialised default, not confirmation that anything was applied.**

⛔ **There is no device attribute for this.** We checked the vendor's full attribute table:
only gateway, IPsec and DHCP addresses exist. And `snat` on an nftables `input` hook does
**not** rewrite what the application sees — tried, measured ineffective, reverted.

---

## 4. `csgIndicator` reads FALSE in the database and broadcasts TRUE on the air
**Measured on an ip.access nano3G, decoded off the air from a handset's own diagnostic
stream. Not read on a DPH.**

**SYMPTOM.** Some handsets silently refuse to camp on the cell. They receive it at strong
signal, decode the full cell identity, pass the cell-selection criteria by a wide margin,
and **never transmit** — no rejection is logged anywhere, on either side.

**MECHANISM.** Both CSG attributes in the device database read open (`csgIndicator = FALSE`,
`csgAccessMode = OPEN_ACCESS`) — the writes landed. **The broadcast MIB says
`csg-Indicator = TRUE` anyway**, and the MIB value-tag increments, i.e. it was *regenerated*
with TRUE put back. The MIB builder appears to read neither attribute — most plausibly it
hardcodes *"this is a Home NodeB, therefore advertise CSG-capable"*. ⚠️ **That last clause is
an inference; what is measured is that both attributes say open and the air says closed.**

> ### ✅ SOLVED — and the fix is a **PAIR**, where each half alone is **worse than the broken baseline**
> ```
> accessDecisionMode = LEGACY        <- takes csg-Indicator OUT of the broadcast MIB
> csgAccessMode      = OPEN_ACCESS   <- no access control at all
> ```
> **Eight handsets attached within about 60 seconds of the second write**, having silently
> declined the cell for weeks. `[measured, ip.access nano3G]`
>
> ⭐ **The inference above was wrong in an instructive way.** The MIB builder does not ignore
> both attributes — it reads `accessDecisionMode`, which **nobody had set**, because nothing in
> the documentation pointed at it. `csgAccessMode` alone cannot remove the indicator.
>
> ⛔ **And this is why it stayed unsolved: every single-attribute test looked like a failure.**
> ```
> LEGACY alone          -> DENY-ALL. Every handset rejected. The worst of the three states.
> OPEN_ACCESS alone     -> some handsets served, the strict ones still refuse. The old baseline.
> LEGACY + OPEN_ACCESS  -> all eight served.
> ```
> ⭐⭐ **A one-at-a-time search CANNOT find a fix whose components are individually harmful.**
> Both halves had been tried separately, and both were "disproven" by exactly the evidence a
> careful tester trusts. ⇒ **If you are changing one variable at a time and every change makes
> things worse, that is a signal about the SHAPE of the fix, not about the variables.**
>
> ⛔ **NEVER set `LEGACY` without `OPEN_ACCESS`.** The vendor calls it *"Closed Access in Legacy
> Mode"*: **stop advertising the gate, keep enforcing it on everyone.** With an empty access list
> that is deny-all, and **nothing reaches the core at all** — so every instrument you would reach
> for says the cell is healthy while no handset can use it. It is a nastier failure than the one
> it replaces, because the previous one at least let some handsets through.
>
> ⭐ **The confirmation was the SHAPE of the recovery, not the count.** They arrived in a wave —
> five, then seven, then eight, inside a minute. Handsets being *rejected and retrying* would
> have trickled in; handsets **declining to attempt** all appear at once when you remove the
> reason. **The wave is evidence about the mechanism, and a slow trickle would have refuted it.**
>
> ⚠️ **`OPEN_ACCESS` means strangers' handsets will ATTEMPT to attach.** On a live cell,
> devices belonging to a real commercial carrier reached the core and were refused *there*.
> ⇒ **The gate moves from the air interface to your core.** That is workable, and it is a
> different security posture from the one you thought you had. Choose it deliberately.
> ### 🔴 The narrower alternative is worse than untested — there is one measurement and it points the wrong way
> `LEGACY` plus a **populated** access list is the obvious way to keep a closed cell without the
> deny-all. An earlier revision of this trap said whether that list survives a reboot had never
> been measured. **It has, once:**
> ```
> before    accessControlList   populated with allow entries
> after     accessControlList   ()            <- empty
> upTime    626 -> 515                        <- it went DOWN, so the unit rebooted between reads
> ```
> **The list did not survive.** ⇒ ⛔ **If the enforcement half persists and the permission half
> does not, a reboot leaves the cell enforcing against an empty whitelist — which is deny-all,
> and is exactly the outage described at the top of this trap.** The narrow option can therefore
> re-arm the failure this trap exists to document, at the first power cut, with no one touching
> anything.
>
> ⚠️ **n=1, and the mechanism is not established.** One reboot, and nothing rules out something
> else in that window having cleared the list. **That is enough to stop you automating closed
> access on the assumption it persists; it is not enough to state non-persistence as a
> property.** Measure it on your own unit across a deliberate power cycle before relying on
> either answer.
> ⭐ **Note the instrument, which is the reusable part: `upTime` going DOWN is what proves a
> reboot happened between two reads.** Without it the empty list is just a value you cannot
> explain.

A strict Release-8 handset with an empty Allowed CSG List is *required* by 3GPP TS 23.122 to
decline such a cell. Others tolerate it and camp happily — so this presents as "some of my
phones work and some don't", per handset model.

**CHECK.** ⛔ **Do not read this from config.** The setter even warns that the attribute is
read-only and writes it anyway; the value changes and the broadcast does not. **Decode it off
the air**, or infer it from the pattern: a handset that receives your SIBs, derives the full
cell identity, and never transmits is exhibiting this rather than being misconfigured.

> ### ⚠️ PUBLISH THIS AS AN INSTRUMENT LESSON, NOT AS A DIAGNOSIS.
> **The measurement stands. Every causal consequence we drew from it has been superseded.**
> We once wrote that five handsets refused this network and that strict Release-8 CSG was
> why. **That framing is refuted** — the refusal turned out to be specific to one *cell*, not
> to the PLMN and not to CSG membership, and the same handset model camped happily on a
> different cell with the same SIM and the same PLMN. Separately, manual CSG selection —
> which bypasses the allowed-list by specification — was issued correctly on another handset
> and failed *inside the modem* without transmitting.
>
> ⇒ **What survives is the instrument lesson: a database read is not an air read.** What does
> not survive is "and that is why your handsets refuse."

⭐ **What made this a finding rather than a stale cache:** the MIB value-tag *incremented*. The
write was **consumed** — it triggered a rebuild — and the rebuild put `TRUE` back. "Consumed
and discarded", not "ignored".

⛔ **Not established: the DPH's own CSG values are unread by anyone.** This is a nano3G
measurement and it may not describe your Cisco unit at all.

⛔ **And a useless instrument, worth naming so you don't trust it:** Android's `dumpsys`
`mCsgInfo` field reads `null` on a cell *known* to be broadcasting closed-CSG. It carries no
information.

---

## 5. A cold boot leaves the cell LOCKED, and the obvious unlock sets the wrong attribute
**Measured on a DPH-151.**

**SYMPTOM.** After a power cut the cell registers with the core and no handset can use it.
You issue an unlock; **it is acknowledged**; nothing changes.

**MECHANISM.** Two similarly-named attributes. The unlock action you reach for sets
`rrmAdminState` — a **real state change**, correctly acknowledged — and never touches the
cell's `administrativeState`, which is the one that gates service.

> ### ⭐ Why this survived for months: **every warm reboot confirmed it**, because a warm
> ### reboot never re-locks the cell. The sequence was validated hundreds of times by cases
> ### structurally incapable of exposing the bug. A proxy with a long record of being right
> ### is *more* dangerous than one nobody has tested.

> ### 🔴 AND A SECOND FACE OF THE SAME TRAP: `action <NUMBER>` ACKS AND DOES NOTHING.
> Measured side by side on a DPH-151, and **both acknowledgements are the identical string**:
> ```
> action 1216       -> "Request ack'd."   rrmAdminState UNCHANGED at LOC_LOCKED
> action rrmUnlock  -> "Request ack'd."   rrmAdminState LOC_LOCKED -> LOC_UNLOCKED
> ```
> ⚠️ **The number is not wrong.** `1216 = unlock` was verified in the device's own action table
> and cross-checked against the lock action found independently in disassembly. It is correct
> and simply **not dispatchable by number** through this client. Reading this as "1216 is the
> wrong id" sends the next person to re-derive a mapping that is already right.
> ✅ **Fire actions by NAME.**

> ### 🔴 A THIRD FACE: `selectCellParams` IS A NO-OP WHILE THE RRM IS LOCKED.
> It acks and does nothing. Our own notes record the correction: *"'acked but no effect' was
> recorded as a property of the VERB when it was a property of the STATE — that misreading
> cost hours and sent three agents hunting a gate that never existed."* **Order matters:
> unlock, then select.**

**CHECK.** Read **both triplets, always** — never one:
```
get administrativeState   operationalState      availabilityStatus
get rrmAdminState         rrmOperationalState   rrmAvailabilityStatus
```
Do not accept the acknowledgement, and do not accept a change in the *other* attribute as
evidence.

⛔ **Prefer `action unlock` over `action rrmUnlock`.** On the sibling nano3G, `rrmUnlock` is
measured — by paired isolation, both arms — to command the radio-resource process to **exit**
(an orderly commanded shutdown, not a crash). The DPH run that moved `rrmAdminState` **never
checked whether that process survived**, and its own author flags the gap: *"my run may well
have killed RRM and I would not know."*

⚠️ **And do not install your fix before you take the measurement.** We ran a self-healing
patch whose whole job is unlocking the cell *before* anyone looked at the raw post-boot
state — and *"the setting persisted"* and *"the patch unlocked it"* produce **identical
readings**. It was only recoverable because the patch logged when it acted. **Any
self-healing fix must log that it acted, or it destroys the evidence for whether it was
needed.**

---

## 6. `show hnb` on the core lies in **both** directions
**Measured on `osmo-hnbgw` against a DPH-151.**

**SYMPTOM A — false positive.** It reports `1 HNB connected` with **climbing uptime** for a
cell that has been **unplugged from the wall**. We measured this holding for about three
minutes in one test and nearly ten in another, across 13 samples, all false.

**SYMPTOM B — false negative.** Roughly **one read in seven** returns the **welcome banner
only** — a few hundred bytes of confident-looking text with no answer in it.

**MECHANISM.** (A) The command reports the gateway's **session context**, not the device. A
stale context is perfectly stable and survives any dwell shorter than the SCTP timeout.
(B) is a race in the VTY itself — we reproduced it at **6 failures in 40 reads (15%)**, and
**both arms were identical**: 20 reads over separate SSH invocations and 20 inside one
session each gave 17 valid / 3 banner-only. So it is not the transport.

**CHECK.**
```sh
printf 'enable\nshow hnb\n' | nc -q1 <core> 4261
```
- ⛔ **Never classify by byte count.** A banner-only read is 463–525 bytes and a good read is
  ~1088; but a size classifier scores every banner as "ok, just short". **Require the literal
  token `HNB connected`.**
- **Retry on a token miss.** A single clean read of that port means nothing.
- For liveness, cross-check against something that **cannot lie toward success**: the AP's own
  `/proc/uptime` (a low value cannot be faked), and the peer's SCTP state — `SCTP_INACTIVE`
  sits one line below the lie in the same command's output.

⚠️ **A related discriminator, free:** `SCTP_SHUTDOWN_EVENT` means the peer *chose* to close
(the admin-lock fault); `SCTP_COMM_LOST` means it *vanished* (power cut, crash, reboot). A
detector written around the failure you have already seen goes blind on the next one.

⚠️ **And a `COMM_LOST` with no registration since boot is a zombie being reaped, not a drop.**

---

## 7. A trailing `exit` blinds the VTY
**Measured on Osmocom VTY consoles.**

**SYMPTOM.** `nc` to a VTY port returns **zero bytes**, and you conclude the tool cannot talk
to the daemon.

**MECHANISM.** It is the `exit` line, not `nc`.

```
printf 'enable\nshow hnb\n'       | nc -q1 → 1116 bytes   ✅
printf 'enable\nshow hnb\nexit\n' | nc -q1 →    0 bytes   🔴
printf 'show hnb\n'               | nc -q1 →  720 bytes   🔴  "% Unknown command."
```

> ⭐ **The failing form is the more careful one.** Closing the session politely blinds the
> instrument, which is why it reads as "the tool is broken" rather than "my invocation is
> wrong."

**CHECK.** Use `printf "enable\n<cmd>\n" | nc -q1 <host> <port>`, **never a trailing `exit`**.
⚠️ And note the third line: without `enable`, you get 720 bytes of `% Unknown command.` —
**not empty**, so an emptiness check passes it and you act on a non-answer.

---

## 8. Your deploy passed `md5` and the program never ran
**Measured on a DPH-151: three deploys, three matching hashes, zero executions.**

**SYMPTOM.** You deploy a script, verify it, and its effects never appear. The log is empty —
which is indistinguishable from "the hook never fired" *and* from "it fired and did nothing".

**MECHANISM.** Deploying with `cat > f.new && mv f.new f` creates the file at the default
`0644` — **no execute bit**. The boot hook's `[ -x "$WD" ] && ... && run` guard then fails,
the `&&` chain short-circuits, and **nothing is logged at all**. `md5sum` matched the source
every time, because a content hash is structurally incapable of answering *"will it run?"*.

> ### 🔴 The cost was not the wasted deploy. It was that the cell being still LOCKED read as
> ### *"the patched watchdog fails to clear a lock it is written to clear"* — a logic-bug
> ### question about **code that had never executed**. It was one message from becoming
> ### someone's assignment.

**CHECK.** Three separate questions, three separate instruments:
```sh
md5sum FILE                     # are the bytes right?          CONTENT ONLY
ls -l FILE   /  test -x FILE    # will it run?                  MODE
```
✅ Better: deploy with `install -m 755` so the mode can never be inherited.

⚠️ **And a third question people skip entirely: is the *running* process actually this file?**
An interpreter reads a script **once at exec**, so replacing it under a running service leaves
disk and memory silently divergent while every content check reports fine. Compare the
process start time against the file mtime; if the file is newer, it was rewritten without a
restart. ⛔ Do not reach for `/proc/PID/exe` — for an interpreted service that resolves to the
*interpreter*, a confident answer about the wrong file.

---

## 9. A vestigial precondition fails closed and sends you to fix the wrong thing
**Measured on a DPH-151, during an unattended cold boot.**

**SYMPTOM.** An automated bring-up blocks with a clear, specific error telling you to change
a setting and reboot. The setting is genuinely not set. **The device does not need it.**

**MECHANISM.** The script used to drive the DMI console over TCP 8090, so it gated on that
port being up. The transport was later changed to a local one-shot client **that needs
nothing from port 8090** — and the gate stayed. On a cold boot it waited for a port nothing
opens, while the transport it actually uses was answering every read taken during that same
boot.

> ### ⭐ Two general points, and the second one is the reusable one:
> - **A vestigial precondition is indistinguishable from a live one.** Nothing in a gate says
>   which dependency it was written for, and it fails *closed*, so it presents as *"the system
>   is not ready"* rather than *"this check is obsolete"*.
> - **An error string is the one piece of documentation nobody ever reviews**, because it is
>   only ever read when something is already going wrong — so its reader is debugging, not
>   auditing. Ours told a reader to reboot for a setting the device does not need, and it was
>   quoted onward as authoritative *because* it lived in the canonical script.

**CHECK.** **Test the transport you actually use**, with a positive control on a known-present
value. ⛔ Do not delete the gate — a fail-closed gate testing the wrong thing is a bug, but
*no* gate is a different bug. **Re-aim it.**

---

## 10. The cell registers and there is no radio
**Measured on a DPH-151.**

**SYMPTOM.** The core accepts the HNB registration. Everything looks up. **No handset can
attach.**

**MECHANISM.** With `rfParamsCandidateList` empty, the select action **acknowledges and
selects nothing**: `uarfcnDownlink = -1`, `scramblingCode = -1`,
`operationalState = DISABLED`. An HNBAP association with no radio.

> ### 🔴 An earlier revision of this trap blamed `AUTO`, and had it backwards.
> It said AUTO *"selects from a candidate list"*. **It does not.** `AUTO` selects from
> **network-listen scan results**; `CONFIGURED` is the mode that reads your list — the vendor's
> own management library says so. Detail and corroboration:
> [`CONFIG.md`](CONFIG.md#rfparamscandidatelist--the-one-nobody-sets-and-the-cell-dies-without-it).
>
> ⚠️ **The measurement below is untouched and still stands. What is no longer established is
> WHY it worked.** Populating the list moved a real unit to a live carrier in 15 seconds, and
> that is only consistent with the library text if the unit was **already** in `CONFIGURED` —
> i.e. if *"defaults to AUTO"* was an assumption nobody read back. **We did not record the
> method at the time, so we cannot close it**, and we are not going to invent a reading.
> ⇒ **Read `cellParameterSelectionMethod` back on your own unit rather than trusting either
> account of what the default is.**
>
> ⭐ **The consequence if yours IS in `AUTO`:** populating the list changes **nothing**, and a
> no-change reads as *"the list is not the problem"* — sending you away from the fix instead of
> toward it. **Set the method first, then the list.**

**CHECK.** A registration alone is **not** an acceptance criterion. Require all three:
```
the core accepted an HNB-REGISTER-REQ after THIS boot
operationalState = ENABLED
uarfcnDownlink > 0
```
Populating the list moved ours from `-1` to a live carrier and `ENABLED` **within 15 seconds**.

---

## 11. NTP: writing the factory tier is not writing the value in force
**Measured on a DPH-151.** Covered in [`CONFIG.md`](CONFIG.md); repeated here because the
failure is silent.

**SYMPTOM.** The HNB-GW connection is never attempted. It looks exactly like the HNB-GW step
being broken.

**MECHANISM.** Without working NTP the device does not even try. There are two NTP
attributes: an **operational** one and a **factory-default** one applied after a reset. The
widely-circulated instruction names the factory one. Writing it succeeds, reads back fine,
and changes nothing in force.

> ### 🔴 CORRECTED — AND THE ADVICE TO "READ BACK THE OPERATIONAL TIER" DOES NOT WORK ON A DPH-151
> On the DPH-151 the operational-tier attribute was **rejected in every form tried** (an error, or
> a zero maximum length); only the factory-tier name is accepted. The tier *model* may still be
> right about what the running client reads — but **you cannot verify it by reading that attribute
> back on this hardware.**

**CHECK — behaviourally, not by reading a tier.** Set what the device accepts, then ask the
question that actually matters: **does the gateway connection get attempted at all?** That is the
thing NTP gates, and it is observable. A tier read-back that errors tells you nothing either way.

And confirm the unit can actually *reach* the NTP server you gave it — on an isolated segment a
public address resolves fine and never syncs.

---

## 12. Searching firmware for a port number returns zero
**Measured on DPH-151 and DPH-153 images.**

**SYMPTOM.** You grep an extracted firmware image for `14677` to see whether the backdoor is
present. **Zero hits.** You conclude it was removed.

**MECHANISM.** **A port lives in code as a number, not as text.** It appears as an immediate
load of the byte-swapped value — on these MIPS images, `0x5539`, which is `htons(14677)`,
loaded at two sites. That is what a `bind()` looks like, not a hex coincidence.

**CHECK.** Search for the **byte-swapped hex immediate**, or disassemble around the socket
calls. And more generally: **for any zero that matters, run a positive control** — search for
something you *know* is in that image. If the control also returns zero, your instrument is
blind, not the world empty.

> ### ⚠️ AND IT FAILS THE OTHER WAY: A PORT NUMBER IS A SUBSTRING OF A BUFFER SIZE
> `13107` is a substring of `131072`. Someone was one sentence from publishing *"this binary
> references that port"* when the hit was a **buffer constant**.
> ⇒ ⭐ **A numeric token collides as readily as a common English fragment** — and this direction is
> the worse one, because **a large hit count discourages the control that a zero invites.**

⚠️ On this host specifically: the `grep` in an agent shell may be a wrapper that silently
skips gitignored paths. Use `/usr/bin/grep` by absolute path when a recursive zero is
load-bearing.

---

## 13. Don't kill the management daemon
**Measured on a DPH-151.**

**SYMPTOM.** You run a published "clean up these processes" list to get to a known state, and
the unit **reboots** — or your management channel dies mid-sequence and never returns.

**MECHANISM.** On this firmware one daemon owns the TR-069 session, the device data model
**and** the DMI action path. Killing it destroys the very channel you are configuring over.

**CHECK.** Don't. If you need a clean state, reboot the unit deliberately and wait out the
cold-boot window ([`BRINGUP.md`](BRINGUP.md) Phase 7) rather than killing processes.

---

## 14. Comfort noise is not a fault
**Measured on the core, repeatedly — this one fooled us five separate times in one night.**

**SYMPTOM.** An audio stream carries ~6 packets/second where you expect 50. It looks like
catastrophic loss.

**MECHANISM.** **AMR discontinuous transmission.** A silent talker emits one SID (comfort
noise) frame per 160 ms = 6.25/s. That *is* the expected rate for silence.

⚠️ **And the elimination that keeps failing:** *"it can't be DTX, this leg is PCMU and PCMU
has no DTX"* is **true about the codec and wrong about the flow** — a transcoding leg emits
one output packet per input frame, so it **inherits the source's DTX cadence while carrying a
codec that has none**.

> ### ⭐ THE MECHANICAL RULE: **a caveat that predicts a RANGE cannot explain a VALUE OUTSIDE IT.**
> Discontinuous transmission predicts roughly 6 packets/second of comfort noise. **It does not
> predict ZERO.** So *"that's just DTX"* is available for a low rate and **not** for an absolute
> zero — and an absolute zero from a peer that never answers is what an unroutable address looks
> like (trap 3). ⇒ **Check the number against the bound's own prediction before letting the bound
> explain it away.** ⚠️ A *true* caveat filters as effectively as a false one, and nothing will
> ever refute it.

**CHECK.** ⛔ A rate in packets/second discards the information you need. **Look at the
inter-arrival distribution**: a 20 ms mode is speech, a 160 ms mode is DTX, and a bimodal
distribution is a real speech/silence mixture. Count speech and SID frames **separately**.
And if you are testing unattended, remember a handset sitting in an empty room produces
**nothing but comfort noise** — such a call cannot contain the fault you are hunting.

---

## 15. The management data model and the running radio config are **different stores**
**Measured on a DPH-151. This one wasted an evening and it is the most surprising entry here.**

**SYMPTOM.** You set the PLMN over TR-069/CWMP. It stores. You read it back — **88 times** —
and it reads back correctly every time. **The cell still broadcasts the factory placeholder
MCC on the air.**

**MECHANISM.** The CWMP data model and the running radio configuration are **two separate
stores**. Writing the TR-069 parameter genuinely writes the TR-069 parameter. It does not
move the radio. **The DMI path is what moves what goes on the air.**

> ### ⭐ This is the whole reason to distrust a read-back that happens to succeed.
> Every instinct in this repo says *"read it back rather than trusting the write"* — and here
> the read-back **succeeds, repeatedly, from the store you wrote to**, while the thing you
> care about is unchanged. A read-back only proves the write landed *in the store you read*.

**CHECK.** Verify on the **air**, or via the store that actually feeds the radio:
- read the cell parameters through DMI (`uarfcnDownlink`, `scramblingCode`, the broadcast
  PLMN), **not** through the TR-069 tree;
- better, decode the broadcast from a handset's engineering/field-test screen.

> ### ✅ THE BETTER READ-BACK: ask the device what it last *kept*
> The management protocol binds a **`ParameterKey`** to the key of the most recent **successful**
> write. That is the device's own statement about what it recorded, rather than your server's
> statement that the request was accepted. **Pair every write with a `ParameterKey` read** — one
> extra round trip.
>
> ⚠️ **And a two-sided bound, because it was paid for:** a callee-side read-back is evidence
> **only if you can show the write actually executed first.** The one published case of this law
> catching a silently-ignored write was **withdrawn by its own author about twenty minutes later**
> — the "unchanged" samples came from sessions in which the queue ended before the write ran.
> **The law stands; that example evaporated.** A status code of 0 is the caller's optimism.

**RELATED, same shape:** the `csgIndicator` trap (#4) is this defect's twin — a stored value
that the broadcast ignores. **On this firmware family, "the config says X" is never evidence
that the air says X.**

---

## 16. Transmit power: setting one limit is not containment
**Measured on a DPH-151. ⚠️ Unresolved — published because it is unresolved.**

**SYMPTOM.** You set a transmit-power limit to its floor and assume the cell is contained.

**MECHANISM.** There is more than one power ceiling and they are not obviously ordered. On
our unit `maximumTotalWidebandTransmitPower` was `0` while `cpichTxPowerUpperLimit` remained
at its factory default. **Whether the total dominates the per-channel ceiling is explicitly
not established**, and our own runbook says all the limits are needed and **no one of them is
sufficient alone**.

**CHECK.** ⛔ We cannot give you a clean one, which is the point of publishing this. Set every
limit you can find, and **treat containment as a physical question** — enclosure, no external
antenna, distance — rather than a configuration one, until someone measures the interaction.

> ### 🔴 AND THE WAY THIS ACTUALLY GOES WRONG IS A UNIT ERROR, NOT A MISSING SETTING
> A power value here was once justified as *"matched to the other cell, not exceeding it."* Every
> individual clause of that sentence was true, and the result was **about 19.5 dB — roughly 90× —
> above where the reference cell actually runs**, on live licensed spectrum. Two errors compounded:
> ```
> it matched a HARDWARE CEILING against what was really an OPERATING SETTING
> and it used the OTHER device's ceiling -- this one's own is 6 dB lower
> ```
> ⇒ ⭐ **Self-review does not catch this, because nothing in the sentence is false.**
> ✅ **Name the DEVICE and the QUANTITY KIND in the same sentence as the number.** "A ceiling on
> unit A" and "a setting on unit B" are four different things and two of them are not comparable.
>
> ⚠️ **And you cannot read your way out of it: this device exposes NO attribute reporting actual
> radiated power.** Of 22 power-related attributes, only two are read-only and both report
> *capability*, not output. ⇒ Use the state pair as your check instead, and know what each one
> means: **`administrativeState` is what you ASKED FOR; `operationalState` is what you GOT.**

> ### ⭐ TWO THINGS THAT MAKE THIS SETTING PARTICULARLY HARD TO LEARN FROM
> - **The parameter is read at BOOT.** A change looks fine for an entire cycle before it bites.
>   ⇒ **A user who sets a value and sees the cell still up has learned nothing.**
> - **A value that never binds runs forever without incident.** One previous value ran 15.7 hours
>   cleanly *because it was inert* — it sat above the ceiling and never constrained anything.
>   ⇒ **"It has been set for months and was fine" is not evidence, if the value never bound.**

⚠️ **And a caution about the containment setting itself:** a two-hour outage here was blamed
on setting one of these to `0`, and that verdict was **retracted by its own author** once a
separately-measured hardware fault turned out to explain the same loop. **The floor value is
the one that actually constrains power and it is the one you want** — set it deliberately and
instrumented, not by discovery, and watch for the fault rather than avoiding the setting.

---

## 17. A config file that is a decoy — referenced everywhere, read by nothing
**Measured on ip.access firmware.**

**SYMPTOM.** You edit a config file at an obvious path. Nothing changes. The file is exported
as an environment variable **by the application's own start script**, and that variable is
live in the running process's `/proc/<pid>/environ`. It looks maximally load-bearing.

**MECHANISM.** The consuming binary has **zero** environment-access imports — no `getenv`, no
`environ`, no `setenv`, out of 349 dynamic imports, against a demonstrably-working reader as a
control. **It cannot consult that variable.** Both binaries reference their config by **bare
basename with no directory component**, so the open resolves against the process's **current
working directory** — and the entry there is itself a symlink into the live config bank.

```
<cwd>/<name>.cfg -> /var/ipaccess/config/<name>.cfg -> config_bank_N/<name>.cfg
```

The copy you edited is not on that path.

**CHECK.**
```sh
readlink -f <cwd>/<name>.cfg                       # follow the ACTUAL chain
ls -l /proc/<pid>/cwd                              # where a bare-basename open resolves
readelf --dyn-syms <binary> | grep -c getenv       # print the DENOMINATOR beside it
```
Two free corroborations that a copy is inert: its **mtime is stale** relative to the live
bank's, and **only one of the pair exists** — a designed defaults location would hold both, so
one-of-two is the signature of a stray copy. ⛔ **Do not "complete the set" by adding the
missing one.**

---

## 18. Persistence that is erased seconds after it is applied
**Measured on a DPH-151.**

**SYMPTOM.** A boot-time customisation is provably sourced at boot, and provably does not
survive. Both halves are true.

**MECHANISM.** The user hook runs from `/etc/profile`, **before** the `rcS.d/S*` scripts — and
the firewall init's `flush` is **unconditional and runs before its own enable check**. Anything
your hook added is destroyed seconds later, by design. Cron does not rescue it either: a
cron-added rule survives only until the next boot's flush.

**CHECK.** Follow the **sourcing chain**, not a grep for the filename. Grepping for the hook's
name returns three files and **every one of them is misleading on its own** — one is commented
out (with the vendor's reason beside it), one looks login-only, one deletes it. The live path
is indirect and the middle hop never names the file.

```sh
grep -n 'source\|flush' <every rcS.d script that runs after you>
```

✅ **The supported surface is the environment file the firewall script itself sources.** You
stop racing that script and become it.

⚠️ **Related, same device, easy to run reflexively:** `mount -o remount,ro /var/ipaccess` is
the next line in a published guide, and it **silently stops the reboot-cause log from
updating** — disabling the best post-mortem instrument on the box.

---

## 19. Two files in your "config backup" are live runtime state
**Measured on a DPH-151.**

**SYMPTOM.** You capture a config bank for restore purposes. Two of the files change **every
~16 seconds**. Restoring the set writes stale runtime state back over live state.

**CHECK.** Sample the whole bank's hashes three or four times, about 15 s apart, **with a
control**: the genuinely static files must be constant across the same samples, or your
"churn" is a capture artefact rather than a property of the files. Second tell: a `_bkup` copy
that **always equals** the primary is *tracking* it, not preserving an older good copy.

---

## 20. Two instruments agreeing is not corroboration
Not a device fault — the failure that produced several of the entries above.

**SYMPTOM.** You run two different checks, they agree, and you are confident. You are wrong.

**MECHANISM.** Two instruments only corroborate if their **failure modes differ in a way you
have named**. We once searched a config file two ways — one command had the right pattern and
a truncated output, the other had complete output and the wrong case — and **each alone would
have found the answer while the intersection was empty**. Agreement between two blind
instruments is indistinguishable from corroboration.

**CHECK.** Before trusting agreement, **say out loud how the two could each be wrong**. If you
cannot, you have run one instrument twice.

Two free corollaries:
- **A `head -N` that returns exactly N lines is a truncation warning**, and it is arithmetic
  on output you already have. Same for `tail`.
- **Print the denominator beside every count.** `0 hits` is a broken reader you cannot
  distinguish from a true zero; `0 hits / 165 keys parsed` is a finding.
- ⭐ **And the sharper version of the same rule, because it caught three people in one evening:**
  ***check whether your display limit became your answer.*** A `| head -14` read back as *"14 files"*
  understated a corpus-wide retraction rate by a factor of three — **in the finding that was ABOUT
  retraction detection, written by someone who had quoted "when you truncate, print the total" to
  two people within the hour.** ⇒ **Knowing the rule does not stop you being its instance;** the
  only thing that does is printing the total next to the sample.
- ⭐ **AND WHEN YOU CORRECT A COUNT, SAY WHICH KIND OF CORRECTION IT IS.** A figure that moves
  `14 → 39 → 45` reads as *"nobody can pin this down"*, and **the good number then inherits the
  distrust the wrong one earned.** ⇒ Here only the first was an **error** (a truncated read
  reported as a total); `39` and `45` are two valid **definitions** — *the first* retraction below
  a threshold, versus *any* — and they reconcile exactly, differing by the 6 files that warn you at
  the top and then retract something else 200 lines down.
  ⇒ ✅ **Label it: ERROR, or SHARPENED DEFINITION.** Without that, a series of corrections is
  indistinguishable from an unreliable measurement — and the last, best number is the one that
  gets discounted.

---

## 21. A cold boot takes about 16 minutes, and every check gave up sooner
**Measured on a DPH-151 across ten cold boots. Ranked first by cost.**

**SYMPTOM.** You pull the power, wait what feels like a generous amount of time, and conclude
the cell does not come back on its own. **It does.**

**MECHANISM.** Three serial delays, and only the first is variable:

```
~5 min   the core reaps the stale SCTP association from the unit's previous life
         (variable: 3m09s and 5m22s both observed)
~11 min  NAT state clears and the AP's SCTP INIT finally gets through
         (barely varies -- 43 s spread across two boots)
~16 min  the cell registers. Handsets follow within about a minute.
```

> ### ⭐ The failure was in the *observers*, not the device.
> A retry loop gave up at 9 minutes. An alarm fired at 10. One window check was 21 seconds
> early. **Three confident negatives, from two people, every one correct at the moment it was
> taken and every one early.**
>
> ⇒ **A well-controlled zero gives no signal that its window was too short.** Every other trap
> here is about an instrument that reads wrong; this one is about an instrument that reads
> *right* and is asked *too soon*.

**CHECK.** ⛔ **Do not call a cold boot failed before T+20 min.** Gate on the SCTP association
actually being established — read the kernel's association table, not a VTY command (trap 6).

⚠️ **SCTP state numbers differ per kernel.** The AP's 2.6-series kernel reports `4` for
ESTABLISHED; a modern kernel reports `3`. **Do not "fix" a check on one host using a value
read on the other.**

⚠️ **Quote both terms, never just the total.** If a boot ever runs long, it is the first
(variable) term that moved.

⚠️ **Honest counterweight, so this does not read as "just be patient":** two of the fixes made
during those ten boots were **genuinely necessary** and would have blocked a boot forever —
the bring-up was driving a console that never answers, and it never populated the RF candidate
list (trap 10). Everything after those two was impatience mistaken for failure. **Two failures
that look identical can need opposite responses**, so use the acceptance criteria in
[`BRINGUP.md`](BRINGUP.md) rather than a stopwatch alone.

---

## 22. Running the root tool twice does not confirm it worked
**Read from the tooling's own source. This one bites the *reader*, not the author.**

**SYMPTOM.** You run the root-acquisition tool. You are not sure it worked. You run it again to
check — and it reports success. **That success proves nothing about whether the technique
works.**

**MECHANISM.** The tool calls its `try_root()` check **before** it injects anything. So on the
second run, the check succeeds against **the residue of the first run** — an account or a key
that is still sitting there. What you have verified is the **persistence of the side effect**,
not the **method**.

> ### ⭐ And note which run is the dangerous one: **the second.** The first run you treat as
> ### uncertain; the second is the one you *trust*, and it is the one that cannot fail.
> Same family as trap 15 (a store that reads back correctly while the air never changes) and,
> for that matter, as a publication gate that excludes itself from its own scan: **the check is
> structurally unable to observe the thing it is being asked about.**

**CHECK.** Verify root by its **effect on a fresh, unprivileged path**, not by re-running the
acquisition:
- log in over your **own** newly-installed key, from a clean session;
- confirm a privileged read that has nothing to do with the tool.

⇒ **To test the *method* rather than the residue, you must first remove the residue** — undo
the injected account or key, then run once. Otherwise you are testing persistence, and
persistence is not what you wanted to know.
---

## 23. The reboot log names the wrong process — structurally, every time
**Read from vendor code on a DPH-151.**

> *You arrive thinking: "the box says this process crashed, so that's what I'll go fix."*

**SYMPTOM.** The device's reboot history consistently blames **one** process. You go and debug it.

**MECHANISM — three separate defects in one small file, and all three flatter the record:**

1. **Last writer wins.** The supervisor polls *all* monitored PIDs each cycle with **no `break`**,
   and assigns the crashed-app name **unconditionally**. If two processes are dead at one poll,
   the record names **whichever is last in the monitored list** — even if the real casualty died
   minutes earlier.
2. **The uptime field is left-censored at 300 s.** The reboot routine busy-waits until *system*
   uptime reaches 300 and then records whatever it last read. **A death at 20 s, at 165 s and at
   299 s all write ~300.** The field carries no information below the threshold. ⇒ A tight
   cluster at ~300 is **a clamp in vendor code, not a property of the world**.
3. **A non-clean reboot writes a literal `0`.** The clean path records a real uptime; some cause
   codes hardcode `0`. So `uptime = 0` looks like a device dying instantly at boot and means
   nothing at all.

⭐ **And the 300 s is a DELAY, not an exclusion** — an early crash is *deferred* to ~300 s, while
a late crash reboots almost immediately. **Same code, two behaviours, selected by uptime at the
moment of the crash.**

**CHECK.**
- **Use the core dumps, not the log.** The core-copy step runs **per dead PID**, so it is
  unbiased. Presence is strong evidence. ⚠️ Absence is weak — a purge runs first.
- Read `uptime` **only alongside the cause code**, and treat any ~300–307 value as censored.
- ⛔ **Do not sort the history by timestamp.** It is built by *prepend*, so file order **is**
  insertion order, newest first. Its timestamps come from another file's mtime and read 1970 or
  a stale year when the clock is unset.
- ⚠️ If the partition has been remounted read-only, the history is **frozen** and you are reading
  pre-remount records.

> ### ⚠️ A related trap in the same subsystem: **a shared identifier is not shared behaviour.**
> An audit found **six** files that trigger a reboot, not the five usually listed. One has its
> **own** copy of a same-named reboot function with **no delay floor and no environment check** —
> it reboots immediately. The auditor had read the function in one script, found the 300 s floor,
> and carried that property to a **different file with the same function name**.
> ✅ `grep -rl '/sbin/reboot'` across the filesystem **and print the count.**

---

## 24. Your TLS server is too modern to talk to it
**Read from the device's own linked libraries.**

> *You arrive thinking: "it connects and immediately gives up — it must be rejecting my certificate."*

**SYMPTOM.** You stand up your own management server. The device connects and the session dies
instantly. It looks exactly like your certificate being refused.

**MECHANISM.** The device's client stack is **OpenSSL 0.9.8h (2008)**. Its exported symbols carry
SSLv2/SSLv3/TLSv1 client methods **only** — 0.9.8 predates TLS 1.1 and 1.2 entirely. **Your
server must offer TLS 1.0**, and every modern TLS stack disables TLS 1.0 and its ciphers by
default. A TLS-1.2-only server produces a handshake failure indistinguishable from rejection.

**CHECK.** Before diagnosing anything device-side, **prove your own server offers TLS 1.0** and a
period-appropriate CBC cipher suite. A successful session negotiates TLS 1.0.

⚠️ **And the device may FIN on you even after a clean handshake.** In one measured run, **73 of 73**
sessions ended with the *device* closing — a completed mutual-TLS handshake, a valid client
certificate presented, then a clean FIN in about 20 ms with **zero application bytes**. Two
different handlers and two different server certificates gave identical results, which rules out
"wrong handler". ⇒ **That is a post-handshake, pre-application decision on the device side, not
your server closing early.** Your own server log already answers who closed: a `recv()` returning
empty is a clean FIN.

> ### ⚠️ AND YOUR PROBE LIES THE SAME WAY
> `openssl s_client` will tell you **"no peer certificate available"** — and that is *your client*,
> not the server. Modern OpenSSL's default security level refuses this era's parameters and closes
> **before** the certificate is shown. `-cipher 'ALL:@SECLEVEL=0'` returns it immediately.
> ⇒ ⭐ **A client-side policy rejection and a server that serves nothing are indistinguishable in
> that output** — and the wrong reading sends you to fix a working service.

⚠️ **The device also sends no TLS SNI**, so name-based virtual hosting cannot work on a single
address. If you host more than one service, you need more than one address — and until you do,
**every connection is handled by whichever service that address defaults to.**

> ### ⭐ Instrument note worth more than the finding: **`strings` is not a symbol table.**
> `strings` reported the TLS 1.0 client method **absent** while `nm -D` found it present. The
> author was one step from publishing "no TLS 1.0 support", which is the opposite of the truth.

---

## 25. It registers, de-registers ~15 seconds later, and it is **not** the famous bug
**Measured on a DPH-151.**

> *You arrive thinking: "it drops after about fifteen seconds — that's the wildcard-bind bug from the forum."*

**SYMPTOM.** The cell completes HNBAP registration, the core accepts it, and roughly **15 seconds
later** the device de-registers itself and shuts down gracefully.

**MECHANISM.** It registered carrying **uninitialised placeholder cell identity** — an all-zero
PLMN, a sentinel location area, a sentinel service area. With no valid radio configuration it
registers with sentinels and then stands down when the radio cannot come up. **This is trap 10
wearing a timer's clothes.**

> ### 🔴 It is NOT the wildcard-bind / SCTP path-failure fault, whose published symptom is the
> ### same 10–20 second window. Four discriminators, any one of which settles it:
> ```
> SCTP aborts = 0            a path failure ABORTS; this shut down gracefully
> INIT-ACK advertises no extra address parameters   -> not multi-homing at all
> the exit is an application PDU with an explicit Cause, not a timeout
> it follows that PDU by ~1.4 ms -- causally tied to a decision, not to a timer
> ```

> ### ⭐ AND THE UNDERLYING CAUSE HAS NOW BEEN TRACED, ON A DPH-151 IMAGE
> **The normal-mode boot script never programs the radio processor's array.** The vendor inlined
> the array-init body into the *diagnostic* mode scripts and **not** into the normal one. Every
> link was re-verified:
> ```
> no array image loaded
>   -> DMA open fails with an invalid-argument error
>   -> the router process cannot open the radio control plane
>   -> the control app takes its fatal path
>   -> its socket dies, the registry lookup returns empty
>   -> HNB-Deregister, cause radioNetwork, ~15 s after a successful register
> ```
> ⭐ **Nothing is missing from the device.** The array image and its loader are both **present** —
> the step is simply never executed in normal mode. ⇒ **A file-presence check reports everything
> fine.**
>
> **How to see it:** the boot-script directory holds ~26 links and **none** references the array
> initialiser — control: the same sweep *does* find the mode script, so it is not blind.
> ⚠️ Booting a diagnostic mode proves the DMA *can* open. **That is a diagnostic, not a fix.**

**CHECK — free, and it needs no VTY or management read at all.** Watch the registration message
for **real PLMN / location / service area values**. One decoded field proves your configuration
survived to the radio. Sentinels there mean trap 10, not a network problem.

---

## 26. An error string names what the code **tried** to do, not what happened
**Read at instruction level from vendor binaries.**

> *You arrive thinking: "it says it received 16 bytes and choked — I have a framing bug."*

**SYMPTOM.** A log line names a byte count and looks like a parser complaining about a malformed
frame.

**MECHANISM.** The number is a **compile-time constant** — the *length argument* of a `recv()`
that returned **≤ 0**. The instruction sequence loads the constant, calls `recv`, compares the
result against zero and branches to the error. **No received length is ever compared to anything
on that path.** Its sibling message about incomplete data is the same shape. **Both are
connection-loss handlers, not parser errors.**

**CHECK.** `recv() == 0` is an **orderly peer close**. Ask **which peer hung up, and when** —
not what malformed frame arrived. Those are opposite investigations.

⚠️ The branch covers both `0` and negative returns, so **the binary itself cannot distinguish an
orderly close from a socket error.** Neither can you, from that line.

---

## 27. A config value carries a trailing newline onto the wire
**Read from a vendor binary's imports, and observed in a DNS query.**

> *You arrive thinking: "the hostname looks right in the file but the lookup fails."*

**SYMPTOM.** A value you set in a config file is visibly correct, and the device behaves as though
it is wrong.

**MECHANISM.** One vendor binary reads its config with `fgets` and imports **no newline-stripping
function at all** — the usual candidates are absent from its symbol table, and the one string
function it does import is used for field separators. ⇒ **The last comma-separated element of any
list value carries the line's `\n`**, because it has no trailing comma and runs to the buffer end
that `fgets` filled. It reached a live DNS query as a name with a trailing newline.

**CHECK.** ⛔ **`od -c` the value, never `cat`.** `cat` renders a trailing newline invisible, which
is exactly how this survived all the way to the wire. The device also self-instruments it: it logs
a name and a length per entry, and the buggy final element logs **length = visible length + 1**.

⚠️ **A sibling binary in the same firmware DOES strip the newline.** Parsing rules differ per
binary, so testing one proves nothing about another.

---

## 28. The operator's hostnames still resolve, and nothing is behind them
**Measured, with passing positive controls.**

> *You arrive thinking: "the name resolves, so the service is up and my redirect isn't working."*

**SYMPTOM.** You point the device at your own infrastructure, it does not take, and you check the
operator's names — they resolve fine. So your redirect must be broken.

**MECHANISM.** Decommissioned services behind **live DNS records**. Of eleven operator service
names, ten still resolved and **nothing answered** on any management or time port.

⭐ **Time service is the strongest single signal**: it is the first step of the documented boot
order and it is **unauthenticated**, so its silence cannot be explained away as credential-gating.

> ### 🔴 AND THE INSTRUMENT THAT MAKES THIS WORK IS THE ONE THAT HIDES IT
> If you have set up a wildcard DNS answer for the operator's domain — which is how you redirect
> the device in the first place — **your own resolver answers every name under it, including
> names that are malformed or that never existed.** Anything your workaround covers stops
> reporting.
>
> ✅ **Query past your own fix**: use an explicit public resolver, and **include a name you know
> should not exist** so you can see what a real negative looks like.

⚠️ **`open|filtered` from a UDP scan is not evidence of life** — it means *no reply*. And a UDP
scan silently needs root; one run returned nothing at all, including for a known-open control.

---

## 29. A file's timestamp is not a timestamp on a device with no clock
**Corrected from our own notes — the law survived, the mechanism under it did not.**

> *You arrive thinking: "this file is older than the boot, so it's left over from last time."*

**SYMPTOM.** You want to know whether a file on the device is fresh or stale. You compare its
mtime against boot time.

**MECHANISM.** These devices have **no battery-backed clock**. The clock starts at an epoch
default and then **jumps discontinuously** when time sync succeeds. So a file written *before*
sync carries a timestamp that "predates the boot" **while being completely fresh** — the mtime and
any current clock reading come from two different time bases on one machine.

> ### ⭐ THE LAW ABOVE IT, WHICH IS THE PART WORTH KEEPING:
> **A positive control validates READABILITY, not CURRENCY.** It proves the file is present and
> non-empty. It can never prove the file is about *now*. We built a freshness gate on exactly this
> confusion, and on a RAM-backed file the gate can only fire on a clock artefact — rejecting
> **fresh** data as stale.

**CHECK — do not use the clock at all.**
- **Compare a PID recorded inside the file against the live process table.** A match proves
  current-boot provenance outright, with no timestamps involved.
- To settle whether a path even survives a reboot, use `mount` — it needs no write and no marker
  file. ⚠️ On our unit `/tmp` is **tmpfs**, so nothing there survives; a file that appears to have
  done so is telling you about the clock, not about storage.

---

## 30. `--help` is an action
**Measured across a fleet of device-facing scripts.**

> *You arrive thinking: "I'll just run it with --help and see what it does."*

**SYMPTOM.** You run an unfamiliar device-side script with `--help` to find out what it is. **It
runs.**

**MECHANISM.** A shell script with no argument parsing does not print help — it **executes**. In
one audited set, a majority of device-facing scripts had no help text at all, one placed its help
handling at line 59 of 61 (after 58 lines had already run), and one had **no shebang, no header,
and fired three state-changing management actions at a live cell.**

**CHECK.** ⛔ **Never probe an unknown script by running it.** Read it — `head -40` costs nothing.
✅ And when deciding which tools are safe to run, use an **allowlist of provably-inert ones**,
never a blocklist: a detector that misses things shrinks an allowlist **toward safety** and
inflates a blocklist **toward danger**.
---

# ☠️ ONE-WAY DOORS

**These four can leave you with no way back in, or put a transmitter on the air. They are not
"traps" in the debugging sense — read them before you act, not after.**

## 31. Booting the other firmware bank can remove every way back in, and it is sticky
**Measured on a DPH-151's own flash.**

> *You arrive thinking: "I'll boot the other bank, it's the same box."*

**SYMPTOM.** The bank switch succeeds. The device boots. **You have no login and no recovery
channel.**

**MECHANISM.** The two banks are **not two copies of one system**. On the unit measured, the older
bank's `/etc/passwd` carries **two uid-0 logins** and the newer carries **a single unprivileged
account** — no root at all. The vendor's undocumented entry path present in the older bank's helper
binary is **absent** from the newer one. And the bank selection is written to the **persistent boot
environment**, so it does not revert on its own.

⇒ **Every route in can be on the bank you are leaving.**

**CHECK — before you switch, not after:**
```sh
# unpack BOTH banks and compare what can log in
grep ':0:' <bankA>/etc/passwd  ;  grep ':0:' <bankB>/etc/passwd
```
And grep both helper binaries for whatever entry path you rely on, **with a positive control on a
string you know is in both** — the original check used the binary's own name (15 hits vs 16), so
the search was demonstrably not blind.

⛔ **We are deliberately not describing the vendor entry path itself.** What matters here is that
it exists in one bank and not the other.

---

## 32. Unpacking the firmware overwrites **your** filesystem
**Measured. Only a permission error stopped it.**

> *You arrive thinking: "cpio extracted nothing — zero files."*

**SYMPTOM.** You extract the initramfs, your output directory is **empty**, and `cpio` complains
about `/sys`.

**MECHANISM.** The archive stores **absolute paths**. A plain `cpio -idm` therefore extracts to the
real `/` — and as root that unpacks a 2011 root filesystem **over your host**. The empty output
directory is not a failed extraction; it is the extraction going somewhere else.

**CHECK / FIX.**
```sh
cpio -idm --no-absolute-filenames < initramfs.cpio     # MANDATORY
```
> ### ⭐ **THE LOUD ERROR IS THE ANSWER.** The first attempt hid it with `--quiet` and
> ### `2>/dev/null`, which turned *"I am writing to your root filesystem and was denied"* into
> ### *"0 files"* — indistinguishable from an empty archive.
> Never silence stderr on an extraction. The permission denial was the only thing that saved the
> host, and the redirect nearly threw it away.

---

## 33. Correcting the PLMN silently removes a safety interlock
**Measured.**

> *You arrive thinking: "I fixed the PLMN — that's just good hygiene."*

**SYMPTOM.** **None.** Everyone, including you, files the change as an improvement.

**MECHANISM.** Bring-up gates are checked in sequence. While the unit still held the previous
operator's PLMN, **that wrong value was itself preventing transmission** — two barriers stood
between the device and radiating. Correcting it removes one, and **nobody chose to remove it**.

⚠️ **And something may already be trying to clear the last one.** A pre-existing entry was found
sitting in a management queue that wrote the **admin-enable and service-enable** parameters on
*every* session — inherited configuration, not authored by the current owner.

**CHECK, before correcting the PLMN:**
1. **Enumerate what else is holding the radio down.** Know how many barriers you have, not just
   that you have some.
2. **Dump your management server's pending queue.** You may be one session away from radiating.
3. ✅ **Implement the refusal at the TOOL level** — a hard block on sending the admin-state,
   service-enable, RF-transmit, transmit-power, UARFCN and scrambling-code parameter names.
   **Removing one queue entry fixes an instance; a refusal in the tool fixes the class.**

---

## 34. A used unit carries the previous operator's PLMN, and your core will not stop it
**Measured live on a used unit.**

> *You arrive thinking: "my core only knows my test PLMN, so it can't broadcast anything else."*

**SYMPTOM.** Nothing rejects it. The cell registers and is accepted.

**MECHANISM.** **The safety-critical identity lives on the radio unit, not in your core.**
`osmo-hnbgw` runs an accept-all policy and **copies the HNB identity verbatim without validating
it**. A femtocell still holding a real carrier's MCC/MNC will register happily, and the device
holds that value across a `default / local / lkg / active` precedence stack.

**CHECK.** Read the PLMN **off the device**, and confirm the **`InUse` sibling** read-back — the
data model provides one on every settable RF parameter for exactly this purpose. Do it **before**
anything enables RF, never from a bare echo of what you just set, and never in the same unverified
batch as the write.

> ### ⚠️ And "nothing attached" is not a safe outcome. It is an impersonation that also failed.

⭐ **A useful provenance check:** if your unit still shows the factory **placeholder** PLMN and
placeholder gateway hostnames, it was never fully provisioned by an operator — which cuts against
it carrying live operator configuration at all.

---

# More traps

## 35. A write that reads back as `0` may have been **consumed**, not lost
**Measured.**

> *You arrive thinking: "I set it, read it back, it's still zero."*

**MECHANISM.** At least one service-enable parameter is a **one-shot edge, not a state**. Writing
`1` arms a byte that a dispatch loop consumes exactly once and clears. So an immediate read-back of
`0` is **indistinguishable** from "the write never took".

⚠️ **Edge vs state is not derivable from the attribute namespace** — the same vendor-private range
holds obvious verbs and obvious nouns. There is no mechanical classifier. The test is empirical.

**CHECK — the three-read protocol:**
```
R1  immediately, same session      R1=0            -> a CONSUMED EDGE
R2  later, same session            R1=R2=R3=V      -> persisted
R3  after a reboot                 R1=R2=V, R3=old -> RAM only
                                   RPC fault       -> rejected
```
> ### ⭐ **`R1` is the read nobody runs**, because the instinct is write → reboot → check.

⛔ **Calibrate on an inert parameter** — a heartbeat interval, a log-upload flag. **Never on the
radio-enable, and never on the PLMN.**

---

## 36. The management console is mute while the management path works fine
**Measured. And it is the exact OPPOSITE of trap 7.**

> *You arrive thinking: "the console accepts my connection and never replies."*

**MECHANISM — four separable causes, and you can split them for free:**

- **Telnet option negotiation.** The daemon sends `IAC DO LINEMODE` on connect. A raw `nc` that
  never answers it **never gets a prompt**, and every command times out.
- **Launch environment.** The vendor launcher sets **no library path at all**; the client inherits
  it from whoever invokes it. ⭐ **Invariance across 26 restarts is the *signature* of a launch
  defect, not evidence against one** — started the same wrong way 26 times, crippled identically
  26 times. Discriminator: a healthy start prints exactly **six** task-creation lines and
  "Completed initialisation". Fewer means half-initialised.
- **Single-client collision.** A collided session returns an empty banner, indistinguishable from
  "attribute not supported".
- **Free split: did a prompt ever arrive?** No prompt ⇒ negotiation. Prompt but no result ⇒
  launch or downstream.

> ### 🔴 **THIS CONSOLE INVERTS THE VTY RULE IN TRAP 7, AND CARRYING IT ACROSS TRIPS TWO OF THE
> ### FOUR CAUSES AT ONCE.**
> ```
> Osmocom VTY (trap 7):  a trailing `exit` BLINDS you -- the polite close is the broken one
> this console:          you MUST send `quit` and read to EOF -- dropping the TCP connection
>                        WEDGES it for ~60 s, and Ctrl-C kills it until reboot
> ```
> **Two consoles, opposite etiquette, one project.** A rule learned on one is a hazard on the other.

⚠️ **The console may not exist at all on your firmware.** It is a *commissioning* mode you invoke,
and the vendor's own boot path uses the one-shot client instead. **Its absence from the process
list is normal**, not a fault.

---

## 37. One bad attribute name aborts the whole batch — and a real name from the wrong namespace reads as correct
**Measured.**

> *You arrive thinking: "the device rejected my whole query, so my transport is broken."*

**MECHANISM.** A batch read aborts **entirely** on a single invalid name, so one wrong entry makes
every valid one in the batch look absent. Worse: **the spec-correct name is often from a different
namespace than the device's own table.** Four measured instances:

| you reach for | reality |
|---|---|
| the standards-body name for the scrambling code | exists in the standard, **absent** from the device's table, which uses a shorter form |
| `MaxFAPTxPower` | **CDMA2000-only.** UMTS uses `MaxFAPTxPowerExpanded`. Querying the wrong one returns a fault that reads as *"no TX power control exposed"* — false, **and it is the power cap** |
| `UARFCNUL` | not in the UMTS RF object at all; only an `…InUse` read-back exists. The uplink is **derived** from the downlink by duplex offset. Planning to set it is planning a fault |
| the address attribute in the vendor's own example script | it is the **read-only** 16-byte tunnel address, not the writable 260-byte gateway one. ⭐ **The field widths confirm the roles independently of the names** |

**CHECK.** Read the device's own attribute table first (one grep), and **enumerate the tree** rather
than guessing names. ⭐ A read on a non-existent parameter returns a **fault, not silence** — so a
fault on one name plus a value on another is a **clean positive**, not an ambiguous zero.

⚠️ **And check both shapes of the data model.** The standard split by technology between issues, so
the admin-state and RF-transmit paths are **flat** in one issue and carry an extra technology
segment in the other. A tool aimed at one shape gets empty faults from the other and reads it as
*"no RF control exposed"* — **which lands directly on a safeguard.**

---

## 38. The device offers exactly one IKE proposal, and a modern responder refuses it
**Measured off the wire.**

> *You arrive thinking: "my IPsec responder never gets past the first exchange."*

**MECHANISM.** It is **IKEv2**, and it offers a **single proposal with no alternatives**:
AES-CBC-128, HMAC-SHA1-96, PRF-HMAC-SHA1, **DH group 2 (MODP-1024)**. Modern strongSwan does not
offer group 2 by default, so a default install answers `NO_PROPOSAL_CHOSEN`.

**CHECK / FIX.** Explicitly enable `aes128-sha1-modp1024` on your responder. ⭐ **One packet is
enough to confirm** — every retransmission is byte-identical, so the capture needs no lucky timing.

⚠️ **Counting trap: three packets is ONE attempt retransmitted** (same SPI, same nonce). Counting
packets as attempts inflates the retry rate threefold.
⚠️ **Method note worth more than the finding:** the packet *size* was used to guess the IKE version
and was consistent with **both** candidates. ***A number consistent with both hypotheses is not weak
evidence for one — it is no evidence.***

---

## 39. Standing up your own security gateway can take down your LAN, including your own shell
**Measured; the routing numbers are documented defaults, not read off that build.**

> *You arrive thinking: "I added an IPsec responder and lost the box."*

**MECHANISM.** The device proposes a **very broad traffic selector**. As responder, its selector
becomes your *local* side, which is harmless — but a broad **remote** selector, or routes installed
into strongSwan's policy routing table at its default rule priority, **outranks your main routing
table** and takes the LAN with it, including your management path.

**CHECK — before you install:**
```sh
ip rule        # nothing below 32766 means a new priority-220 rule will SHADOW main
```
- **Pin the remote selector to the device's virtual IP as a `/32`.** Never mirrored, never `0/0`.
- **Take the virtual-IP pool from the free RFC1918 block the device asks for**, never from your own
  LAN subnet — otherwise you get an ARP collision on your own network.

> ### ⚠️ `apt install strongswan` **starts the daemon.** Installing is not a read.
> The packaging enables *and* starts the unit and loads all configuration, so it binds the IKE
> ports immediately on a production host. ✅ Order: **mask → install → write config → review the
> policy intent → unmask → start.**

⚠️ Two companions that will waste an afternoon: the daemon ships **AppArmor-confined**, so key
material outside the packaged paths produces denials that `ls -l` flatly contradicts (see trap 20's
family); and **reverse-path filtering must be loose** — strict mode drops decapsulated packets, so
a generic "harden your host" guide is actively wrong here.

---

## 40. `openssl x509 -in <file>` reads only the FIRST certificate in a bundle, silently
**Measured across 44 PEM files.**

> *You arrive thinking: "none of these certificates is a root."*

**MECHANISM.** A sweep reported every certificate as an intermediate or leaf. **Two files held two
certificates each**, and the second certificate in those two bundles was **the only self-signed
root in the entire image**.

**CHECK.** Count `BEGIN CERTIFICATE` **per file** before trusting any per-file certificate summary.

> ### ⭐ **A count of FILES is not a count of CERTIFICATES, and nothing in the output says so.**

---

## 41. Opening the case can destroy a factory configuration
**Measured on a DPH-151.**

> *You arrive thinking: "I'm about to open this thing up."*

**MECHANISM.** A 2×6 header carried **five jumpers tethered to the lid**. Opening the case lifts
all five at once, and their positions are gone. Five of six columns jumpered reads as a **deliberate
factory configuration**, not a debug header — **the device may not boot correctly until they are
restored.**

> ### ☠️ AND THE DANGEROUS MOVE IS PUTTING THEM **BACK**. THIS IS A ONE-WAY DOOR.
> **Do not guess the pattern. Leave them off.**
>
> The firmware's tamper reader treats **all-pins-open as an explicitly excluded pattern** — it is
> dropped as *invalid* and counted separately, and **it does not trip the latch**. But a
> **guessed** pattern is *valid-looking*: it passes the validity gate, **mismatches the stored
> word**, and after three consecutive reads **commits a tampered flag to flash. Permanently.**
>
> ```
> no jumpers fitted   -> reads as the excluded pattern -> dropped as invalid -> SAFE
> a GUESSED pattern   -> passes validity -> mismatch -> x3 -> tampered=1 in flash, ONE-WAY
> ```
> ⇒ **Restoring them from memory is strictly more dangerous than leaving them off.**
> ⛔ **And do not run the vendor's tamper-clear command** — it is destructive.

**CHECK.** ⭐ **Photograph the board before the lid is fully clear**, at an angle showing which
columns are bridged — that is the only way to restore them *knowing* rather than guessing. **If you
did not photograph it, leave them off.**

⚠️ The jumpers coming away **with the housing** is itself the argument that this is
tamper-**evidence**, not tamper-**response** — a response mechanism would use a microswitch.
⚠️ **BOUND, in the sentence: this was measured on a sibling model's gateway processor, and is a
strong sibling mechanism rather than a measurement of your unit.** It is published because the
failure is irreversible and the safe action costs nothing.

---

## 42. Restart-shaped events with no explanation: check the barrel jack before the protocol
**Measured, with the case open, after three people had spent effort on protocol explanations.**

> *You arrive thinking: "it reboots at random and nothing in the logs explains it."*

**MECHANISM.** A **loose power jack.** Irregular intervals, no cadence, nothing network-visible.

> ### ⚠️ AND THE EXPENSIVE HALF: **the subject may not have been continuously powered during any
> ### earlier measurement.** Instruments had been audited exhaustively; **power continuity never
> ### was.** Every conclusion drawn across that period inherited it.

⛔ **But it does not absorb every neighbouring mystery** — it did not explain an eight-minute window
in which the device was demonstrably up and polling. ⭐ **A mundane cause arriving late wants to
swallow the anomaly next to it.** Resist that.

⚠️ **Competing software candidate, same signature:** the vendor watchdog restarts supervised daemons
on death and **reboots the box** on repeated death, so a crash→restart→reboot loop looks identical
from outside.

---

## 43. Crash files: zero-byte means healthy, and old ones are not yours
**Measured.**

> *You arrive thinking: "there are crash files, so it's crashing."*

**MECHANISM.** A **zero-length** staging file is created at process **start**. It is the signature
of a **healthy** process, not of a crash. And on used hardware the crash directory holds **the
previous operator's dumps from years earlier**, sitting alongside yours.

> ### ⭐ AND MOST OF WHAT IS IN THERE IS THE PREVIOUS OWNER'S
> On one audited unit **15 of 24** application dumps dated from the carrier era, a decade before
> the current owner. The persistent reboot history held **235 entries over 15 years — two of them
> the current owner's.**
> ⇒ **The same firmware crashed the same way on the carrier's own production network. Nothing you
> did introduced it.**
>
> ### ⚠️ AND THERE ARE **TWO** REBOOT HISTORIES. The one you find first is the RAM copy.
> ```
> the RAM copy      ~21 entries        <- what you will find first
> the flash copy   ~235 entries        <- 1/11th of the record is what you were reading
> ```
> ⛔ **Do not sort either one** — it is reverse-chronological already, and its timestamps come
> from a clock that may not have been set (trap 29).

**CHECK.** Scope every read of that directory **by mtime**. A hit in a decade-old dump says nothing
about you, and two sets coexist. An earlier reading of ours concluded "it is crashing" from exactly
this and was **retracted by its own author**.

---

## 44. A boot-time config script that runs and does nothing
**Measured.**

> *You arrive thinking: "my boot script is there, it runs, and nothing changes."*

**MECHANISM.** The vendor boot path executes a management script from the persistent partition at
every boot — and **two independent conditions disable it silently**:
1. a single **auto-generated marker comment** in the file causes the whole path to be skipped;
2. on one firmware-variant family the init script **comments out every `set` line** before running
   it. ⚠️ On the unit measured this second guard is a **no-op** — the vendor scoped it deliberately
   to a different variant.

**CHECK.** Grep the file for the auto-generated marker, and check your filesystem-variant prefix
against the guard's condition.

⛔ **And treat authoring one as a one-way door:** a boot-time script issuing writes runs **before
anyone can intervene** and re-applies itself every cycle. **Review it attribute by attribute against
the device's own name map before the file exists.**

✅ **One durability note that cuts the other way:** that file is **not** in the post-download
deletion list, so it survives the one trigger that wipes every other config file (trap 2).

---

## 45. You may not need a security gateway at all
**Measured: the audited unit reached full service with none.**

> *You arrive thinking: "I have to stand up an IPsec gateway before any of this works."*

**SYMPTOM.** You budget days for a security gateway because every description of the boot order
puts IPsec before everything else.

**MECHANISM.** The firmware carries an **"IPsec is not supported" branch** that is a *supported*
no-tunnel path straight to the management server, with a named switch controlling it. ⭐ **And the
gate is a string compare against the literal `"0.0.0.0"`** — an **unprovisioned gateway address**,
not a locked device. It is re-evaluated on config commit, **so no reboot is needed.**

The unit these notes come from **served four subscribers with no security gateway at all.**

**CHECK.** Before building anything: read the gateway address the device currently holds. If it is
the unset sentinel, you are already on the no-tunnel path.

⚠️ **BOUNDS, and they are real:** which branch a given unit takes is **not established**; the
gateway address must move in the same change; and **enabling the switch needs write access to the
device**, which may be the thing you do not yet have.

🔒 We report only that the path exists. Nothing here is about constructing a gateway.

---

## 46. A second cell on the same PLMN **removes** service instead of adding it
**Measured: bringing up a second unit took down two working handsets.**

> *You arrive thinking: "I'll bring the second unit up alongside the working one and compare them."*

**MECHANISM.** **A cell that broadcasts but cannot serve is worse than no cell.** Handsets choose
on signal strength, not on whether the cell works — so they migrate to the new one and then fail.
Distinct cell identities prevent an identity *collision*; they do **not** prevent *reselection*.

**CHECK — and the instrument is not the one you would reach for.**
- **Watch the INCUMBENT's subscriber list**, sampled before and after every step. Not the new
  cell's attributes. *"The new cell registered"* is the success signal; **"a handset migrated" is
  the failure signal, and nothing watches for it by default.**
- **Identify the off-switch before you touch the on-switch.** The RF admin-state lock is the
  correct kill. ⛔ **Do not tear down the Iuh association** — it is harmless and worth keeping for
  diagnosis.

---

## 47. Working on the device changes the device
**Measured on a DPH-151.**

> *You arrive thinking: "it keeps rebooting while I'm looking at it."*

**MECHANISM.** This is a **138 BogoMIPS ARM with about 2.5 MB of free RAM and no swap.** Concurrent
SSH sessions, a `/proc`-wide file-descriptor walk (~65 s), and a recursive `grep -r` over the
compressed root filesystem all preceded the instability — and the longest stable stretch began when
they stopped.

> ### ⇒ 🔴 **A LOAD-INDUCED REBOOT IS INDISTINGUISHABLE FROM A FAULT-INDUCED ONE.**
> ⚠️ Its own author bounds it honestly: *"neither is established."* But it means **you must not
> pool observations taken under load with quiet-box ones** — date-stamp the moment you stopped
> poking it.

**Three concrete limits worth knowing before you plan anything:**

| you want to | reality |
|---|---|
| `grep -r` over the vendor tree | **kills your SSH connection** |
| write a capture to the device | **the root filesystem is 100% full, 0 bytes available.** `/tmp` is a 15 MB RAM disk on a box with ~2.5 MB free; another temp path is a **separate 512 KB** RAM disk; the flash is ~3.5 MB |
| run a long one-liner over SSH | **the SSH daemon silently rejects commands over roughly 900 characters** — measured OK at 900, broken pipe at 1500. The error reads like a permissions problem (`exec request failed on channel 0`) |

> ### ⚠️ AND THAT LAST ERROR HAS **TWO** CAUSES, WHICH IS WHY IT MISLEADS
> ```
> exec request failed on channel 0
>    cause 1   your command is over ~900 characters
>    cause 2   you are opening the Nth concurrent SSH session -- dropbear refuses it
> ```
> ⭐ **Its own source note is the point: it "reads exactly like a dead device."** So a reader who
> knows only cause 1 shortens a command that was never too long, and a reader who knows neither
> concludes the unit has died.
>
> ✅ **Discriminate for free: close your other sessions and retry the SAME command.** Works ⇒ cause
> 2. Still fails ⇒ shorten it. ⭐ And if you script against this box, **gate on a positive banner
> from the command you ran** — a refused session must never be recordable as a device-down.

✅ **FIX for captures: stream over SSH stdout** (`tcpdump -s 0 -U -w -`). Zero filesystem writes,
no race against a reboot, and no truncated-copy hazard.
✅ **FIX for long commands: put the loop logic on your workstation**, not on the device.

---

## 48. Your cell will not radiate and the reason mentions GPS
**Read from vendor code on a donor DPH-151 rootfs. ⚠️ Our own unit's flash is unread.**

> *You arrive thinking: "the service-disable reason says GPS, so the receiver is broken — or I need
> to get this thing near a window."*

**SYMPTOM.** The cell will not bring the radio up, and the reason the management layer reports names
GPS.

**MECHANISM — and it is an infrastructure absence, not a fault in your unit.** The vendor's
service-disable vocabulary is a **closed, validated set** (a string-compare chain that returns an
error for anything unrecognised, so it is the *accepted input set* rather than a sample of strings
that happen to be in the binary). **Two of its six entries are GPS:** a **lock timeout** and an
**out-of-tolerance** condition.

And the lock timeout is reachable **with no hardware fault at all**:

```
the device fetches GPS assistance data from its operator's server
   -> that service was retired with the network. The server is gone.
the device deletes its cached assistance file on every shutdown
   -> EVERY lock attempt is a COLD START: no almanac, no ephemeris
   -> minutes of clear sky against a timeout, indoors,
      on units whose external antenna port was deleted
```

⇒ ⭐ **A reader will find a GPS reason and conclude the receiver is dead. It is a dead assistance
server.**

**CHECK.** Treat a GPS service-disable reason as **expected** on this hardware in 2020s conditions,
and go look for the other gates (traps 5, 10, 25) before suspecting the receiver. See
[`HARDWARE.md`](HARDWARE.md) for why you probably do not need a GPS antenna at all.

> ### ⛔ AND WE CANNOT TELL YOU HOW TO CLEAR IT — BECAUSE OUR OWN CELL RADIATES WITHOUT EVER LOCKING
> The unit these notes come from **serves handsets today with no GPS fix, ever.** So the gate is not
> currently blocking us, **and nobody knows why.** A guide that told you *"GPS will stop you"* would
> be contradicted by our own cell.
>
> ⚠️ **This trap is DIAGNOSTIC, not prohibitive.** It tells you what a GPS reason means. It does not
> tell you the gate is your problem, and it does not tell you how to satisfy it.

⚠️ **Bounds, all of them in this sentence:** the binary evidence is from a **donor** unit; the file
that owns this question **retracts half its own support** (the strings live in a validating setter,
the actual decision site is **unlocated**, and a once-only lockout callback is unread); and our own
unit's flash has never been read.

📌 **An untested lead, published as a lead and not a recipe:** you control DNS for this device, so a
wildcard for the operator's domain makes it ask **you** for the assistance file. ⛔ **The file's
format is unread** — serving a valid one is a real hosting job, not a config line. **Do not treat
this as a procedure.**

---

## 49. The reset button reaches factory-restore sooner than the manual says
**Measured on an ip.access nano3G (train `563.16.0`), by reading the vendor's own switch-monitor
binary. ⛔ NOT measured on any DPH — the value below is almost certainly different on yours, and
the point of this trap is the method, not the number.**

**SYMPTOM.** You mean to reboot the unit and you factory-restore it instead. Your NV environment,
your installed key, your access flags and both config banks are gone, and the unit comes back in
its shipped state — which on this hardware means **no management surface at all**. Nothing warns
you, because from outside a reboot and a restore look identical while they happen.

**MECHANISM.** The button is sampled by a small vendor daemon that maps **hold duration** to one
of two outcomes, and it prints its own thresholds in its help text:

```
held for LESS than N seconds  ->  reboot                    (harmless)
held for MORE than N seconds  ->  RESTORE FACTORY DEFAULTS  (one-way)
```

**On the unit measured here `N` was 3. Every document in reach said 5** — the vendor manual, and
two write-ups derived from it. ⇒ ⭐ **There is a band between the real threshold and the documented
one where a press you believe is safe performs a factory restore.** On this unit that band was two
seconds wide, and a four-second press — comfortably "short" by the documentation — lands in it.

⚠️ **And the error is asymmetric, which is why it is worth a trap.** The documented figure is
*safe for the operation the manual describes* (you want a restore; 5 > 3, so you get one, with
margin). It is only wrong for the operation the manual does **not** describe: a deliberate short
press. So the number is simultaneously correct in the guide and dangerous in the reader's hand.

**CHECK.** ✅ **Read the thresholds off your own unit rather than trusting any document, this one
included.** The daemon is small and its help text is plain:

```sh
strings /path/to/the/switch-monitor-binary | grep -i -A2 'switch is pressed'
```

⚠️ **If `strings` is absent, `grep` the binary directly** — and print the denominator, because a
zero from a missing tool and a zero from a binary that does not contain the text are the same
observation.

> ### ⭐ The generalisable half: **the binary is a better source than the manual, and it is on the
> ### device you already own**
> This threshold has been written down three ways in this project — `>10 s`, then `>5 s`, then the
> measured `3 s` — each revision tightening it, and each one carried forward by people quoting the
> previous document rather than the device. **Three sources agreeing is not three pieces of
> evidence when they share one origin.**
>
> ⚠️ **Treat any surviving unsourced duration in a femtocell guide as suspect**, and prefer a
> number you can point at in a binary over a number you can point at in a PDF.

> ### ⛔ And there is only one instrument that tells you WHICH one you performed, after the fact
> The device writes a reboot-cause history, and a restore and a reinitialise get **different
> cause codes**. That file is the only thing that distinguishes them — the LEDs do not, and the
> boot looks the same.
>
> ⚠️ **Two things about reading it.** It is **reverse-chronological**, so `tail` gives you the
> oldest entries and a confident wrong answer. And the reinitialise code has **more than one
> writer** — a short button press, a management-interface reboot action, and your own tooling can
> all produce it — so **that code means "a reinitialise happened", not "somebody mistimed a
> press."** `[measured: three distinct writers of the same code on one unit.]`

---

## 50. The handset finds the cell, shows it, and will not connect — because you are lying to it about your power
**Mechanism from the vendor's own management library plus 3GPP TS 25.331. The magnitude is
disputed between two of our own derivations, and is published disputed.**

**SYMPTOM.** The handset lists your network and camps on it. Registration never completes. It
reads as access control, a core-network fault, or a barred cell. It is none of those.

**MECHANISM.** The cell broadcasts its CPICH transmit power in SIB5. **A handset does not
measure your power — it is told.** It then sets its first RACH preamble by open loop:

```
Preamble_Initial_Power = P_CPICH(from SIB5) - CPICH_RSCP + UL_interference + Constant
```

Advertise a higher CPICH power than the cell actually radiates and the handset infers an
enormous path loss, then **transmits its preamble that much too hot** — into a femtocell that
may be a metre from its face. The receive front end overloads, the RACH fails, and the attach
never begins. The vendor's library states both the precondition and the consequence:

> *"…If this rule is broken, the **actual power with which CPICH is transmitted will be
> different from the value of Primary CPICH Tx Power that is broadcast in SIB5/5bis**."*

> ### ⭐⭐ This is the interference mode a containment plan usually misses completely
> Every other power discussion in this repo concerns **your downlink** — how far the cell
> reaches and who can hear it. **This one is uplink, and the transmitter is not yours.** It is
> every handset in range being instructed to shout. ⇒ **A containment argument that bounds the
> femtocell's own output and stops there does not touch this at all.**

> ### ⚠️ And the attribute behind it does not look like a power setting
> `cpichTxPowerUpperLimit` reading **500** is not somebody asking for +50 dBm. **500 is exactly
> the 3GPP TS 25.331 ceiling for that SIB5 field** — the value an *unset* field sits at.
> ⇒ **Correcting it changes the honesty of the advertisement, not the output.** The radio
> cannot exceed its hardware power ceiling whatever this attribute says.
> ⭐ **So "nobody ever configured this" and "somebody turned it up" present identically here,
> and they call for opposite actions.**

> ### ⚠️ How much too hot? Two derivations, and they do not agree
> ```
> ~29 dB   the figure carried in our brief
> ~47 dB   broadcast 50 dBm vs a CPICH at 10 percent of a 13 dBm carrier (= +3.0 dBm)
> ```
> **Sign, cause and order of magnitude agree. The figure does not**, and it turns on a CPICH
> power-percentage attribute that was never read. **"Tens of dB" is the honest statement.**
> ⛔ **Do not quote a number from here** — read the percentage and the hardware ceiling on your
> own unit.

**CHECK.** Compare what you **advertise** against what you can **radiate**. They are different
attributes and **the device does not check them against each other.** ⚠️ **And in `CONFIGURED`
mode the upper-limit attribute stops being a bound and becomes the actual transmitted CPICH
power** — so the identical number means two different things depending on a setting documented
in another guide entirely: [`CONFIG.md`](CONFIG.md#rfparamscandidatelist--the-one-nobody-sets-and-the-cell-dies-without-it). See also
[trap 16](#16-transmit-power-setting-one-limit-is-not-containment), which is the same subject
from the downlink side and is also unresolved.

---

## 51. A staged radio parameter is a loaded change, and any reboot fires it
**Measured on an ip.access unit. The mechanism is ordinary; the hazard is entirely in the timing.**

**SYMPTOM.** A carrier or band change you made days ago — or did not know you had made —
appears after an unrelated reboot. Nobody connects the two events, because nobody rebooted in
order to apply anything.

**MECHANISM.** `rfParamsCandidateList` is **applied at boot**, not at write time. A write
therefore does not change the live carrier: it **arms** one. The `set` succeeds, a readback of
the live `uarfcn*` is unchanged and correct, and everything looks healthy — because at that
moment everything *is* healthy.

⇒ **Staging and applying are separated by an arbitrary amount of time, and by whoever reboots
next.** That need not be you and need not be deliberate. A crash, a watchdog, a power cut and a
deliberate bring-up all apply it equally well.

> ### ⭐⭐ The dangerous shape: a step that arms a change in a different subsystem from the one it is named after
> Two of our own runbooks had the operator write a candidate list as part of a **PLMN**
> procedure. ⇒ **Running a block called "set the PLMN" silently armed a BAND revert.** Both
> writes succeed. Both readbacks pass. The band moves at the next power cut, and whoever debugs
> it is hunting a change that nobody made.
>
> ⭐ **Before any reboot, on any unit, compare the STAGED value with the LIVE one.** That is a
> different question from *"did my write succeed"*, and only the first one finds this.

> ### ⚠️ And do not verify a band by grepping your own notes
> When we corrected a band, the live configuration changed and **the notes did not** — the
> superseded value went on outnumbering the correct one by roughly **fifty to one** across our
> own documents. ⇒ **Anyone grepping for the band found overwhelming agreement on the wrong
> answer.** **A count of agreeing documents measures copying, not truth.** Read it from the
> device.

> ### 📌 A fresh unit ships with nothing staged
> `rfParamsCandidateList` read `()` on a factory-state unit — **empty, nothing armed.** ⇒ **This
> hazard is about what *you* arm, not about what arrives**, which is worth knowing before you go
> hunting for a staged value on a unit nobody has configured. It also means **a factory restore
> disarms it**, at the cost of everything else a restore takes.

**CHECK.** Ask for the staged list and the live carrier as **two separate questions**, and
compare them. ⛔ **A successful `set` is evidence of a successful `set` and of nothing else.**
Related: [trap 2](#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
is the same hazard one layer down, where what a reboot picks up depends on which bank is live.

---

## 52. You corrected the fact, and the stale copy now reads as corroboration
**Not a device fault. Measured on this repository, twice, two commits apart, in opposite
directions — which is what identified the missing step.**

**SYMPTOM.** A claim you have already corrected is still wrong somewhere else in the corpus.
Worse than a lone error: **a reader who cross-checks two documents and finds them agreeing comes
away with *more* confidence, not less.** A partial correction actively strengthens belief in the
thing it was meant to remove.

**MECHANISM.** Two failure modes that look unrelated and are the same missing step.

```
CORRECTING   fix the mention you found; the others stand, and now read as independent sources
ADDING       grep the file you are editing, find nothing, conclude it does not exist
```

Both happened here within two commits. The first: a config attribute documented backwards, fixed
in one guide while two others kept the original wording. The second: a data-model section
written into a second guide that had held it all along, because the check was *"is it in this
file"* rather than *"is it in this repo"*.

> ### ⭐⭐ The rule is **grep the corpus**, not **grep carefully**
> Neither instance was careless. Both greps were correct, ran cleanly, and answered the question
> they were given. ⇒ **The defect was the scope of the question**, and scope is not something
> care fixes — you can read a file with total attention and still be reading one file.

**CHECK.** Two greps, and they are the same grep pointed at the repo rather than the file:

```sh
grep -rn '<the old claim>' --include='*.md' .    # after correcting anything
grep -rln '<the concept>'  --include='*.md' .    # before adding anything
```

⚠️ **And positive-control the second one**, because it is the one whose failure is silent: a
search that finds nothing and a search that cannot find anything print the same result. Confirm
the pattern matches something you know is present before trusting a zero.

---

## 53. "Read-only" that came from a warning string, not from a rejected write
**Measured on an ip.access nano3G, on two unrelated attributes.**

**SYMPTOM.** An attribute is documented — in your own notes — as read-only, and work is planned
around routing past it. **It was never read-only.**

**MECHANISM.** The setter prints a warning and **performs the write anyway**:

```
**** Setting Read-Only Attribute <name> (<id>) from DMI is not recommanded
<name> (<id>) = <the value you just set>          <- and the readback confirms it
```

⚠️ **"not recommanded" is not a refusal, and the device is not lying** — it is saying the write
is *unsupported*, which is a different claim from *impossible*. **Nobody tried it, because the
warning read like a refusal.**

⭐ **The tell is that the claim has no failed write behind it.** Ask of any "read-only" in your
notes: **did someone write it and observe a rejection, or did someone see a warning and stop?**
Those two produce identical documentation and opposite facts.

> ### ⚠️ Two independent instances, and there is a third outcome hiding between them
> - **`csgIndicator`** — the setter warns, the write lands, **and the broadcast does not follow**.
>   See [trap 4](#4-csgindicator-reads-false-in-the-database-and-broadcasts-true-on-the-air).
>   ⇒ ⭐ **A successful write to a "read-only" attribute can still change nothing that matters.**
>   That is a **third state** beyond accepted and rejected, and **a readback cannot distinguish
>   it from success** — the stored value is exactly what you asked for.
> - **`managementServerType`** — warned, **applied, confirmed by readback**, and behaviourally
>   real. Planning had rested on the belief it could not be changed, and that belief traced back
>   to the warning rather than to any attempt.

**CHECK.** ⛔ **A warning is not a return code.** Write it, read it back, **and then check what
the value actually governs** — because the two instances above differ precisely there, and only
the second one did anything.

---

## 54. Every watched process is running, every port is listening, and there is no cell
**Measured on an ip.access nano3G during commissioning.**

**SYMPTOM.** The unit looks healthy by every instrument you would naturally reach for. The
watched applications are all running. The ports you expect are listening. Nothing has crashed
and nothing is logging an error. **There is no radio and no cell.**

**MECHANISM.** One empty string at the top, and below it a chain of components that are each
**waiting correctly**:

```
managementServerUrl, OPERATIONAL tier, EMPTY
  -> the management-server TYPE stays at its non-TR-069 default
  -> the device sits in a management mode whose server address is also empty
  -> there is nothing to provision from, so it never provisions
  -> the system manager parks, awaiting application registration
  -> the 3G control app's registrations go unanswered
  -> the internal readiness gate never flips          (trap 57 -- and a zero there
                                                       is NORMAL pre-bring-up)
  -> no transceiver, no Iuh, no cell
```

⭐ **Nothing in that chain is faulted.** Every component is in a legal state, doing the correct
thing given its input. ⇒ **A process table cannot see it, a port check cannot see it, and a crash
log cannot see it, because there is no crash.** That is *why* every instrument agrees the unit is
fine — they are all answering questions about liveness, and nothing is dead.

⛔ **Only the first link is worth checking**; the rest are consequences. Read the **operational
tier** of the management-server URL, by its bare name — see
[the four-tier model](CONFIG.md#the-four-tier-value-model), and note that the tier trap and this
outage are the same event seen from two ends.

**CHECK.** ✅ **Choose an instrument that can only be satisfied by the END of the chain.**
*"Is there a cell"* is answerable. *"Are the processes up"* is a different question, and it will
keep agreeing with a dead unit for as long as you are willing to ask it.

---

## 55. `ps` truncates the argument list, so a flag reads as absent
**Measured on an ip.access nano3G (busybox `ps`).**

**SYMPTOM.** You check whether a daemon was started with a particular flag. `ps` does not show
it. You conclude it was started without it, and go looking for why.

**MECHANISM.** **busybox's `ps` truncates the argument list.** The process really does carry the
flag; the output simply does not reach it. There is no ellipsis and no warning — **the line just
ends**, and a short line looks exactly like a complete one.

✅ **`/proc/<pid>/cmdline` has the truth.** It is NUL-separated, so make it readable:

```sh
tr '\0' ' ' < /proc/<PID>/cmdline; echo
```

> ### ⭐ This refines the rule at the top of this file rather than repeating it
> That rule says `ps` answers *is it listed*, not *is it running*. **This is a third question it
> does not reliably answer either: _with what arguments_.** ⇒ **Three different questions, one
> command, and it looks equally authoritative answering all of them.**
>
> ⚠️ **And the failure direction is the dangerous one:** a truncated line reads as **absence of
> the flag**, never as presence. **So it always fails toward "the thing you were looking for is
> not there"** — which is the conclusion that starts an investigation rather than ending one.

---

## 56. `sed -ie` may or may not have made a backup, and the flag cannot tell you
**Measured locally on BusyBox 1.37.0. What the device's much older BusyBox does is NOT
established here, which is the entire point of this entry.**

**SYMPTOM.** A vendor script edits a critical file with `sed -ie`. You read that and conclude a
backup exists, because `e` looks like a suffix. Or you conclude one does not, because you have
read that BusyBox's `-i` takes no suffix and `-ie` therefore parses as `-i -e`. **Both readings
are defensible and at most one is true on your unit.**

**MECHANISM.** `-i` optionally takes an *attached* suffix, and support for that varies by
implementation and by version:

```
GNU sed             -ie  ->  in-place, backup suffix "e"          file.e IS created
BusyBox 1.37.0      -ie  ->  in-place, backup suffix "e"          file.e IS created   [measured]
BusyBox 1.9.2       -i takes NO suffix, so -ie = -i -e            NO backup at all    [measured]
```

`[both measured, not reasoned: BusyBox 1.37.0's help prints `-i[SFX]` / "Optionally back files up,
appending SFX" and the run produced the suffixed file; BusyBox v1.9.2 (2011), on the femtocell
itself, prints a bare `-i` and the identical run left no suffixed file.]`

> ### ✅ One command discriminates, and you should run it before trusting either row
> ```sh
> busybox sed --help 2>&1 | grep -- '-i'      #  -i[SFX]  => a backup IS written
>                                             #  -i       => it is NOT
> ```
> ⇒ **The help text is the authority for the build in front of you**, and it takes a second.

⇒ **The same eight characters mean two different things**, and which you get depends on a version
nobody checked. **Roughly fifteen years and an added feature separate those two rows.**

> ### ⭐⭐ Two correct measurements disagreed, and adjudicating between them would have been wrong
> This entry exists because a reported claim did not reproduce. The reported behaviour was real —
> **on the device.** The contradicting measurement was also real — **on a modern build.**
> ⇒ **The fix for a disagreement between two valid measurements is not to decide which is right.
> It is to ask which INSTANCE each claim is about.**
> ⭐ **A mechanism is true over a range, and a claim without its range is not finished.** Neither
> party had stated a version, so the sentence *"BusyBox `sed -i` takes no suffix"* was unfalsifiable
> and wrong-sounding at the same time — **it is true of some BusyBoxes and false of others, and
> nothing in it says which.**

**CHECK.** ✅ **Look for the file.** `ls` beside the target for the exact suffixed name. One
command, and it answers what the flag cannot.

> ### ⭐ The failure is asymmetric, which decides when to look
> Believing a backup exists when it does not **costs you the file**. Believing one does not exist
> when it does costs you **a wasted `ls`**. ⇒ **Check before you need it**, not after — and if the
> suffix *is* honoured on your unit, there is a recoverable copy sitting there that nobody has
> been looking for.

---

## 57. The readiness gate reads zero on a healthy unit, because bring-up is what opens it
**Measured on an ip.access nano3G across four boots. Provenance bounded at the end — a second
unit is measured only in the negative.**

**SYMPTOM.** You read the firmware's readiness word on a unit you have not brought up, get
`00000000`, and conclude the board is faulty or still initialising. **You wait. It never
changes.**

**MECHANISM.** ⭐ **The gate is a PRODUCT of bring-up, not a precondition for it.**

```
bring-up, step 1     programs the radio array  (the vendor's own init script)
bring-up, ~49 lines later
                     polls the readiness word, aborts if it never reads 1
```

⇒ **That poll VERIFIES step 1 worked. It is not waiting for the device to become ready.** And the
**normal boot path never programs the array at all** — it performs an FPGA load and stops there.
⇒ **So the array is unprogrammed on every boot until something programs it, and zero is the
correct reading on a unit nobody has brought up.**

`[measured, 4 boots, 4-for-4: programmed -> gate 1 -> cell came up · never programmed -> gate 0
-> the core-side connection fails in a way that makes no sense on its own terms.]`

> ### ☠️ And the obvious fix is the destructive one
> **Do not program the array by hand against a running application set.** The vendor's init
> script **stops and resets the array before it loads anything** — so against live apps that is a
> RUNNING→STOPPED transition underneath a process whose job is to notice exactly that. It raises
> a fatal error, the manager aborts, the process watchdog sees the death, the radio is turned
> off, and **the board reboots.**
> ⇒ ⭐ **Order is load-bearing: array first, applications after.** A bring-up script that insists
> on that order is not being fussy.
> ⚠️ **Two defects, one root:** the array is never programmed at boot, **and** programming it
> late destroys the thing it was fixing.

**CHECK.** ✅ **Ask what WRITES the value, not what reads it.** A status word with no writer on
the boot path cannot change on the boot path, and no amount of waiting will move it. ⇒ **Grep the
boot scripts for the writer.** If the only one lives in your bring-up, then a pre-bring-up zero
is the design rather than a fault.

> ### 📋 Provenance, stated narrowly because this is the kind of claim that gets over-stated
> ```
> MEASURED   one unit, four boots, both directions
> MEASURED   a second unit, BOTH directions -- gate 0 before bring-up,
>            and 1 on the first poll after it, watched twice
> ```
> ⇒ ✅ **Two units, both directions. An earlier revision of this entry said the second unit was
> measured only in the negative; that was true when written and was superseded within the day.**
>
> ⚠️ **The address of the status word is firmware-specific and is deliberately not the load-bearing
> part of this entry.** On ours it is `713eb8`; **treat that as a starting point for your own
> build, not a constant** — see [trap 56](#56-sed--ie-may-or-may-not-have-made-a-backup-and-the-flag-cannot-tell-you)
> for what happens when a version-dependent detail is carried across builds as though it were universal.

📌 This is the named version of the link that [trap 54](#54-every-watched-process-is-running-every-port-is-listening-and-there-is-no-cell)
describes abstractly as *"the internal readiness gate never flips"* — **there it is the last link
in a chain of correct waits; here it is a thing you will read directly and misinterpret.**

---

## 58. A script that runs inside `$( )` must not background anything that keeps stdout
**Mechanism measured locally, both shapes. Whether it is what bricked a unit is UNRESOLVED — see
the bound at the end.**

**SYMPTOM.** You append a few harmless lines to a boot-time helper — a watchdog loop, a poller,
anything long-lived and backgrounded — and the device stops completing its boot. **The lines are
correct. They work when you run the script by hand.**

**MECHANISM.** ⭐ **Command substitution waits for EOF on stdout, not for the main process to
exit.** A backgrounded child **inherits that stdout** and holds the substitution open for as long
as it lives. So if the script is invoked as `$(…)` — and on this platform the root hook *is* a
command substitution, because the injected value is `"x$(…)"` — **your background job pins the
boot.**

```
$( sh helper.sh )        helper backgrounds a loop, stdout not redirected
                         -> the substitution does not return until that loop EXITS
                         -> boot stalls exactly where the payload runs
```

`[measured locally: a backgrounded 2-second loop that keeps stdout made `$(…)` take **2009 ms**;
the same loop with the redirect moved returned in **4 ms**.]`

> ### ☠️ And the fix that looks right is wrong — redirect the SUBSHELL, not the command inside it
> ```sh
> ( while …; do thing; done ) &                  # ⛔ pins the substitution
> ( while …; do thing >/dev/null 2>&1; done ) &  # ⛔ STILL pins it -- the SUBSHELL holds fd 1
> ( while …; do thing; done ) >/dev/null 2>&1 &  # ✅ the redirect belongs here
> ```
> ⚠️ **Redirecting the inner command is the shape that fools people, and there is a reason it
> fools them: it sometimes works.** A subshell containing a **single command** is commonly
> optimised into an `exec`, so the inner redirect lands on the only process and the hazard
> disappears. **A subshell containing a loop cannot be optimised away, so the subshell survives
> holding the inherited descriptor.**
> `[measured: single-command subshell with an inner redirect returned in 5 ms — indistinguishable
> from fixed. The identical pattern around a loop took 2009 ms.]`
> ⇒ ⭐⭐ **So "redirect the inner command" is a rule that passes on the simple test case and fails
> on the real one.** That is worse than a rule that never works.

**CHECK.** ⭐⭐ **Before you edit a script, ask how it is INVOKED.** The same three lines are
inert in an init script and fatal inside `$( )`. **Nothing in the script tells you which**, and
the file you are editing looks identical in both worlds. ⇒ **Grep for the callers before you add
anything long-lived**, and if any caller is a substitution, redirect at the subshell.

> ### ⚠️ BOUND — the hazard is established; the incident is not
> This is published because **anyone who gains persistence on one of these boxes will eventually
> add something to a boot hook, and the hook is a command substitution.** That much is measured.
>
> ⛔ **What is NOT established is that this is what killed the unit it was found on.** The
> mechanism predicts a stall at the point the payload runs — but the network client and the SSH
> daemon start **before** that point, so a stall there should leave the box **pingable, with SSH
> answering.** **It is not pingable at all.** ⇒ **Most likely cause, not proven cause**, and the
> discrepancy is recorded rather than explained away.

## 59. The manual for your device family may not cover your model, and the one that does has a different version number
**Measured across three archived ip.access installation manuals for the same product family. The
generalisation to other vendors is reasoning, not measurement, and is marked as such.**

**SYMPTOM.** You want a hardware fact your device cannot tell you — what the status LED means,
whether an antenna is internal or fitted. You open the installation manual for your AP family,
find the section, and act on it. **The section is complete, well formatted, and about a different
model.** Nothing in it is wrong; nothing in it is about your unit.

**MECHANISM.** Vendors revise a manual across a product line's lifetime and **drop models as they
add others**, keeping the document number. Two revisions of `N3G_INST_300`, measured:

```
FILE                                    "S8"   "S4"   "E8"
N3G_INST_300_AP_Install_v7.0.txt          0      37     53      LED tables: S4, E8
N3G_INST_300_v292_1.0_2012.txt           63       0     58      LED tables: E8/E16, S8, S16
N3G_nano3GAP_Installation_Manual_2009     0       0      0      an earlier line entirely
```

⇒ ⭐ **The two are DISJOINT on S4 and S8 while sharing a document number.** The older revision has
**no S8 content at all** — so a reader with an S8 gets a confident, complete-looking answer from
the S4 or E8 table and never sees a warning, because from the document's point of view nothing is
missing.

> ### ☠️ And the two revisions give OPPOSITE instructions on the same subject
> ```
> v7.0  §3.3.3  "To fit external antennas, first remove the plastic cover ...
>                Unscrew the antennas to expose the SMA connectors."      <- this is the E8
> 2012  CAUTION "Do not attempt to fit an external antenna or antenna
>                cabling to the nano3G S8 AP."                            <- this is the S8
> ```
> ⇒ **One document family, one subject, opposite instructions, and the discriminator is a model
> suffix that appears nowhere in either sentence.** A reader who has only the first revision will
> go looking for connectors that are not there, on a unit whose antennas are internal.

**CHECK.** ✅ **Before reading any table, grep the manual for your exact model string and require a
non-zero count.**

```sh
grep -c 'S8' manual.txt        # 0 => you have the wrong revision, not a missing feature
```

⇒ **A zero is the signal.** It costs one command and it is the only thing standing between
"the manual says" and a fact about someone else's hardware. ⚠️ **And do it per section, not per
document** — a manual can cover your model in the installation chapters and silently drop it from
the troubleshooting ones.

> ### 📋 Provenance
> ```
> MEASURED   three manual revisions, one product family, counts above, reproducible
> MEASURED   the two contradicting antenna statements, quoted verbatim from each file
> REASONING  that other vendors do the same. Common publishing practice, not measured here.
> ```
> ⚠️ **The counts are of the model STRING, not of meaningful coverage** — `S8` could in principle
> appear only in a compatibility list. Here it does not: the 2012 revision carries a dedicated
> `8.1.2 nano3G S8 AP LEDs` section. **Confirm the hits are substantive before trusting the number.**

📌 This is the documentation-layer form of the same error
[trap 2](#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell) records at
the device layer: **a correct instruction for one model in a family destroys another.** There it
is a config bank; here it is the page you read to find out.

---

## 60. A corpus you are writing is not a corpus you have read
**Reported by the lane it happened to, on the evening this file was growing fastest. The
generalisation is theirs; the incident is recorded because they asked for it to be.**

> ⚠️ **An earlier revision of this line named the exact entry count.** It was correct when written
> and false by the end of the same evening — **inside the card about documentation you trust
> without checking.** Left as a note rather than quietly fixed, because the demonstration is worth
> more than the tidiness.

**SYMPTOM.** You spend an hour diagnosing a fault, concluding the hardware is at issue. **The
answer is in a file in your own repository, which you have been actively adding to all evening.**
You never opened it.

**MECHANISM.** ⭐ **Authorship feels like knowledge.** Directing material *into* a document
creates a strong and false sense of having its contents available. The feeling tracks **effort
spent on the file**, not **facts retrievable from it** — and the two diverge fastest exactly when
the file is growing quickly, which is also when it is most likely to contain what you need.

```
the lane had:     directed entries INTO this file the same evening
the lane needed:  an entry already in it, on the exact verb that was failing
the lane did:     an hour on a hardware hypothesis, and asked a human to inspect the unit
```

> ### 🔴 AND THE SECOND HALF, WHICH IS SHARPER AND WAS REPORTED BY THE SAME LANE AGAINST ITSELF
> **Reading the corpus is not enough, because there are two kinds of answer and the wrong one
> feels more authoritative.** Faced with a command that acknowledged and did nothing, the lane had:
> ```
> (a) the running script's OWN comment, three lines from the failure:
>       "1216 is DECLINED when the AP is not yet ready"
> (b) an entry in this file, measured on a DIFFERENT MODEL:
>       "not dispatchable by number"
> ```
> ⇒ **It took (b).** It was general-sounding, it required no further work, and **it made the device
> the problem rather than the device's state.** (a) was correct, and the control that settled it —
> **a working unit's own bring-up log, showing the same numeric call succeeding** — was in a sibling
> directory and never opened.
> ⇒ ⭐⭐ ***A finding from elsewhere feels like knowledge; a comment in the file you are running
> feels like noise.*** **Prefer the local, specific, boring source.** A general finding that
> transfers is a claim about two devices; **a comment beside the failing line is a claim about
> this one.**
> ⛔ **And the cost was not just delay.** Believing the call was broken, the lane forced the value
> by hand — **turning an informative decline into a silent one, and papering over the real stall.**
> ⇒ **Acting on the wrong explanation destroyed the evidence for the right one.**

> ### ⭐ Why it is worse than ordinary forgetting
> A document you have never seen prompts you to go and look. **One you have been writing does
> not** — it is already represented in your head as *handled*. ⇒ **The failure is silent and it
> gets more likely as the file gets better**, because a growing file is evidence of attention,
> and attention is what you are wrongly inferring recall from.
> ⚠️ **It compounds on a team.** Where several people or lanes publish into one document,
> **each one's contribution feels like coverage of the whole**, and nobody holds a reason to read
> the parts they did not write. The file's own growth becomes the reason it goes unread.

**CHECK.** ✅ **Search your own documentation FIRST, on the same terms you would search a
stranger's — and do it before forming a hardware hypothesis, not after one fails.**

```sh
grep -rn -i '<the verb you just ran>' docs/     # before the second attempt, not the fifth
```

⇒ ⭐ **Treat "we wrote that up" as a reason to grep, not a reason to skip grepping.** The cost is
one command; the alternative is re-deriving your own conclusions and asking someone to go and look
at hardware that was never at fault.

📌 **This file exists because of this trap, and is subject to it.** Its entries are written so a
stranger can act on them — **read them as a stranger.**

---
## 61. The cell registers on the core with a perfect identity while its own MIB has none — because a shim supplies it

**SYMPTOM.** The AP registers on Iuh, the gateway prints a complete, correct cell identity, bring-up
exits 0, the radio LED is lit and a carrier is selected — **and no handset will camp on it.** Unlock
(`action 1216`) is refused every time, acking each time and changing nothing.

**WHAT IS ACTUALLY WRONG.** The AP has **no cell identity of its own**:
```
                        broken AP      working AP
mcc   (1398)            ""             "999"
mnc   (1399)            ""             "99"
sac   (1583)            -1             1
lacRacCandidateList (2048)  ({1,(0)})  ({10422,(99)})
saiLac (2098)           -1             10422
```
**A cell with no PLMN, LAC or SAC cannot broadcast a selectable cell.** It transmits; a UE reads it
and declines it.

**WHY EVERY INSTRUMENT SAID IT WAS FINE.** The Iuh shim **hardcodes** the identity and writes it
into the config object on every start. So the gateway's own view —
`MCC 999 MNC 99 LAC 10422 SAC 2 CID 2` — is **correct and comes from the shim, not from the AP.**
⇒ **The shim answers the identity question on behalf of an AP that has no identity.**
⭐ **THE MISREADING THAT COSTS THE HOURS:** the documentation says the shim *"overwrites whatever
OAM provisioned"*, which reads as *identity is handled*. It means the shim covers the **CORE** path.
**The AIR path still reads the MIB.** Two consumers of one conceptual value, and the loud one masks
the silent one's absence.

**AND THE REFUSAL IS THE HONEST SIGNAL.** The vendor manual says: *"The AP will remain locked if it
is not ready to provide service."* ⇒ **An AP with no identity is not ready, so the unlock is
correctly refused.** Measured, same device, same session:
```
before provisioning:  action 1216 -> ack'd -> rrmAdminState LOC_LOCKED    (6 times, 2 operators)
after  provisioning:  action 1216 -> ack'd -> rrmAdminState LOC_UNLOCKED  (FIRST fire)
```
⛔ **Do not force it.** Writing `rrmAdminState = LOC_UNLOCKED` directly succeeds, reads back
correct, and leaves the cell exactly as unusable — **it destroys the one signal telling you what is
wrong.** A repeated refusal is a diagnosis, not an obstacle.

**THE CHECK.** Before blaming the radio, read the identity **out of the AP**, never off the core:
```
get 1398   get 1399   get 1583   get 2048   get 2098
```
Any of `""`, `-1`, or a default-looking `({1,(0)})` means the cell is unprovisioned. **Copy a
working unit's values and change only what must differ — the SAC and cell id.**

**THE GENERAL FORM.** ⭐ *When component A supplies a value on behalf of component B, every check
that reads A will pass while B is empty.* Ask **which component answers the question your
instrument asks**, and read the value from the one that has to **use** it.

---

## 62. Packet data depends on an address that exists at runtime and in no configuration file
**Measured on the core side of a working private UMTS network carrying data for real handsets.
Core-side, so it applies whichever femtocell you are using.**

**SYMPTOM.** Data works. It works for days. **Then the core host reboots and every packet session is
gone** — no handset attaches, no context activates, and **nothing in any log names a cause.** The
daemons start, bind, and report healthy.

**MECHANISM.** The GTP daemons bind and peer on a **secondary IP address**, and both halves name it
explicitly:
```
osmo-ggsn.cfg   gtp bind-ip      <the address>
osmo-sgsn.cfg   ggsn 0 remote-ip <the address>
```
⚠️ **The address itself was added once, by hand, with `ip addr add` — and existed in no netplan, no
`systemd-networkd` unit and no `/etc/network` file.** ⇒ **It survives exactly as long as the host
stays up.**

> ### ⭐ Why nothing tells you
> **A missing bind address is not an error at the layer that reports errors.** The daemons come up,
> the config parses, the VTY answers. The failure is that a peer relationship silently has no
> endpoint — and **the address's absence is invisible to every component that depends on it**,
> because each one only knows the string it was configured with.
> ⇒ **This is a landmine, not a fault: it is armed the moment the address is created by hand, and it
> fires on an unrelated event weeks later.**

**CHECK.** ✅ **For every address your config files name, ask which file creates it.**

```sh
grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' /etc/osmocom/*.cfg | sort -u | while read a; do
  printf '%-16s ' "$a"
  ip -4 addr | grep -q "$a" && printf 'live '   || printf 'ABSENT '
  grep -rqs "$a" /etc/netplan /etc/systemd/network /etc/network && echo 'persisted' || echo 'NOT PERSISTED'
done
```
⇒ **`live` + `NOT PERSISTED` is the landmine.** ⭐ **Both columns are needed** — "it answers" and
"it will answer after a reboot" are different questions, and only the second one is about
configuration.

📌 **Generalises past GTP.** Any interface alias, any route, any `ip` command typed during a debugging
session becomes load-bearing the moment something is configured to point at it. **The debugging
session ends; the dependency does not.**

---

## 63. A host route fixes the voice symptom and cannot fix the data one, because the rejection is a source-address check
**Measured on a live network where both symptoms appeared together and looked like one fault.**

**SYMPTOM.** Media does not flow. You add a host route to the AP's transport address, **voice starts
working immediately** — and **data still does not.** The obvious reading is that the route is
incomplete, or that data needs a second route.

**MECHANISM.** They were never the same fault.
```
DLGTP ERROR  Unknown GSN peer <addr>       6133 of 6141 GTP errors were this ONE line
```
⭐ **That is a check on the SOURCE ADDRESS of the arriving packet, not a routing decision.** A route
changes which way a packet leaves; it does not change the address the packet arrives *from*. ⇒ **The
peer check rejects it on arrival regardless of how well it was routed.**

> ### ⭐⭐ AND THE DETAIL THAT RULES OUT THE OBVIOUS ALTERNATIVE
> **The rejected tunnel id is the GGSN's OWN local id for that subscriber.** ⇒ **It knows the tunnel.
> It recognises the session. It refuses the packet anyway, on the source address alone.**
> **That is what eliminates "unknown tunnel" as an explanation** — and without it you would spend the
> afternoon on session state, which is correct and irrelevant.

**CHECK.** ✅ **When one fix resolves half a symptom, treat the halves as separate faults until
proven otherwise.** A single change that fixes voice and not data is **evidence they were two
problems**, not evidence the change was partial.
⇒ **Read what the rejecting component actually says.** Here it named the reason in one line,
repeated six thousand times, while the search was for something subtler.

---

## 64. Three handsets, three unrelated faults, one symptom — and the fix is a log filter
**Measured while bringing packet data up for real handsets.**

**SYMPTOM.** "Data doesn't work." Three handsets, none of them online, and an afternoon spent
looking for the network fault they have in common. **There isn't one.**

**MECHANISM.** Each handset failed for **a different reason that was not the network's**:

| handset behaviour | actual cause |
|---|---|
| sends **no APN** at all | falls through to the core's `default-apn` — ✅ **works, once a default exists** |
| attaches but **never activates a context** | nothing broken; the bearer was proven separately |
| a third, unrelated per-device fault | its own owner, its own fix |

⇒ **Three faults with three owners, presenting identically at the only place anyone was looking:
the aggregate log.**

**CHECK.** ✅ **Filter every packet-data log by IMSI before concluding anything.**

⇒ ⭐ **That single habit turned one apparent network fault into three handset faults.** An aggregate
log over N subscribers is **N interleaved stories**, and the shared symptom is an artefact of the
view, not a property of the system. **Pick one subscriber and follow it end to end.**

⛔ **And one diagnostic to avoid while you are in there: `show mm-context all` SEGFAULTS the SGSN.**
A command that reads state should not be able to end the process holding it; this one can.

---

## 65. A derived value is computed once at cell setup, so provisioning a running AP changes the database and not the air
**Measured on an ip.access nano3G. The mechanism is a derived-vs-stored distinction and is not
specific to one attribute — expect siblings of it.**

**SYMPTOM.** You correct the cell identity on a running AP. **Every readback confirms it.** The value
reaches flash. You fire the apply action and it returns **confirmed**. ⇒ **And handsets still see the
old identity**, because the air never changed.

**MECHANISM.** ⭐ **The broadcast value is not the attribute you wrote.** It is **derived** — computed
**once, at cell setup**, from the attribute — and then held:

```
you write     the identity attribute        -> database ✅  flash ✅  readback ✅
the air       carries a value RRM computed  -> from the attribute as it was AT CELL SETUP
                                               and keeps it until the next cell setup
```

⇒ **Two values, one name.** The stored one is what every instrument shows you. The derived one is
what a handset reads. **They agree right up until you change the stored one on a running cell.**

> ### ⛔ AND THE APPLY ACTIONS DO NOT RECOMPUTE IT — ONE OF THEM CONFIRMS ANYWAY
> ```
> the parameter-apply action    does NOT recompute it
> the unlock/select action      does NOT recompute it  --  AND RETURNS CONFIRMED
> ```
> ⇒ ⭐⭐ **A confirmed action reads as an applied action.** That is the whole trap: the
> acknowledgement is truthful about the *call* and silent about the *effect*, and there is no
> observable difference from the side that issued it.
> 📌 Same family as [trap 5](TRAPS.md#5-a-cold-boot-leaves-the-cell-locked-and-the-obvious-unlock-sets-the-wrong-attribute) —
> **an acknowledgement is a statement about receipt, never about consequence.**

> ### ⭐ WHY NOBODY HITS THIS DURING A NORMAL BRING-UP
> **The bring-up path is safe for free, because it runs after a reboot** — cell setup happens
> *after* the attributes are in place, so derived and stored agree. ⇒ **The trap is reachable only by
> hand-provisioning a cell that is already up**, which is exactly what you do when you are fixing
> something. **The repair path is the exposed one; the happy path is not.**
> ⚠️ **That also means it can hide for a long time**, validated by every clean bring-up, in the same
> way [trap 5](TRAPS.md#5-a-cold-boot-leaves-the-cell-locked-and-the-obvious-unlock-sets-the-wrong-attribute)
> was validated by every warm reboot.

> ### ⭐⭐⭐ CONFIRMED AS A **CLASS**, NOT A ONE-OFF — PREDICTED FIRST, THEN MEASURED
> **The prediction was made from this entry's mechanism, before the test was run**, on a completely
> different attribute — the neighbour list:
> ```
>                  the INPUT you write          the ACTIVE list the cell uses
> BEFORE reboot    written and verified ✅       EMPTY  ()
> AFTER  reboot    unchanged            ✅       POPULATED, matching the input
> ```
> ⇒ ⭐ **Two unrelated values, one mechanism.** The cell identity is derived from its stored id; the
> active neighbour list is derived from the static one. **Both are computed at cell setup and both
> ignore a write made afterwards.**
> ⇒ 🎯 **So this is not a quirk of one attribute — it is how this firmware treats derived state**,
> and the right response to finding one instance is to **assume siblings and go looking**, not to
> patch the instance. **A prediction that survives a test on an attribute you have never touched is
> worth more than three more measurements of the original.**

**CHECK.** ✅ **Compare what the AP BROADCASTS against what it is CONFIGURED with — never one alone.**
The configured side is any readback; the broadcast side has to come from the air or from the core's
view of the registered cell.

⇒ **If they disagree, reboot rather than re-apply.** Re-applying confirms and changes nothing, which
costs you the next hour.
⭐ **And generalise the question rather than the fix:** for any value you are about to write on a
running cell, ask **"is this stored, or is it derived from something stored?"** A derived value has a
moment of computation, and **writing its input after that moment is a no-op with a receipt.**

---

## 66. Two co-varying candidates cannot be separated on one unit — a second unit with a *different* identity is an instrument, not redundancy

**Measured on ip.access nano3G hardware. The shape is general: it applies to any derivation you are
trying to attribute, on any fleet where the units were configured alike.**

**SYMPTOM.** You want to know which of two values a third value is derived from. You read all three
on the unit you have. **They are consistent with the hypothesis.** They are also consistent with the
*other* hypothesis, and nothing in the reading tells you that.

**MECHANISM.** The two candidate inputs happen to hold **the same value** on that unit:

```
unit A     candidate X = 1     candidate Y = 1     derived = 1     <- consistent with BOTH
unit B     candidate X = 1     candidate Y = 2     derived = 2     <- consistent with Y ONLY
```

⭐ **On unit A the question is not merely unanswered — it is unanswerable**, and it stays unanswerable
no matter how many times you read it, how carefully, or over how many days. In the case that produced
this trap the inference sat in the notes for **twelve days**, correctly flagged as untraced, and every
observation taken in that window was compatible with it.

⛔ **The failure mode is that the reading FEELS like confirmation.** You predicted the derived value
from candidate X and the device agreed. It would have agreed with a prediction from candidate Y too.

✅ **THE CHECK.** Before attributing a derivation, ask: **do my candidate inputs differ on the unit I
am reading?** If they do not, **the reading cannot discriminate** — say so, and go and find a unit
where they do. **One correctly-configured unit and one differently-configured unit are worth more
than ten identical ones**, and a fleet configured from one template is a fleet of one instrument.

📌 Related: trap 65 (a derived value is computed once at cell setup). The same derivation is at issue;
this trap is about how you establish *what it derives from*.

## 67. Get the distribution before calling it a storm — and check whether your own repair started it

**Measured on a live core. The instrument is a per-hour histogram over the whole log, not a rate.**

**SYMPTOM.** A counter is running far above what you expect. You name it a storm, attribute it to the
system you are working on, and start eliminating causes. **Every cause you eliminate is real work and
none of it converges**, because the framing is wrong in a way none of the eliminations can reach.

**MECHANISM — TWO framings collapse into one, and both are wrong:**

```
what you say      "this unit has been flooding all night"
what you measured  a RATE, inside a window you chose because the rate was high in it
what the histogram says
                   ~12/hour all day ................ the baseline
                   873 in ONE hour .................. the flood
                   and that hour is the hour YOU changed something
```

⭐⭐ **The flood began when the repair landed.** The unit had been up for an hour before that at **22
in the hour** — indistinguishable from baseline. ⇒ **The storm was a product of the fix, not the
condition the fix treated.** A rate cannot show you that; only the distribution can, because the
distribution contains the moment *before*.

✅ **THE CHECKS, in order:**
1. **Histogram the whole log by hour before quoting any rate.** A rate is a claim about a window, and
   you chose the window *because* of its contents.
2. **Line up the onset against your own change log.** The most likely author of a brand-new anomaly is
   the most recent change, and the most recent change is usually yours.
3. **Measure a window with no actions of your own in it.** In the case that produced this trap, the
   first "it's fixed" reading contained three events **that were the observer's own test**, and the
   first "here's the cause" reading was taken from a window the observer had just polluted the same way.

⛔ **AND A COROLLARY ON NAMING CAUSES.** An unfamiliar error line appeared in that polluted window and
was announced as the engine of the flood. Counted afterwards: **1 occurrence in 649 events**, and it
later occurred **twice in a window containing zero events of the kind it supposedly caused.**
⭐ **NOVELTY IS NOT FREQUENCY.** A line is salient because you have not seen it before, which is a fact
about your reading history and not about the system. **Count it before you name it.**

## 68. A model check admits a device on evidence gathered from a different device
**Measured twice in this project, on opposite sides of the same law — once as a destructive
configuration error, once as a permission guard that was written to prevent it.**

**SYMPTOM.** You have two units of the same model. A tool, a runbook step or a safety check asks
*"is this a supported model?"*, gets **yes**, and proceeds — **using a fact that was established on
the other one.**

**MECHANISM.** ⭐ **Model is a proxy for a capability that was measured once, on one box.** The proxy
and the fact are identical right up until you own two, and then they come apart silently:

```
what the check asks      "is this a <model>?"                 -> a TYPE question
what it needs to know    "has THIS UNIT's behaviour been      -> a PER-DEVICE question
                          exercised here?"
```

⇒ **Nothing in the answer says which question was actually answered.**

> ### ⭐⭐ THE TWO FACES, AND THEY POINT IN OPPOSITE DIRECTIONS
> **As a configuration error —** which bank of firmware config is live is **per-device**. A correct
> bank number for one unit is destructive on its sibling, and one model in this family has no
> numbered banks at all. **Carrying the number across is the mistake.**
> ⇒ [trap 2](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell).
>
> **As a permission error —** a tool that stages a **loaded change** (applied by any later reboot,
> not only the one you intended) guarded itself with an explicit allow-list rather than a model
> check, and said why in its own comments:
> > *"MODEL IS NOT THE PRECONDITION, AND a model check ALONE WOULD WIDEN THIS TOOL … its real
> > precondition is 'this DEVICE is deployed and its band behaviour has been exercised here', which
> > is a per-device fact … a model check would admit [the second unit] **on the strength of a
> > measurement taken on a DIFFERENT box.**"*
> ⇒ ⭐ **The second unit would have passed a model check and failed the actual precondition.**

> ### ⚠️ AND THE SUBTLE PART: READING THE ATTRIBUTE ON ONE UNIT STRENGTHENS THE GUARD
> When the relevant capability attribute **was** finally read — on the first unit — the obvious
> conclusion is *"good, now we know the model supports it."* **The opposite is true.** The attribute
> is **readable and per-unit**, which means a model check is now demonstrably answering a question
> the device can answer for itself. ⇒ **Evidence that a per-unit measurement is available is
> evidence AGAINST substituting a type for it.**

**CHECK.** ✅ **For any check that gates an action, ask what it would have to be true of to be
sufficient — then ask whether the thing you measured is that.**

- **If a capability is readable per unit, read it per unit.** A model is a cache of that read, taken
  on hardware you are not holding.
- **Prefer an explicit allow-list to a type check for anything irreversible.** An absent entry
  refuses; a type check guesses, and guesses in the permissive direction.
- ⛔ **When you promote a unit into an allow-list, promote it on the measurement, not on its
  siblings.** "Same model as the one that works" is the exact inference this entry exists to stop.

📌 **And a documentation corollary, learned the same evening.** The refusal message cited a doc, and
the doc was then updated in the belief that the tool read it. **It did not** — the gate was a
hardcoded list and the doc was the *justification*. ⇒ ⭐ **A file a program names in its output is not
necessarily a file the program consults.** **Read the code before editing the thing the error message
blames.**

---

## 69. Five of the components write no log at all unless the unit is in developer mode
**Measured in a DPH-153 firmware extraction, and independently on a live ip.access sibling. The two
halves come from different models, and that is stated rather than merged.**

**SYMPTOM.** A process is misbehaving. You go for its log. **The file is empty, or it does not exist.**
⇒ You conclude the process is dead, wedged, or never started — and you are now debugging the wrong
thing, because **the process is fine and nothing was ever going to write that file.**

**MECHANISM.** Each component's start script redirects its own output **only in developer mode**:

```sh
if [ "$OP_MODE" = "OP_DEVELOPER" ]
then  ./$PROG >/tmp/$PROG.txt 2>&1 &     # the per-process log you are looking for
else  ...                                 # started with NO redirect at all
```

⇒ ⭐ **This is not one component being awkward.** Measured in one firmware image, in five separate
start scripts — the DMI agent, the radio-resource manager, the user-plane app, the L1 router and the
SoIP router. **Every one of them is silent by default.**

> ### ⭐⭐ AND THE DEFAULT IS "NOT DEVELOPER"
> On a live sibling unit, `OP_MODE` is sourced from a file **that does not exist on a normal unit**,
> falling through to the non-developer value. ⇒ **So the absent log is the SHIPPED behaviour, on
> every component, on every unit nobody has deliberately switched over.**
> ⚠️ **Which means a zero here is evidence about the MODE and nothing whatsoever about the process.**

> ### ⛔ AND DO NOT SWITCH THE MODE TO GET THE LOG
> `OP_MODE` gates more than logging — the same variable appears in the start path of five components.
> ⇒ **Changing the operating mode of a unit in order to observe it changes what you are observing.**
> **Find where the output actually goes instead.** With no redirect, a component's stderr follows
> whatever the init system gave it — on the units here, the boot console log. **That file exists on a
> normal unit and the per-process one does not.**

**CHECK.** ✅ **Before treating an empty log as a symptom, find out which process is supposed to write
it, and under what condition.**

```sh
grep -rn "$(basename <the log file> .txt)" /opt/*/*/*.sh    # who redirects into it, and inside what if
```
⇒ **If the writer is inside a mode test, the file's absence is configuration, not failure.**
⭐ **The general form: a log file has a writer, and the writer has a condition. "No log" is a claim
about the condition until you have checked it.**

> ### 📋 PROVENANCE, because the two halves are from different models
> ```
> MEASURED   the five gates and the redirect form   -- in a DPH-153 firmware extraction
> MEASURED   the default falling through to non-developer, and the per-process log
>            absent while the component ran normally  -- on a live ip.access nano3G
> NOT ESTABLISHED   where OP_MODE is set on the DPH-153 itself. Do not assume it is the
>                   same file as the nano3G's; that is the cross-model inference this
>                   repo cards elsewhere.
> ```

---

## 70. A counter measures its own node, never the flow — and a zero from one can be the correct value
**Measured on a working private UMTS network moving real traffic. Core-side, so it applies whichever
femtocell you are using.**

**SYMPTOM.** Packet data "does not work." The session exists, the bearer is up, radio bearers are
assigned, the handset's modem transmits — **and the packet-core node you ask reports `User Data Bytes
(In): 0`.** You conclude nothing is flowing.

**MECHANISM.** ⭐ **With direct tunnel the user plane runs RNC ↔ gateway and never passes through the
serving node at all.**

```
control plane   handset -- RNC -- SERVING NODE -- gateway     the node sees this
user plane      handset -- RNC ------------------ gateway     the node never sees this
```

⇒ **The serving node cannot count bytes it does not carry.** ⇒ ⭐⭐ **No amount of traffic will ever
move that counter. Zero is the CORRECT reading for a healthy direct-tunnel session.**

> ### ☠️ AND THIS IS WORSE THAN A BROKEN TOOL, WHICH IS WHY IT DESERVES ITS OWN ENTRY
> **A broken tool is caught by a positive control on the tool.** This one **passes every control you
> would think to run**: the management interface answers, the session is listed, the counters are
> present and correctly formatted, and **every neighbouring field is accurate** — the access point
> name, the assigned address, the tunnel endpoints. ⇒ **Nothing is wrong with the instrument.**
> ⭐⭐⭐ **The only wrong thing was the assumption that the bytes go past it.**
> ⇒ 🎯 ***Ask what PATH the data takes before believing a counter on a node.***

**CHECK.** ✅ **Measure at the endpoint, not at a waypoint you have not proven is on the path.**

```sh
# paired before/after on the handset's own interface — the cheapest decisive measurement
<read interface counters>;  <generate known traffic>;  <read again>;  diff
```
⇒ **A delta on the device's own radio interface is a fact about the radio.** In the run this entry
comes from, **a 1 MB download showed a ~1.09 MB receive delta** on the cellular interface while the
serving node still read zero — and **that** settled it.
⭐ **The rule that generalises: when two instruments disagree, prefer the one closest to the physical
thing.** A byte counter on the interface that carries the bytes outranks a byte counter on a node
that may not be in the path.

> ### 📋 THREE SIBLINGS FROM THE SAME INVESTIGATION, ALL OF WHICH READ AS "NO TRAFFIC"
> | what was read | why it was wrong |
> |---|---|
> | a **cumulative** counter, read **once** (`RX=30MB`) | quoted as evidence of *current* flow; **delta over 5 s was 0.** It was history. |
> | a ping to an address **on the same /26** as the source | never entered the tunnel at all — it went to neighbour discovery. **100 % loss read as a dead tunnel.** |
> | the wrong device entirely | the handset was camped on a **different cell** than the one under test. **Counting per-device rather than in aggregate settled it.** |
>
> ⇒ ⭐ **All three produced a confident zero, and none of them was a malfunction.**

> ### ⚠️ A COROLLARY IF YOU REWRITE ADDRESSES ANYWHERE IN THE PATH
> Where a packet-rewriting rule is in play, **downstream error messages name the REWRITTEN address,
> not the original.** ⇒ **Grepping the logs for the address you started with returns nothing, and
> that reads as "the fix stopped working" when it means the opposite.** **Grep for both, and know
> which one a healthy system should be showing you.**

📌 **And the discipline this entry exists to protect: "not tested" and "does not work" are different
claims.** In this investigation two cells had never been tried at all — no sessions, no subscribers —
and their silence was briefly read as failure. **An untested path produces the same zero as a broken
one, and only the test tells you which you have.**

---
