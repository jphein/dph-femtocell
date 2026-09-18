# Bring-up: Cisco DPH-153 — the published route, and what this repo can and cannot tell you

> ## 🔑 **THIS PAGE ASSUMES THE DEVICE IS YOURS. THAT IS NOT A DISCLAIMER — IT IS THE SUBJECT.**
> **Everything here is written for someone holding hardware they bought, pointing it at a core
> they run.** ⭐ **That is not packaging around the technical content; it is what the technical
> content is *for*.** A guide to reusing your own device and a guide to attacking someone else's
> are different documents even where a paragraph would look the same.
> ⛔ **Nothing here is for equipment or a network you do not own** — not a carrier's, not a
> neighbour's, not one you found. **No route on this page is published to help you reach
> somebody else's unit**, and every one of them needs physical or LAN access you would only
> have to your own.
> 📌 **What you may publish, what you may not, and the one bright line: [`LEGAL.md`](LEGAL.md).**

> ## 1️⃣ **BEFORE STEP ONE — CONFIRM WHICH UNIT YOU ARE HOLDING: [`MATRIX.md`](MATRIX.md)**
> **This guide is for the DPH-153: the donor archive's train · board code `224F`**
> ⇒ ⛔ **If your unit is not that, STOP — the other models differ in ways that have cost this
> project days: bank numbering is REVERSED between the 151 and the nano3G, the 154 has no banks
> at all, and a 579 measurement is not a 563 fact.**
> ✅ **[`MATRIX.md`](MATRIX.md) is the identification table** — `## Identity`, `## Silicon and RF`,
> `## Capability`, `## Access and state`. **Read it first; it is 166 lines and it is the only
> document that tells you WHICH machine you have before you type anything.**
> 📌 **POINTER, NOT A COPY.** `[Wired in 2026-09-14: MATRIX.md existed and NO guide referenced it —
> the identification step was written and orphaned.]`


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

## ✅ A WORKING REFERENCE **CONFIG SET** EXISTS — added 2026-09-14

**It is the CORE side, not a device procedure, and that distinction is the whole value of it.**
📌 **[`(private lab notes)`](../../(private lab notes)) — 23
files, 24.8 MB, saved from `tempest`'s folder (Discourse topic 2625, post 41) on 2026-09-06.**
⇒ **`cfgs/` holds seven Osmocom configs — `hnbgw · msc · sgsn · ggsn · hlr · mgw · stp` — from a
deployment that carried a DPH-153.** ⭐ ***This project's own oldest law: the broken device tells
you where it failed; the working one tells you what a correct request looks like.*** **We had never
held a working reference config before.**

### 🔴 **THE DIFFERENCES, AND ONE IS A LIVE UNTESTED LEAD**
⛔ **POINTER, NOT A COPY — the full diff, with its bounds, is in that archive's `README.md`.**
```
                    THEIRS              OURS
hnbap-allow-tmsi    1                   ABSENT      🔴 the difference worth testing
cs7 instance 0      point-code 0.23.5   ABSENT      ⚠️ we rely on defaults
                    sccp-address msc/sgsn
iuh local-ip        EXPLICIT            EXPLICIT    ✅ corroborates our 2026-09-03 fix
plmn                001 01 (ITU test)   999 99      ⚠️ a data point, NOT evidence against 999-99
```
⭐ **`hnbap-allow-tmsi 1` permits HNBAP UE Registration by TMSI rather than requiring IMSI** — and
the archive's own note is the reason to care: ***"it lives exactly on the path a UE takes when
first attaching through a NEW cell — which is the thing that has never once happened on our DPH."***
⚠️ **BOUND, theirs: our nano3G carries UEs fine without it, so it is not fatal in general.**

### ⛔ **WHAT THE ARCHIVE DOES *NOT* GIVE, STATED SO IT DOES NOT INFLATE THIS PAGE**
**It contains NO device-side 153 procedure.** ⇒ **The hardware/root half is still the original
author's published route, unreproduced here, exactly as the scope block above says.**
⚠️ **AND DO NOT USE `151prov.pcapng` / `151full.pcapng` AS A POSITIVE CONTROL** — the archive's
README retracts them: **150 mutual-TLS handshakes, ZERO application bytes, device-initiated FIN
8.7 ms after the server's `Finished`.** ***An instrument that has never once shown a success.***
📌 **Also in there: `csps.mp4`, a 124 s screen recording of that deployment carrying CS+PS** —
Wireshark plus an SDR on the Band 5 uplink, a full attach, and real GTP-tunnelled traffic.

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

---

## ⛔ Before you let this unit transmit

> ### ⛔ **STOP. THIS IS THE STEP THAT PUTS A TRANSMITTER ON LICENSED SPECTRUM.**
> Everything before this point was passive. **From here the cell radiates.**
> **Band 2 (1900 PCS) and Band 5 (850 Cellular) are refarmed and in active use** — empty of the
> old technology is not the same as vacant. There is a clean route (a **Part 5 experimental
> licence** in the US) and there is minimum power with physical containment. **You cannot have
> house-wide coverage and RF containment at the same time.**
> **Settle the PLMN before this step, not after** — a unit that ran on a carrier still carries
> that carrier's MCC/MNC. Use **999-99** or **001-01**, and verify it **on the air**.
> 📌 Full text: the spectrum section of the [README](../README.md).
> ### ☠️ **AND EMERGENCY CALLING DOES NOT WORK ON THIS CELL.**
> A handset that camps onto it will try to place **911 / 112 / 999 calls through it, and they
> will not complete** — with **no warning shown to the user.** It displays bars and looks like
> service. ⛔ **Not fixable with configuration:** a private core has no route to emergency
> services. ⇒ **Programmed SIMs you control, minimum power, physical containment** — so no
> handset you do not control can camp on. ☠️ **If anyone nearby might rely on a phone to call
> for help, do not run the cell.**
