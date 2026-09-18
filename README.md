# Private UMTS from retired femtocells — Cisco DPH-151 / DPH-153 / DPH-154 and the ip.access nano3G

AT&T shut down its UMTS network on **2022-02-22**. The MicroCell femtocells sold to
customers to fix indoor coverage stopped being able to do their job that day, and they
have been landfill-priced ever since — routinely under $15, often under $10.

They are not landfill. Underneath the Cisco badging they run **ip.access femtocell
firmware**, they speak **Iuh** natively, and every value that binds one to AT&T ships as
an editable placeholder. Pointed at an open-source core, one becomes a private UMTS cell.

> ### What has actually been made to work
> **Two devices, both taken end to end here, against the same [Osmocom](https://osmocom.org)
> core** (`osmo-hnbgw` + `osmo-msc` + `osmo-mgw` + `osmo-hlr`):
>
> - A **Cisco DPH-151** as a private UMTS cell carrying **voice, SMS and packet data** for four
>   handsets — **2.31 Mbit/s down, 0.28 Mbit/s up, measured** — and **recovering unattended from a
>   power cut in about 16 minutes.** → [`docs/BRINGUP.md`](docs/BRINGUP.md)
> - An **ip.access nano3G S8**, taken from a **sealed, un-commissioned box** through factory reset,
>   commissioning, root, an Iuh transplant and first light, to **a second cell carrying voice
>   alongside the first**, carrying **voice and packet data.**
>   → [`docs/BRINGUP-NANO3G.md`](docs/BRINGUP-NANO3G.md)
>
> ⭐ **Packet data works on both** — `osmo-sgsn` + `osmo-ggsn`, real PDP contexts, real throughput.
> **The traps that cost the most there are core-side, not radio-side** —
> [62](docs/TRAPS.md#62-packet-data-depends-on-an-address-that-exists-at-runtime-and-in-no-configuration-file),
> [63](docs/TRAPS.md#63-a-host-route-fixes-the-voice-symptom-and-cannot-fix-the-data-one-because-the-rejection-is-a-source-address-check)
> and [64](docs/TRAPS.md#64-three-handsets-three-unrelated-faults-one-symptom--and-the-fix-is-a-log-filter).
>
> Independently, a **DPH-153AT** has been reported registering with `osmo-hnbgw` and
> radiating UMTS after IPsec was disabled and its hardcoded NTP and HNB-GW addresses were
> repointed (Osmocom Discourse, `tempest`). **Reported, not reproduced here** —
> [`docs/BRINGUP-DPH153.md`](docs/BRINGUP-DPH153.md).
>
> ✅ **The DPH-154 HAS a working route in** — no memory-corruption exploit, no JTAG, no case
> opening, no serial console. **You stand up the management server it is already looking for**
> (its own `REDIRECTOR_URL` names the host and the port), **and then write one CWMP field that the
> device copies into its root-sourced environment file with no escaping.** ⭐ **It rides the
> session the device OPENS TO YOU, so the unit's total inbound firewall never comes into it.**
> **Access is solved. The RADIO is separately gated** by a per-unit tamper bit, SET on the unit
> measured here — so the final phase is unproven and is labelled as such.
> [`docs/BRINGUP-DPH154.md`](docs/BRINGUP-DPH154.md).
>
> 📌 **This line read *"no known route in"* until 2026-09-16.** The guide it points at had
> already been corrected; these citations had not. ⭐ *A correction that updates one mention of a
> fact leaves the others reading as confirmation* — and the stale copy was on the front page.
>
> ⭐ **The nano3G is not a footnote here.** It is ip.access's own product — the thing Cisco badged —
> and it is the reference for the *software* half of every model in this repo. **Where the two
> differ, both are stated.** It costs $180–200 against the MicroCell's $10, and
> [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) covers when that is worth paying.

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

### SIMs — what to buy, and what you do *not* need

You need **SIMs you can program**, so handsets treat your cell as *home* rather than as a roaming
network. **Two items, and neither is exotic:**

| item | what | note |
|---|---|---|
| **Blank writable USIMs** | e.g. [Gialer 30-pack, writable/programmable USIM, 4G LTE / WCDMA / GSM, 2FF+3FF+4FF](https://www.amazon.com/dp/B08BWSS8L3) — the cards used here | multi-form-factor, so one card fits any handset |
| **A PC/SC smartcard reader** | any ordinary CCID reader | ⭐ **NOT a special "SIM programmer".** The one used here is an **Alcor Micro AU9540**, driven by `pcscd` |

⇒ ⭐ **There is no dedicated programmer and no soldering.** Writing is done in software with
[`pySim`](https://osmocom.org/projects/pysim) — for these cards, the **`gialersim`** profile.

> ### ⛔ THREE THINGS THAT WILL COST YOU A CARD IF NOBODY TELLS YOU
> - **Write Milenage (K + OPc). Never COMP128v1.** A 3G/UMTS cell needs Milenage; COMP128v1 is a 2G
>   algorithm and a card written that way will not authenticate here.
> - **Identify the card by ICCID before every write.** Blank cards are **physically
>   indistinguishable**, and writing the wrong one is not always recoverable.
> - **There is a one-way door.** Card programming has irreversible steps — a wrong ADM key, or an
>   algorithm binding written wrong, can lock a card permanently. **Read your tooling's warnings
>   before the first write, not after.**

📌 **The core-network side of this** — HLR entries, IMSI↔MSISDN, auth data — is Osmocom's
documentation, not this repo's.

---

## Repo map

| path | what it is |
|---|---|
| **[`docs/MATRIX.md`](docs/MATRIX.md)** | ⭐ **all four models side by side** — FCC power per band, silicon, HSUPA, tamper state, config-bank scheme |
| [`docs/HARDWARE.md`](docs/HARDWARE.md) | the four models, what differs, what to buy, what not to |
| [`docs/ACCESS.md`](docs/ACCESS.md) | getting a shell, a console, or a management interface |
| **[`docs/BRINGUP.md`](docs/BRINGUP.md)** | **DPH-151** — commissioning → Iuh → a first call. **Also the router to the other three.** |
| **[`docs/BRINGUP-NANO3G.md`](docs/BRINGUP-NANO3G.md)** | **ip.access nano3G S8** — sealed box → root → a cell carrying voice |
| **[`docs/BRINGUP-DPH153.md`](docs/BRINGUP-DPH153.md)** | **DPH-153** — the published route, and what transfers from here |
| **[`docs/BRINGUP-DPH154.md`](docs/BRINGUP-DPH154.md)** | **DPH-154** — become its ACS, then inject through `LogUpload.Tuning`; access solved, radio tamper-gated |
| [`docs/CONFIG.md`](docs/CONFIG.md) | the attributes that matter and what they do |
| [`docs/TRAPS.md`](docs/TRAPS.md) | ⭐ **the failure modes. Read this before you debug anything.** |
| [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) | when one of these is the wrong choice |
| `config/` | sanitised core-network config templates, with placeholders |
| `tools/` | scripts that generalise beyond one network |
| `_config.yml` | GitHub Pages settings. **The file does not enable Pages** — that is a repo-settings decision. |

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

⚠️ **And "model" here includes one device that is not a MicroCell at all.** Some findings were
measured on an **ip.access nano3G** — the product Cisco badged as the DPH — because it runs the
same `563` software train and was available to test against. **Entries that came from one say
so** — with one honest caveat: where we could establish the software family but not the specific
model, an entry says *"an ip.access unit"* rather than naming the nano3G, because **inventing an
attribution in a repo whose subject is that instructions do not transfer between models would be
worse than the vagueness.** Where a nano3G result is all there is, the entry says that too rather
than quietly generalising it: the two devices have already been shown to be **opposite** on the single setting
most likely to brick a bring-up. See
[`docs/HARDWARE.md`](docs/HARDWARE.md#the-ipaccess-nano3g--the-sibling-these-findings-are-cross-checked-against)
for what transfers and what does not.

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

Nothing here is legal advice. Rules differ by country; find out which apply to you.

## Scope: your hardware, your core

This is about making a femtocell **you own** serve a core **you run**. That is the whole subject.

> ### ⛔ **ONE CONSTRAINT ON *YOUR CORE* BEFORE YOU BUILD IT — AND IT IS THE ONE THAT BITES LATER**
> **These devices ship a 2008 TLS stack.** A DPH-154 offers **TLS 1.0 only, exactly one cipher
> suite (`0x002f` / `TLS_RSA_WITH_AES_128_CBC_SHA`), and no extensions.**
> ⇒ ⭐⭐ **One suite means there is no negotiation margin at all.** Any modern default, distro crypto
> policy, or `SECLEVEL` bump removes the *only* thing it can speak, and the handshake does not
> degrade — it ends.
> ### ☠️ **THE FAILURE YOU SHOULD ACTUALLY PLAN FOR IS NOT SETUP. IT IS A ROUTINE UPGRADE, MONTHS LATER.**
> **You will get this working. Then you will upgrade the OS or tighten TLS for an unrelated service
> on the same host, and every femtocell will stop managing at once** — none of them touched.
> ⛔ **It presents as *"the devices died"*, which sends you to the hardware.** ⭐ **Simultaneity is
> the tell: N independent devices do not fail in the same minute — the thing that changed is the one
> thing they share, which is your core.**
> ✅ **So write the requirement down on the CORE, next to whatever runs its upgrades — not in the
> femtocell notes.** *The person typing `apt upgrade` is not reading this page.*
> 📌 Mechanism, probe and the way `openssl s_client` misreports it:
> [trap 24](docs/TRAPS.md#24-your-tls-server-is-too-modern-to-talk-to-it). **Same class as the
> DPH-151's SSH needing the legacy cipher set — an obsolete peer whose requirements are invisible
> until maintenance removes them.** ⚠️ **The SSH one fails loudly at your prompt. This one fails on a
> device with no screen.**

It deliberately does not cover attacking, intercepting or impersonating anyone else's
equipment or network. Some of the same mechanisms would apply — that is true of most
networking knowledge — but the material here is organised around reuse, and working attack
payloads are not published, here or anywhere.

⚠️ **One root path is described in full**, and the reason is that a reader who owns one of these
needs to be able to **close** it. The ip.access nano3G's management console is a root path, and
[`ACCESS.md`](docs/ACCESS.md#route-6--the-nano3gs-dmi-console-where-the-management-plane-is-the-root-path) gives the injection sink, the boot-script branch that gates the port, and
the one-write defence — **in enough detail to verify on your own unit, because a description too
vague to check is not documentation** — while stopping short of an assembled article.

📌 **Context, stated so the judgement is visible rather than implied:** this hardware generation
has **no live network and no vendor left to ship a fix.** AT&T's 3G service ended in February
2022, and these are surplus units in the hands of the people reusing them — which is also the
audience for this page. **The thing that helps them is the mechanism stated accurately**,
including that the obvious hardening step closes the console you were using.

## Safety of this repo

`tools/pre-publish-check.sh` runs before every commit and exits non-zero if it finds key
material, device IMEIs (in **both** 15- and 14-digit forms — a management interface prints
them without the check digit, so a 15-digit search returns a clean, complete-looking zero),
private-key blocks, internal hostnames, or oversized binaries.

It carries its own **positive control**: it plants a key-shaped string, confirms it finds
it, and removes it. A scanner that cannot be shown to see a planted secret proves nothing
when it reports none. It also fails the run if the scanner wrote anything to stderr, because
a scanner that errored is a scanner whose zeros are meaningless.

`tools/check-links.py` validates every relative link and `#anchor` across the Markdown. These
pages cross-reference each other constantly, and once they are served as a site a broken anchor
is broken navigation rather than a cosmetic miss.

⚠️ **It is here partly as a worked example of the failure it guards against.** Its first
version reimplemented GitHub's heading-to-anchor rule and got it subtly wrong — it collapsed
runs of whitespace, so a heading containing an em-dash or an ampersand produced one hyphen
where GitHub produces two — and it confidently reported five good links as broken. Two things
let that through, and the second is the interesting one:

- its docstring claimed a positive control that its code did not implement; what stood in for
  it was the ordinary run, which is circular — a wrong rule produces broken links, and the code
  reported those as broken links rather than as a failed control;
- ⭐ **and the control it *should* have had would have passed anyway**, because at that moment
  no heading in this repo contained an em-dash. **The corpus never exercised the rule under
  test.** A control that cannot fail is decoration.

It now checks the rule against heading/anchor pairs **measured** from rendered documents that
do contain the awkward cases, rather than against this repo's own convenient sample.

## Prior art

The foundation is **fail0verflow's 2012 DPH-151 work** (UART header, SSH password,
the `wizard` UDP backdoor) — still the only substantial published teardown, and it
explicitly deferred the GPS and Iuh questions to a follow-up that never appeared. The
Osmocom Discourse threads on the DPH-153 are the other main source. This repo tries to
carry that forward rather than repeat it.

⭐ **For the ip.access side, the reference is [Osmocom's own nano3G
documentation](https://osmocom.org/projects/cellular-infrastructure/wiki)** — an independent,
maintained account of the same software stack, covering the management interface and the
configuration sequence. Where this repo describes that stack, it is correcting or extending a
source that already exists rather than publishing a new one. **`sysmocom`'s shipped femtocell
configuration is the other artefact worth reading**: it settles at least one question in
[`docs/CONFIG.md`](docs/CONFIG.md) that our own measurements only corroborated.

## Licence

**GPL-3.0.** See [`LICENSE`](LICENSE).

⚠️ The licence covers the **writing and the scripts in this repository**. It says nothing about
the femtocell firmware itself, which is ip.access's and is **not distributed here** — see
[`docs/HARDWARE.md`](docs/HARDWARE.md) for what you need to obtain yourself and from where.
