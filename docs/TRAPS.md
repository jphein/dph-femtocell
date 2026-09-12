# Traps

Failure modes that cost us days. Each one is written as **SYMPTOM** (what you will see),
**MECHANISM** (why), and **CHECK** (the observation that distinguishes it from what it
resembles).

**Every trap names the device it was measured on.** These models differ, and an instruction
that is correct for one can destroy another — trap 2 is a worked example of exactly that.

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

**CHECK.** Ask for the staged list and the live carrier as **two separate questions**, and
compare them. ⛔ **A successful `set` is evidence of a successful `set` and of nothing else.**
Related: [trap 2](#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
is the same hazard one layer down, where what a reboot picks up depends on which bank is live.
