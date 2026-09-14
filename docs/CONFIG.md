# Configuration: the attributes that actually matter

**Scope: measured on a DPH-151 running ip.access train `563.21.8`, unless a line says
otherwise.** Attribute *numbers* are firmware-specific — read them off your own unit. The
*model* below is stable across the family.

---

## The big picture: every operator binding ships as a placeholder

This is the finding that makes the whole project viable. On a factory image, **every value
that binds the device to a network operator is a placeholder in editable configuration**:

| binding | what the firmware ships | what a provisioned unit carries |
|---|---|---|
| **PLMN (MCC/MNC)** | a factory placeholder, not a real carrier | the operator's real MCC/MNC |
| **Security gateway** | a generic `plmnoperator.com`-style placeholder hostname | the operator's SeGW |
| **Management server (ACS)** | a generic `acs.oem.com`-style placeholder URL | the operator's TR-069 servers |

⇒ **"Be the infrastructure" is not a workaround — it is the intended provisioning flow.**
The device is built to be told who it belongs to. You are just the one telling it.

⚠️ **A unit that actually ran on a carrier's network will have the real values written into
its live config.** That is expected on arrival, not a contradiction. Change them.

---

## The four-tier value model

Several important settings exist at **four tiers**, and the naming is parallel across
settings:

```
default<Thing>     compiled-in / factory default
local<Thing>       LOCAL OVERRIDE          <- usually what you want
lkg<Thing>         last known good
<Thing>            the ACTIVE value
```

