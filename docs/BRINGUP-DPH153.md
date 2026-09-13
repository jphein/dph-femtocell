# Bring-up: Cisco DPH-153 — the published route, and what this repo can and cannot tell you

> ### 📋 EVIDENCE CLASS — read this first, it is the whole point of this page
> ⛔ **This repo has not brought up a DPH-153.** Nothing below is a measurement taken here.
> **The route is someone else's**, published independently and first, and it is the better-supported
> path if you are working from public documentation rather than from this repo.
> ⇒ **This page is a router and a scope statement, not a substitute for the original.** Where this
> repo has something genuinely additive — the software-layer material it shares with the 151 — that
> is named explicitly and bounded.
> ⚠️ **Treat every step of the hardware half as the original author's claim, not as ours.**

---

## What is established

- **A DPH-153AT has been reported registering with `osmo-hnbgw` and radiating UMTS**, after IPsec
  was disabled and its hardcoded NTP and HNB-GW addresses were repointed. Reported on Osmocom
  Discourse by `tempest`. ⇒ **Reported, not reproduced here.**
- **The published route reaches root via JTAG**, and its author is explicit about the constraint
  below.

## 🔴 The hardware half does NOT transfer between models

> **The published procedure needs contact with a point on the underside of the board that does not
> exist on the DPH-151 and is different on the DPH-154.**

⇒ ⭐ **Following the 153 route on a 151 will strand you at the hardware step**, and following it on a
154 will put a probe on the wrong place. **The *software* half transfers between models; the
*JTAG/hardware* half does not.** This is the single most important sentence on this page, and it is
the original author's, not ours.

**Extra kit this route needs**, beyond [`HARDWARE.md`](HARDWARE.md)'s general list:

| item | approx | why |
|---|---|---|
| JTAG adapter | ~$21 | a J-Link clone is enough |
| USB↔UART adapter | — | **3.3 V only** — see [`HARDWARE.md`](HARDWARE.md) |

---

## What this repo adds, and it is the software half only

Once you have a root shell by whatever route, **the ip.access software stack is the same family**
across the 151, the 153 and the nano3G. The following are measured here and are about that stack,
not about any model's hardware:

| this repo's material | where | transfers to a 153? |
|---|---|---|
| Pointing the unit at your own core | [`BRINGUP.md`](BRINGUP.md) Phase 4 | ✅ same attributes |
| Radio parameters, unlock order, the transmission gate | [`BRINGUP.md`](BRINGUP.md) Phase 5 | ✅ same attributes |
| Surviving a power cut unattended | [`BRINGUP.md`](BRINGUP.md) Phase 7 | ✅ same mechanism |
| The failure modes | [`TRAPS.md`](TRAPS.md) | ⚠️ **read each entry's scope line** |
| Which config bank is live | [`trap 2`](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell) | 🔴 **per-model. Read the symlink; never assume.** |

⛔ **Do not read an unattributed trap as applying to your 153.** That file states what each entry was
measured on, and where it does not name a device it names a **source** instead — which is the honest
answer for a finding that is not model-specific, and **is not the same claim.**

---

## Where to start

1. **Read [`TRAPS.md`](TRAPS.md) first**, as for any model here.
2. **Follow the original published 153 route for the hardware and root half.** Osmocom Discourse is
   the primary source; [`README.md`](../README.md#prior-art) lists prior art.
3. **Come back to [`BRINGUP.md`](BRINGUP.md) Phases 4–8 for the software half**, substituting this
   model's attribute values.

---

## What would make this a real guide

**One person bringing up a 153 against an Osmocom core and writing down what differed from the 151.**
Specifically:

- **Which attribute values differ**, and whether any attribute *ids* differ.
- **Which config bank is live** on a stock 153 — the one value this repo already knows is per-model
  and destructive to guess.
- **Whether the unattended power-cut recovery** in Phase 7 works unchanged.
- **Whether the 153's second SoC behaves like the 151's** for the addressing traps, which are the
  ones known not to transfer cleanly.

⇒ **Until then this page stays a router.** A guide that reads as complete while resting on someone
else's single report is exactly the failure this repo exists to avoid.
