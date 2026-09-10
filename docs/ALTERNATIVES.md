# Alternatives: when one of these is the wrong choice

A MicroCell is cheap and awkward. Sometimes the awkwardness is not worth it. This is the
honest comparison.

---

## The options

| option | works? | rough cost | the trade-off |
|---|---|---|---|
| **ip.access nano3G** (S8 / E16 / S16) | ✅ proven, and it is the family Osmocom's own wiki documents | **$180–200** | highest certainty. **The band trap below is the real risk.** |
| **DPH-151** | ✅ proven — this repo | **~$10** | 20× cheaper, and costs weeks of reverse engineering. ⚠️ part of the root route is not publicly available (see below). |
| **DPH-153** | ✅ published route by someone else | ~$10 | **best public documentation.** Needs **JTAG and opening the case**. |
| **DPH-154** | 🔴 no | ~$10 | **teardown only.** See [`HARDWARE.md`](HARDWARE.md). |
| **Any CDMA femtocell** (Verizon, Sprint, Airvana) | 🔴 no | cheap, abundant | **wrong air interface.** Osmocom has no CDMA core. Ruled out before band matters. |
| **Band 1 stock** (Vodafone Sure Signal, SFR, most Huawei) | 🔴 no *for US handsets* | cheap, abundant | **wrong band.** Fine if your handsets are Band 1. |
| **SDR, UMTS** | 🔴 no | — | **structural, not a maturity gap.** See below. |
| **SDR, GSM/2G** | ✅ yes | new radio hardware | the real fallback if you abandon 3G. |

---

## ⚠️ The nano3G buying trap: the part-number suffix **is** the band, and the wrong band is cheaper

If you go the reliable route, this is the mistake to avoid. Checked against the FCC
certification text:

```
IPA237B / 237BA · IPA239B · IPA243B / 243BA    UMTS Bands 2 & 5   ✅  (US 1900/850)
IPA237C / 237CA · IPA217C · IPA239C            UMTS Band 4 (AWS)  ❌
"Band 1 E8 AP"                                 Band 1             ❌  (European)
```

> ### 🔴 The trap is live in the listings: the **wrong-band** `239C` was seen at **$140–150**
> ### while the **right-band** `239B` was **$180–200**.
> A listing that says only "nano3G S8" with no part number is a coin flip, and the cheaper one
> is more likely to be the wrong one.

⭐ **And a photo will not save you.** FCC external-photo exhibits show the same enclosure and
**the same rear barcode label** across models — a "237…" assembly number appears even on an
S16 sample. **Only the separate FCC-ID label is authoritative. Make the seller photograph
that one.**

⚠️ **"LOCKED" units are a documented brick, not a theoretical risk.** One was listed at $200
matching a years-old report of locked status LEDs and the management port refusing
connections, with no published resolution.

⚠️ **An FCC ID does not tell you the firmware version.** The same FCC ID set is listed across
firmware generations. What you can infer is a weaker **floor** — a unit cannot run firmware
older than the release that introduced its model. ⭐ **Use that to prefer a unit, never to rule
one out**: the working S8 in this lab is an early part number and it has the Iuh data model.

---

## SDR: this is structural, not "not yet"

People reasonably assume a software radio can do this. For UMTS it cannot, and the reasons are
worth stating so nobody spends a month finding out.

**Osmocom's own hNodeB component says so in its README:** *"This is not expected to be a full /
usable hNodeB anytime soon [if ever]."* It implements **signalling only** — no air interface,
no SDR support. It is a test peer for the gateway, not a base station.

> **GSM on SDR works and UMTS on SDR does not, because GSM is narrowband TDMA that commodity
> radios handle, whereas WCDMA needs continuous 3.84 Mcps chip-rate processing with far
> tighter timing.** Nobody has shipped a working open implementation.

- **OpenBTS-UMTS** — a real open UMTS physical layer *does* exist, and it still does not help.
  **Zero occurrences of `Iuh` in the source**: it ships its own SIP and packet-core trees and
  **replaces** the radio network and core rather than plugging into one. Its maintained fork
  states outright: **packet data only** — circuit-switched voice, SMS, handover, paging,
  ciphering and USIM authentication all explicitly unsupported. ⭐ **Bands are fine; it is the
  absence of voice that kills it, not the radio.**
- **srsRAN / OpenAirInterface / Amarisoft** — LTE and NR only. No UMTS/WCDMA.

## Buying a *new* 3G femtocell: the category is retired

Surveyed across the usual wholesale and marketplace channels: **zero genuine WCDMA Home
NodeBs.** No listing anywhere mentions Iuh, HNBAP, or the relevant 3GPP specification. Minimum
order quantity is not the blocker — **the product does not exist**.

⚠️ **Naming traps abound.** Model names containing "HNB" are frequently LTE units.

---

## The honest reason the used market is so thin

The instinct that there must be a glut is **correct**. AT&T MicroCells are described in the
trade press as boat anchors; Verizon began suspending 3G extender lines in late 2022; the UK's
3G sunset alone is projected at tens of tonnes of e-waste.

But that inventory filters to almost nothing:

1. **Air interface** — Verizon / Sprint / Airvana femtocells are CDMA2000. Osmocom has no CDMA
   core. Gone before band matters.
2. **Band** — European and UK stock is Band 1 (2100). US handsets are 850/1900. They cannot
   see it. (If *your* handsets are Band 1, this filter inverts and the European stock is your
   cheap route.)
3. **Tractability** — of the survivors, only one family has any documented path to an open core.

⇒ For **US** bands, the intersection of *abundant*, *UMTS*, and *850/1900* is essentially
**AT&T MicroCells and nothing else.**

---

## ⚠️ One caveat on this repo's own route

The DPH-151 path described here was reproduced end to end **in one lab**, and this repo is the
write-up. The DPH-153 route was written up independently, by someone else, first.

⇒ **If you are working purely from public documentation, the DPH-153 is the better-supported
buy** — there is a published end-to-end account of it, whereas for the 151 you have this repo
and fourteen-year-old prior art. That is a real difference and we are not going to paper over
it, even though the 153 costs you JTAG and a case opening.

⇒ **If you are following this repo, the 151 is the one it describes**, and the way in is a
publicly documented procedure — see [`ACCESS.md`](ACCESS.md). You generate your own key; there
is no credential here to need.

---

## And the option that is not a device

**Do you actually need a private 3G cell?** If the goal is keeping old handsets useful, a
GSM/2G network on an SDR is a genuinely supported, documented path with mature open-source
support — and many of the handsets that matter are quad-band GSM.

⚠️ **But note one thing the femtocell gives you for free:** a sealed, low-power consumer device
does some RF containment work that an SDR with an external antenna does not. If you switch
routes, the spectrum discussion in the [README](../README.md) needs revisiting rather than
inheriting — **you have moved the premise.**