> ### ⚠️ Two consequences, both of which have bitten
> 1. **Writing the `default` tier is not writing the value in force.** The factory tier is
>    applied after a reset. A write there succeeds, reads back fine, and **changes nothing
>    about current behaviour** — a silent failure that looks exactly like the feature being
>    broken. This is precisely what happens with NTP (below).
> 2. **The `lkg` tier is not readable over TR-069** and some `lkg`-tiered writes **do not
>    survive a reboot**. Re-read after every reboot instead of assuming a write persisted.
>
> ### 🔴 A worked example, measured — and the verification PASSED
> Two units, one serving and one dead, differing in exactly one place:
> ```
>                                working unit        blocked unit
> managementServerUrl (2116)     "http://<acs>/acs"  ""            <- OPERATIONAL, EMPTY
> defaultManagementServerUrl     "<acs-host>"        "<acs-host>"  <- DEFAULTS,  set
> localManagementServerUrl       "<acs-host>"        "<acs-host>"  <- LOCAL,     set
> ```
> **The commissioning form writes the DEFAULTS tier. The operational tier was never populated.**
> ⇒ ⛔ **The verification that was actually performed — reading the form's own echo, which showed
> the address back — passed.** Nobody read `2116`. **The readback was of the wrong tier**, which
> is the failure this section describes, and it still happened to the people who wrote it down.
>
> ⭐ **Which tier a UI writes is not guessable from the UI.** A form that shows you an address
> and accepts it has told you it stored *something*, *somewhere*. **Read the bare name
> afterwards, or you have verified nothing.**
>
> ⚠️ **And a factory restore puts a unit back into exactly this state** — see
> [trap 49](TRAPS.md#49-the-reset-button-reaches-factory-restore-sooner-than-the-manual-says).
> **The recovery path re-arms the fault.**

> ### ⚠️ An EMPTY `lkg*` is not neutral — it is one reason a setting vanishes
> `lkgManagementServerUrl = ""` was measured on a unit whose **operational** value was set
> correctly, and that setting did not survive a reboot: **the last-known-good tier had nothing
> in it, so there was nothing to restore from.** The symptom is a value that reads back
> perfectly, demonstrably works, and is gone after a power cut — which is very easy to blame on
> the power cut.
>
> ⚠️ **It does not always overwrite.** A different fix was measured *holding* across a reboot
> with the `lkg` tier leaving it alone. **The promotion rule — what gets a value into `lkg` and
> when — was never established.** ⇒ **Test reboot survival once, deliberately, rather than
> assuming it in either direction.**
>
> 📌 **Scale, so this reads as structure rather than a quirk of one setting: eight distinct
> `lkg*` attributes appear across our notes** — `lkgApNtpServerInfo`, `lkgIpsecEnable`,
> `lkgManagementServerUrl`, `lkgIpsecGatewayAddress` and `lkgManagementServerType` among them.

> ⚠️ **Precedence between the tiers is a naming convention we have not traced in code.** We
> have the parameter names, the setter, the validator and the commit path; nobody has read
> the arbiter that chooses between them. Treat the ordering above as strong inference, not
> as measured.

---

## The settings you will actually change

### `hnbGwAddress` — where the cell looks for your core
Read-write, string, max length 260. Point it at your `osmo-hnbgw`. This is also a good
**positive control** for whether your management transport works at all: it is a
known-present attribute, so a failed `get hnbGwAddress` means the transport is dead rather
than the name being wrong.

### `ipsecEnable` — turn off the tunnel to a dead security gateway
Set `FALSE`. The device's boot order is **NTP → IPsec to the operator's SeGW → TR-069
provisioning → Iuh**, so with IPsec enabled and the SeGW unreachable it never reaches the
Iuh step. Disabling it is the reported route on the DPH-153 and the measured route on ours.

If you would rather *satisfy* the tunnel than skip it, you can: the trust store is a plain
directory of PEM files on the writable partition, the device trusts vendor CAs rather than
any single operator, and it holds its own client certificate — so your own SeGW can simply
choose to accept it. Adding a CA is a file copy. **Disabling is far less work.**

### `apNtpServerInfo` *and* `defaultNtpServer` — set both
> ### ⭐ Without working NTP the device does not even attempt the HNB-GW connection.
`apNtpServerInfo` is the **operational** attribute; `defaultNtpServer` is the **factory**
tier. Setting only the factory one fails silently, so **set both**.

> ### 🔴 But do not verify by reading the operational tier back on a DPH-151
> It was **rejected in every form tried** there — an error, or a zero maximum length. Only the
> factory-tier name is accepted. The tier model may still describe what the running client reads;
> **you simply cannot confirm it through that attribute on this hardware.**
> ✅ **Verify behaviourally: does the gateway connection get attempted?** That is what NTP gates.

⚠️ **If the unit has no internet route, an NTP address that resolves publicly will resolve
fine and never sync.** Point it at a server it can actually reach.

### `rfParamsCandidateList` — the one nobody sets, and the cell dies without it

Format is a tuple list: `({<uarfcn>, <scrambling-code>, 1})`. **But setting it is only half
the job, and the other half is the part that gets missed.**

> ### 🔴 `AUTO` does **not** read this list. An earlier revision of this page said it did.
> ```
> AUTO        selects from NETWORK-LISTEN SCAN RESULTS
> CONFIGURED  uses exactly the values you supplied
> ```
> **The vendor's own management library says so**, of the parameters NWL chooses between:
> *"It is applicable if Cell Parameter Selection Method is set to Auto, otherwise its value is
> ignored."* ~~A unit that has never run a network-listen scan has an empty scan-result store~~ —
> so **in AUTO the select action acknowledges and selects nothing, with or without a candidate
> list.**
>
> ### 🔴 **THE CONCLUSION STANDS; THE REASON ABOVE IS REFUTED. MEASURED 2026-09-13.**
> `[2g/CLAUDE.md, both nano3G cells, read BY NUMBER. The correction landed in that repo and not in
>  this one -- a cross-repo instance of "a correction that updates one mention leaves the others
>  reading as confirmation." Carried across 2026-09-13 by nebula-librarian3.]`
> ```
> nextRfScanTime (scheduled)              2026-09-13T03:43:00Z
> AP#1  savedNwlResults_001 (2609) = {(), "2026-09-13T03:43:05Z", ""}
> AP#2  savedNwlResults_001 (2609) = {(), "2026-09-13T03:44:04Z", ""}
> ```
> ⇒ ⭐⭐⭐ **THE SCAN FIRED ON TIME, ON BOTH CELLS, AND STAMPED AN *EMPTY* RESULT SET.**
> ⇒ ⛔ **So an empty store does NOT mean "never scanned."** *"Network Listen never scans"* is
> **FALSE**; the correct statement is ***"Network Listen SCANS ON SCHEDULE AND RETURNS NOTHING."***
> ⭐⭐ **Those are DIFFERENT FAULTS WITH DIFFERENT CAUSES** — the first sends you to *"why won't it
> start?"*, the second to *"why can't it hear?"* **Only the second is the real one.**
> ⚠️ **Candidate cause, offered as a candidate and NOT as the answer:** the firmware carries
> *"Ignoring NWL test action as AP is not locked"* ⇒ **a cell may be DEAF WHILE TRANSMITTING**, so
> an unlocked scheduled scan would run, complete and store nothing. ⛔ **UNMEASURED.**
> ### ⭐ **WHY THIS MATTERED ENOUGH TO CORRECT A REASON BEHIND A CORRECT INSTRUCTION**
> **Use `CONFIGURED` — that advice is unchanged and right.** ⛔ **But a reader who ever has to debug
> `AUTO` inherits the premise, reads an empty store as "the scan never ran", and goes hunting for
> why it will not start.** ⇒ ***A true warning resting on a false reason sends the next person to
> the wrong question*** — and this corpus's own law: *it gets dismissed by the first person who
> checks the reason.*
>
> ⭐ **The wrong mechanism produces the right symptom, which is what makes it expensive.**
> Populate the list, leave the method at `AUTO`, and the identical failure comes back — and it
> reads as *"the list write did not take"* rather than *"the device is not looking there"*.

**So set both, method first:**

```
set cellParameterSelectionMethod=CELL_PARAMETER_SELECTION_METHOD_CONFIGURED
set rfParamsCandidateList=({<uarfcn>, <scrambling-code>, 1})
```

✅ **Corroborated independently by sysmocom's shipping nano3G configuration**, which sets the
TR-069 twin of this attribute to `CONFIGURED` and turns off scan-on-boot, periodic scanning and
neighbour-list population. Their entire configuration is *do not scan, use the candidate lists*.

⛔ **Do not run a network-listen scan to "fix" AUTO.** It is an on-air action, it is
unnecessary once the method is `CONFIGURED`, and skipping it removes the question rather than
answering it.

**What you see if you skip all this:** `uarfcnDownlink = -1`, `scramblingCode = -1`,
`operationalState = DISABLED` — and the cell **still registers with the core**. An HNBAP
association with no radio. The core says up; the handsets say no service.

⚠️ **And `uarfcnDownlink` / `uarfcnUplink` are read-only reports, not controls.** A write to
one **succeeds and does nothing** — the device recomputes them from the candidate list at boot.
That looks exactly like a band change that did not take.

> ### ☠️ Switching to `CONFIGURED` changes what a **transmit-power** attribute MEANS
> The same library text, on the CPICH power limits:
> *"If Cell Parameter Selection Method is set to **Auto**, this attribute defines the **lower
> limit** for the CPICH Tx Power that can be selected by NWL… If set to **Configured**, this
> attribute defines the **actual power level at which the Primary CPICH is transmitted**."*
>
> ⇒ **In AUTO these are bounds on an automatic choice. In CONFIGURED they are the setting.**
> The same number, never rewritten, stops describing a limit and starts describing an output —
> and the library notes it **includes the gain of any external amplifier**.
>
> ✅ **Read the CPICH power attributes before and after you flip the method.** This is the one
> configuration change in this guide that can change what you are radiating without any power
> attribute being written, and the [README](../README.md) spectrum section is the thing to
> re-read if the number surprises you.

`[Scope: the library documentation strings are platform-level ip.access text. The AUTO-selects-
nothing behaviour was **measured on an ip.access nano3G**, train 563.16.0 — the same 563 family
as the DPH-151, but not a DPH. The power-meaning flip is **read from the library, not measured
on either**.]`

### PLMN (MCC / MNC)
Two routes, and they are not equivalent:

- **On the filesystem** — the radio resource config file carries plain-text MCC / MNC-digits
  / MNC fields, same structure as the ip.access sibling hardware. Not a signed blob.
- **Over TR-069** — vendor-extension parameters under the `FAPService` cell-config tree
  (the vendor OUI appears in the parameter name). ⚠️ **These are demonstrably readable and
  the ACS can write in principle, but we know of no published successful *write* to MCC/MNC
  on any DPH.** Treat this as "yes by a mechanism proven on sibling hardware", not "yes,
  someone did it".

⛔ **Verify the PLMN on the air, not in the database.** See the `csgIndicator` trap in
[`TRAPS.md`](TRAPS.md): this firmware has at least one attribute where the stored value and
the broadcast disagree, and the broadcast is what matters.

### `administrativeState` — and the attribute that looks like it but is not
The cell has an administrative lock. **A cold boot can leave it LOCKED**, and there is a
similarly-named radio-resource attribute whose "unlock" action **acknowledges, changes a
real state, and does not change this one.** See [`TRAPS.md`](TRAPS.md). Read
`administrativeState` back by name.

---

## Where configuration physically lives

- **Config banks.** The device keeps configuration in two banks with a symlink pointing at
  the live one. ⛔ **Which bank is live differs per unit — do not assume, read the symlink.**
  Getting this wrong can leave a cell with no Iuh and no radio parameters at all. See
  [`TRAPS.md`](TRAPS.md).
- **A software download wipes the live bank.** The post-download hook removes the bank's
  contents. Any hand-edit you have made is gone, silently. Re-apply after every software
  download.
- **Durable writable storage** on our DPH-151 is a jffs2 partition mounted at
  `/var/ipaccess`. Anything you want to survive a power cut goes there. `/var/run` is tmpfs.
- **Factory defaults** live in a hardware-description file read by many consumers; the
  TR-069 defaults live in a plain-text config file. Both are readable and neither is signed.

---

## ⛔ **LOADED CHANGES — a write that looks INERT and fires at the next reboot**

**Two radio attributes on these units have been written, produced NO visible effect, and then taken
effect at a reboot nobody connected to them.** ⇒ **This is a property of the ATTRIBUTE CLASS, not of
either one, and it will bite whoever next touches a radio setting.**
```
rfParamsCandidateList   staged, then ANY reboot applies it — "not just the one you intended,
                        and not only a bring-up": a crash, a watchdog or a power cut will do
3606 primaryCpichPowerPercent   written · 2531 did NOT move · looked COMPLETELY INERT
                        16 minutes later an UNRELATED reboot fired it: -3.0 dBm -> +7.0 dBm
                        ⭐ and it needed NO scan — savedNwlResults kept its old timestamp
```
### ⭐⭐⭐ **THE CONSEQUENCE THAT CATCHES CAREFUL PEOPLE: *"ONE-COMMAND REVERT" IS TRUE OF THE CONFIG AND FALSE OF THE CELL.***
**If a write is loaded, so is its revert.** ⇒ **You revert the setting, observe no change, conclude
the revert worked — and both the change and its undo are queued behind the next reboot.**
⛔ **Two wrong mitigations this produced in ONE night, from careful people:**
```
"harmless today, nothing reads it"          -> FALSE: cell setup reads it
"harmless unless a startup scan succeeds"   -> FALSE: it needs no scan at all
```
⭐ **The second had a GATE the real behaviour does not have, so it implied `nwlOnStartup = FALSE`
as a protection — which would NOT have worked.** ⇒ ***A wrong mechanism describes a wrong repair.***
### ✅ **THE CHECKS, BOTH CHEAP**
1. **Before ANY reboot, on ANY unit: does a STAGED value differ from the LIVE one?** **Staged-vs-live
   is step one of the operation, not a post-mortem.**
2. **Read the `ac` column before calling an attribute a setting.** **Three attributes here were
   recorded as settings and are `ac=0` REPORTS** — `2593`, `uarfcnDownlink`, `3207`. ⭐ **Each time,
   the attribute NAMED the thing somebody wanted, which is exactly when nobody checks.**
📌 Full equation and evidence: `2g/docs/findings/findings-nebula-cpich-power-equation.md`.

> ### 📐 **A DESIGNED-AND-NOT-TAKEN ROUTE, RECORDED SO IT DOES NOT LOOK DISCREDITED**
> **To force a relocation without touching radiated power or needing hands: RAISE THE MEASUREMENT
> THRESHOLD so the UE concludes its serving cell is poor and starts evaluating the neighbour.**
> **Configuration only, contained to one cell, one-command revert.** `[team-lead, 2026-09-14]`
> ⛔ **NOT TAKEN — because a better option existed on the night: JP walked a handset between cells.**
> ⭐ **A call held up while a person walks is a mid-call handover BY CONSTRUCTION** — whereas a
> threshold change risks the UE **RESELECTING AWAY** instead of relocating, ***and a reselection and
> a relocation look the same from the core***, so the experiment could have produced a result that
> read as success and was nothing of the kind.
> ⚠️ **AND: the revert restores the SETTING, not the HANDSET.** **A UE that has reselected away does
> not come back because you reverted.**
> ✅ **KEEP IT: if a trigger is ever needed with nobody present, this is the route.**
> ⛔ **BOUND BEFORE ANYONE RUNS IT: the threshold attribute class is a CORPUS ZERO** —
> `qQualMin` · `qRxLevMin` · `sIntraSearch` · `sInterSearch` all return 0 across `CLAUDE.md`,
> `docs/cards/` and `LAWS-INDEX`, **against a passing control (`cpichTxPower` = 21).** ⇒ **Nothing is
> known about whether it applies LIVE or at CELL SETUP** — ⇒ **assume LOADED until measured.**

---

## Instruments: what these attributes will and will not tell you

> ### 🔴 `hnbGwConnectionCloseCause` is inert. It is not a verdict.
> It reads `INVALID_CONFIGURATION` on a **healthy, connected, working cell**, because that
> is **enum value 0** — i.e. *unset*. It never changes. We previously read its constancy
> through a series of failures as the device "reporting the answer all along"; that was
> inferring agency from a constant, and it is retracted. **A lookup that always returns
> something is not a measurement.**

> ### ⚠️ The SCTP association counters reset per boot.
> `sctpAssociationAborts` / `sctpAssociationClosures` describe the **current boot only**.
> A `0` shortly after a reboot is not evidence that nothing ever happened. Never quote them
> across a boot.

**Read-back is the rule, everywhere.** A log line from the *caller* saying it issued a
command is not evidence the *callee* accepted it. We watched a heartbeat-interval set log
"setting heartbeat to 120", and the kernel's own association table still read the old value:
the code path ran and the socket option was not accepted. **Prefer a read-back of the
callee's state over any log line from the caller.**
