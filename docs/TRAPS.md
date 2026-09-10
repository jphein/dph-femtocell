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

## If you only read four

Ranked by what they actually cost us, not by how interesting they are:

| | trap | why it is first |
|---|---|---|
| 1 | **[#21 — give a cold boot 20 minutes](#21-a-cold-boot-takes-about-16-minutes-and-every-check-gave-up-sooner)** | ten cold boots scored as failures. The cell was fine. Three confident negatives, two people, **all correct when taken and all early**. |
| 2 | **[#5 — two parallel state triplets](#5-a-cold-boot-leaves-the-cell-locked-and-the-obvious-unlock-sets-the-wrong-attribute)** | invisible for months, because the attribute you naturally read is the one that looks healthy. |
| 3 | **[#3 — an address the AP cannot be reached at](#3-the-ap-advertises-an-address-it-cannot-be-reached-at)** | one root cause, four unrelated-looking symptoms, five people chasing the radio. One command finds it. |
| 4 | **[#6 — `show hnb` lies in both directions](#6-show-hnb-on-the-core-lies-in-both-directions)** | it reported a cell as connected for three minutes after it was unplugged. Everything downstream inherits that. |

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

⚠️ **Scope, and it matters: the DPH-151 firmware ships this key correctly in BOTH forms.**
Do **not** hand-append it there. This trap is the nano3G's, and it is in this guide because
the two run the same firmware family and the failure is so completely silent.

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

**MECHANISM.** `cellParameterSelectionMethod` defaults to AUTO, which selects *from a
candidate list*. With `rfParamsCandidateList` empty, the select action **acknowledges and
selects nothing**: `uarfcnDownlink = -1`, `scramblingCode = -1`,
`operationalState = DISABLED`. An HNBAP association with no radio.

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

**CHECK.** Set both; **read back the operational one**. And confirm the unit can actually
*reach* the NTP server you gave it — on an isolated segment, a public address resolves fine
and never syncs.

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
