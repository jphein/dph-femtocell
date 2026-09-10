# Reusing AT&T MicroCell femtocells (Cisco DPH-151 / DPH-153 / DPH-154)

AT&T shut down its UMTS network on **2022-02-22**. The MicroCell femtocells sold to
customers to fix indoor coverage stopped being able to do their job that day, and they
have been landfill-priced ever since — routinely under $15, often under $10.

They are not landfill. Underneath the Cisco badging they run **ip.access femtocell
firmware**, they speak **Iuh** natively, and every value that binds one to AT&T ships as
an editable placeholder. Pointed at an open-source core, one becomes a private UMTS cell.

> ### What has actually been made to work
> A **DPH-151** running as a private UMTS cell against an [Osmocom](https://osmocom.org)
> core (`osmo-hnbgw` + `osmo-msc` + `osmo-mgw` + `osmo-hlr`), carrying **voice and SMS**
> for four handsets, and **recovering unattended from a power cut in about 16 minutes**.
>
> Independently, a **DPH-153AT** has been reported registering with `osmo-hnbgw` and
> radiating UMTS after IPsec was disabled and its hardcoded NTP and HNB-GW addresses were
> repointed (Osmocom Discourse, `tempest`).

This repo is the write-up: what these devices are, how to get into one, how to bring it
up, and — most valuable of all — **the failure modes that cost us days**, in
[`docs/TRAPS.md`](docs/TRAPS.md).

---

## Is this for you?

**Yes, if** you want a small private 3G cell for handsets you already own, you are
comfortable with a serial console and a Linux shell, and you can operate it legally where
you live.

**No, if** you need LTE or 5G (these are UMTS-only), if your handsets are Band 1 (2100 MHz
— most of Europe and the UK), or if you cannot transmit legally. See
[`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) before buying anything.

### ⛔ Spectrum is the real constraint, and it is not a formality

These are **UMTS Band 2 (1900 MHz PCS)** and **Band 5 (850 MHz Cellular)** devices, and
neither band is vacant. **Read the “Before you transmit: spectrum” section below before you power a radio** — it is the section this repo would most like you to not skip.

⚠️ One temptation worth naming here: Band 5 propagates roughly 7 dB better than Band 2, which
makes it exactly the wrong thing to reach for when coverage disappoints. Better propagation is
less containment.

### ⛔ Never broadcast a real carrier's PLMN

A unit that ran on AT&T may still carry **MCC/MNC 310-410** in its live configuration.
Broadcasting that is impersonating a real network operator. Use a test PLMN — **999-99**
is ITU-reserved for exactly this and is what we use throughout; **001-01** is the 3GPP
test network. Change it *before* you enable the radio, and verify it on the air rather
than in the database (see [`docs/TRAPS.md`](docs/TRAPS.md) — the device has a trap here
where the database and the broadcast disagree).

---

## What it costs

| item | note |
|---|---|
| DPH-151 / 153 / 154 | typically **$8–15** used. Confirm the PSU is included. |
| 12 V DC PSU | **read the voltage off the unit's label** — do not guess. |
| 3.3 V USB↔UART adapter | buy a **3.3 V-only** part so a 5 V mistake is impossible. |
| Ethernet cable | — |
| GPS antenna | **probably not needed** — see [`docs/HARDWARE.md`](docs/HARDWARE.md). If you do fit one it must be **active**; a passive antenna will not lock and the failure is indistinguishable from the interlock being unbeatable. |
| a core network | free software, but you need a machine to run it on |

You also need **SIMs you can program** (and a reader) if you want handsets to treat the
cell as home. That is core-network territory and out of scope here; Osmocom's own
documentation and `pySim` cover it.

---

## Repo map

| path | what it is |
|---|---|
| [`docs/HARDWARE.md`](docs/HARDWARE.md) | the three models, what differs, what to buy, what not to |
| [`docs/ACCESS.md`](docs/ACCESS.md) | getting a shell, a console, or a management interface |
| [`docs/BRINGUP.md`](docs/BRINGUP.md) | commissioning → Iuh → a first call |
| [`docs/CONFIG.md`](docs/CONFIG.md) | the attributes that matter and what they do |
| [`docs/TRAPS.md`](docs/TRAPS.md) | ⭐ **the failure modes. Read this before you debug anything.** |
| [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) | when one of these is the wrong choice |
| `config/` | sanitised core-network config templates, with placeholders |
| `tools/` | scripts that generalise beyond one network |

---

## How to read the claims in here

This is written from one lab's logbook, and the logbook was wrong a lot. So:

- **Measured** means someone observed it on real hardware and wrote down the reading.
- **Inferred** means it follows from something measured but was not itself observed.
- **Reported** means someone else published it and we did not reproduce it.

Where a claim is uncertain, the uncertainty is **in the sentence**, not in a footnote —
because footnotes do not survive being quoted. If a statement here does not carry a hedge,
it is because it was measured.

Model scope is stated on every instruction that has one. The three models differ in ways
that matter, and **an instruction that is correct for one can destroy another** — see the
config-bank trap in [`docs/TRAPS.md`](docs/TRAPS.md) for a worked example.

---

## What this repo is *not*

It is not a copy of the lab notebook it was written from. That tree stays private: it holds
working private keys, device identifiers, and vendor firmware whose redistribution nobody
has assessed. Everything here is **rewritten** for a reader who has never seen that network
— which is also what makes it a guide rather than a logbook.

## ⚠️ Before you transmit: spectrum

These cells transmit on **licensed cellular spectrum**. The carriers that abandoned the
*networks* did not abandon the *licences* — UMTS Band 2 (1900 MHz) and Band 5 (850 MHz) are
refarmed and in active use for LTE and 5G today. Empty of the old technology is not the same
as vacant.

So a femtocell on your bench is not an unlicensed device the way a Wi-Fi access point is.
Two honest positions:

- **The clean route** is an experimental licence — in the US, [FCC Part 5](https://www.fcc.gov/general/experimental-licenses).
  It exists for exactly this, and it is not exotic.
- **The pragmatic route** that many people actually take is minimum transmit power, minimum
  antenna, and containment to a single room or a shielded enclosure — accepting a risk
  knowingly rather than not knowing there is one.

⭐ **The two goals are in direct conflict and it is worth saying so plainly: you cannot have
house-wide coverage *and* RF containment.** If your requirement moves from "a bench" to "the
whole house", that is not a power setting — it is a different decision, and it deserves to be
re-made rather than inherited.

Nothing here is legal advice. Rules differ by country; find out which apply to you.

## Scope: your hardware, your core

This is about making a femtocell **you own** serve a core **you run**. That is the whole subject.

It deliberately does not cover attacking, intercepting or impersonating anyone else's
equipment or network. Some of the same mechanisms would apply — that is true of most
networking knowledge — but the material here is organised around reuse, and working attack
payloads are not published, here or anywhere.

## Safety of this repo

`tools/pre-publish-check.sh` runs before every commit and exits non-zero if it finds key
material, device IMEIs (in **both** 15- and 14-digit forms — a management interface prints
them without the check digit, so a 15-digit search returns a clean, complete-looking zero),
private-key blocks, internal hostnames, or oversized binaries.

It carries its own **positive control**: it plants a key-shaped string, confirms it finds
it, and removes it. A scanner that cannot be shown to see a planted secret proves nothing
when it reports none. It also fails the run if the scanner wrote anything to stderr, because
a scanner that errored is a scanner whose zeros are meaningless.

## Prior art

The foundation is **fail0verflow's 2012 DPH-151 work** (UART header, SSH password,
the `wizard` UDP backdoor) — still the only substantial published teardown, and it
explicitly deferred the GPS and Iuh questions to a follow-up that never appeared. The
Osmocom Discourse threads on the DPH-153 are the other main source. This repo tries to
carry that forward rather than repeat it.

## Licence

**GPL-3.0.** See [`LICENSE`](LICENSE).

⚠️ The licence covers the **writing and the scripts in this repository**. It says nothing about
the femtocell firmware itself, which is ip.access's and is **not distributed here** — see
[`docs/HARDWARE.md`](docs/HARDWARE.md) for what you need to obtain yourself and from where.
