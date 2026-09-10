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
`cellParameterSelectionMethod` defaults to **AUTO**, which selects *from a candidate list*.
With an empty list the select action **acknowledges and selects nothing**. Format is a
tuple list: `({<uarfcn>, <scrambling-code>, 1})`.

**What you see if you skip it:** `uarfcnDownlink = -1`, `scramblingCode = -1`,
`operationalState = DISABLED` — and the cell **still registers with the core**. An HNBAP
association with no radio. The core says up; the handsets say no service.

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
