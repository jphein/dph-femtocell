# Hardware: the three models, and which one to buy

> ### ⭐ Short version
> **Buy a DPH-151 or a DPH-153. Do not buy a DPH-154 expecting to use it.**
> The 151 is the one we drove end to end. The 153 has the better *published* route.
> The 154 is a teardown, and every wall on it has been measured rather than assumed.

---

## ⚠️ First: "ip.access" or "Cisco"? Both, at different layers

This guide says **ip.access** a lot, because that is whose femtocell software stack is running
inside — the components, the management model, the config layout, the sibling nano3G hardware.

But when you go to **identify a unit**, everything in front of you will say **Cisco**:

```
the sticker          Cisco Systems
an OUI lookup on the MAC   Cisco SPVTG      <- for every OUI these units use
the on-device paths  a mix: both vendors appear
```

⇒ **ip.access designed the platform; Cisco shipped, badged and OUI-registered these units.**
Both names are correct and they are not in competition. **Where this guide helps you identify
hardware — a sticker, a MAC, a DHCP client name — it means the Cisco layer.** Where it talks
about the software stack, it means ip.access.

⚠️ If you look up an OUI and get "Cisco", that is not the guide being wrong.

---

## The three at a glance

| | **DPH-151** | **DPH-153** | **DPH-154** |
|---|---|---|---|
| **Board code** | `205F` | `224F` | unknown |
| **Radio SoC** | picoChip **PC7205**, ARM926EJ-S — *measured off the live unit* | picoChip **PC312/PC302** — from a JTAG guide | ⚠️ **unsettled — see below** |
| **Gateway SoC** | Ralink RT-series, MIPS 24K — *measured* | Ralink, same family — from a dump | *inferred* |
| **Software train** | **563.21.8** — *measured* | **579.11.x** | 🔴 **unknown**; "later than the others" is inference from a 2013 grant date, not a read |
| **Bands** | B2 / B5 — *measured on air on B2* | B2 / B5 | B2 / B5 — *measured from the FCC grant* |
| **Public firmware dump** | ✅ exists | ✅ exists | 🔴 **none, and no way to make one** |
| **GPS antenna port** | ✅ MCX | ✅ MCX | 🔴 deleted |
| **Root** | ✅ **achieved on both SoCs** | ✅ published route (needs JTAG) | 🔴 **never, by anyone** |

**All three are UMTS Band 2 (1900) and Band 5 (850).** Band is *not* a discriminator among
these three — unlike the nano3G, where it is the expensive mistake (see
[`ALTERNATIVES.md`](ALTERNATIVES.md)).

⚠️ **You cannot cross-flash.** The image loader gates on PCB number and refuses a mismatch —
*"did not match any PCB number found in the .SDP file."* A 151 or 153 image will not load on
a 154. These are three different boards.

---

## DPH-151 — the one that was made to work

This is the only one of the three that this write-up drove end to end on hardware in hand:
unauthenticated root, Iuh established, cell keyed, four handsets served, and unattended
recovery from a power cut.

**Measured throughput:** about **2.3 Mbit/s down, 0.28 Mbit/s up**. ⚠️ **The uplink asymmetry
is the absence of HSUPA, not a misconfiguration** — verified three ways, including the AP
rejecting the relevant attribute name outright and a handset independently reporting its data
classes as UMTS and HSDPA with HSUPA absent. Do not go looking for a setting to fix it.

## DPH-153 — the better-documented one

Someone else published a working route to this model first, and it is the one to follow if
you are working from public documentation rather than this repo.

> ### ⚠️ But the published route is **153-specific at the hardware layer**
> Its author is explicit: the procedure needs contact with a point on the underside of the
> board **that does not exist on the 151 and is different on the 154**. The *software* half
> transfers between models; the *JTAG/hardware* half does not.
>
> ⇒ Following the 153 route on a 151 will strand you at the hardware step.

**Extra kit for this route:** a JTAG adapter (a J-Link clone is enough, around $21) plus a
USB↔UART adapter.

## DPH-154 — buy it to take apart, not to use

Every wall below was **measured**, not assumed:

- **The `wizard` UDP backdoor is gone.** Port 14677 measured **closed**. This was the open
  question about the 154 and it now has a negative answer.
- **13 ports probed, 13 closed, 0 open** — and these are ICMP-unreachable rejects, i.e. the
  signature of a **firewall rule**, not of absent listeners.
- **It initiated nothing at all in 60 seconds of passive capture**, so the "catch it phoning
  home and answer as its management server" route has nothing to catch.
- **No public firmware dump exists, and all four routes to making one are blocked** — with a
  neat circularity: the only software dump path requires the very access the dump is meant to
  provide.
- **No root has ever been confirmed, publicly or here.** It is a 2019 build; the public
  exploits are 2012–2018 and target the 151/153.

> ### ⚠️ Do not repeat "the DPH-154 is not picoChip" as settled — we would have, and it is wrong
> A teardown identifies an **AD9365** transceiver with Band 2 and Band 5 power amplifiers.
> Another source attributes a picoChip part. **These are reconcilable rather than
> contradictory: the AD9365 is the RF transceiver, and a picoChip part would be the
> processor/baseband.** They are different components. The 154's SoC identity is genuinely
> unsettled, and this repo is not going to settle it.
>
> The 154 is still the wrong buy — but for the measured reasons above, not for this one.

---

## The ip.access nano3G — the sibling these findings are cross-checked against

**You are not being told to buy one.** It costs **$180–200** against the MicroCell's **$10**, and
[`ALTERNATIVES.md`](ALTERNATIVES.md) covers when that premium is worth paying (and the
part-number band trap that makes buying one risky anyway). It is here because **several findings
in this repo were measured on one**, and you are entitled to know which, and how far they carry.

**What it is:** ip.access's own product — the thing Cisco badged. The MicroCell is a rebadged
sibling, not a separate design. **That is the structural bet this whole repo rests on**, and it
is the reason the effort was tractable at all: the DPH is not a new device to reverse, it is a
relative of one that was already solved and publicly documented.

| | **DPH-151** | **ip.access nano3G S8** |
|---|---|---|
| **Software train** | `563.21.8` | `563.16.0` — ⭐ **same `563` family** |
| **Processors** | **two SoCs**, radio + an added gateway | 🔴 **one address, no gateway SoC in front of it** — *measured* |
| **Root filesystem** | — | **cramfs, read-only**; a separate **jffs2** partition is the only writable storage |
| **Documented by** | this repo, and fail0verflow 2012 | ⭐ **Osmocom's own wiki** — an independent, maintained source |
| **Price** | ~$10 | $180–200 |
| **Bands** | B2 / B5 on all three | ⚠️ **depends on the part-number suffix** — see [`ALTERNATIVES.md`](ALTERNATIVES.md) |

> ### ⭐ The architectural difference explains one of this repo's own traps
> **[Trap 3 — the AP advertises an address it cannot be reached at](TRAPS.md#3-the-ap-advertises-an-address-it-cannot-be-reached-at)
> is a consequence of the MicroCell's second SoC**, which sits in front of the radio half and
> NATs it. **The nano3G is a single-address device and does not exhibit it.**
>
> ⇒ So when a nano3G-measured finding in this repo concerns *addressing or reachability*, **treat
> it as the simple case and assume your DPH adds a layer.** When it concerns the *ip.access
> software stack* — attributes, config banks, the boot order, the management model — it is the
> same code and it transfers much more readily.

### Which findings here came from a nano3G, and why that is worth knowing

Every trap in [`TRAPS.md`](TRAPS.md) names the device it was measured on, and several name this
one. **Two of them are opposites across the two devices**, which is the best possible argument for
reading the scope line rather than the instruction:

- **[Trap 2 — which config bank is live](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)**:
  on the nano3G measured here it was bank 2; on the DPH-151 it was bank 1, and that unit's bank 2
  was **empty**. ⇒ **A correct instruction for one unit destroys the other.** Read the symlink.
- **[Trap 4 — the CSG indicator](TRAPS.md#4-csgindicator-reads-false-in-the-database-and-broadcasts-true-on-the-air)**:
  measured on a nano3G off the air, **never read on a DPH by anyone.** The fix is now known and is
  in that entry; whether a DPH needs it is genuinely open.

⚠️ **It cuts the other way too.** A nano3G finding is *not* a DPH finding, and this repo tries to
say so every time. Where a nano3G result is all there is, that is stated in the entry rather than
quietly generalised — because **the two devices have already been shown to differ on the one
setting most likely to brick a bring-up.**

> ### ⛔ One thing the nano3G does **not** give you: a cheaper route in
> It is the better-documented device and it is the one Osmocom's wiki describes, so it is the
> reference for the *software* side. **It is not a cheaper or easier device to get a shell on**,
> and nothing in this repo suggests buying one to practise on. If the $10 unit is what you have,
> the $10 unit is what this repo is about.

---

## Firmware: where it comes from, and why none of it is here

> ### ⛔ This repository distributes no firmware, no extracted binaries, and no vendor
> ### archives — and it never will.
> Owning a device does not carry a right to republish its firmware, and no vendor source
> release covers the parts that matter here. **Do not ask us for an image; we would be wrong
> to send one.**

**You do not need one.** The bytes are already on the device in front of you. What you need is
to know *which* bytes are the right ones, and that is a version string you can read yourself:

```sh
ls /opt/ipaccess/            # the ip.access components carry the train in their filenames
```

Known trains, for comparison against your own unit:

| model | train seen here |
|---|---|
| DPH-151 | **563.21.8** (an alternate bank on the same unit held a much older build) |
| DPH-153 | **579.11.x** |
| ip.access nano3G (sibling hardware) | 563.16.0 |

⭐ **The DPH-151 and that nano3G are the same `563` train.** That is the structural finding
this whole effort rests on: the MicroCell is not a new device to reverse, it is a rebadged
sibling of one that was already solved. ⚠️ The DPH-153's `579` is a **different** train, so its
findings do not automatically transfer — and **neither transfers to the DPH-154**, whose train
is unknown.

⚠️ **We are not publishing hashes of these images**, because we have not computed them over a
clean reference we could stand behind — a hash you cannot trace to a known-good source is
worse than none. If you build such a reference, that is a genuinely useful thing to publish.

### Prior-art dumps
Two public `binwalk` extractions of DPH-151 and DPH-153 firmware exist on GitHub (search
`dph151-binwalk` / `dph153-binwalk`) and are the basis of most published analysis, including
much of what informed this repo.

> ### ☠️ If you use them, know this: those public dumps contain a **real device private key**
> ### belonging to somebody else's unit.
> Do not use it, do not copy it into your own work, and do not treat it as a shortcut. It is
> noted here only so nobody mistakes it for a supplied credential. **Generate your own.**

⚠️ **And do not cross-flash from them.** See the PCB-number gate above.

---

## What else you need

### The PSU — a check, not a purchase
These take a barrel-jack brick and are frequently listed "no cables".

⛔ **Read the voltage and polarity off the unit's own label. Do not guess and do not
substitute "close enough"** — wrong polarity or voltage kills the board instantly. This is
much better discovered at unboxing than at power-on.

### A 3.3 V-only USB↔UART adapter
**Buy a part that physically cannot do 5 V**, so the mistake is impossible rather than merely
avoidable. Cheap adapters are often 5 V or unmarked.

- The **Ralink side is 3.3 V TTL** — established from the SoC family.
- 🔴 **The picoChip side's logic level was never measured here. Measure it before connecting.**

> ### ⭐ The best single piece of advice in this whole repo: **make your first serial session
> ### receive-only.**
> Wire **device TX → adapter RX**, and **GND → GND**. Do **not** connect the adapter's TX at
> all, and do not connect VCC.
>
> The 5 V hazard lives entirely on the line running *from* the adapter *to* the device. With
> TX unconnected, **even a 5 V adapter cannot damage the SoC** — so you can start capturing
> the boot log before you have proved anything about your adapter or about the picoChip's
> logic level. It also sidesteps a historically flaky serial *input* path on these boards
> (the author of the 153 route went to JTAG precisely because serial input never worked).

**Header and pinout (151, from fail0verflow):** header **JP1** — pin 1 RX, pin 2 TX, pin 3 GND.

**Baud:** the widely-quoted **56700 is almost certainly a transposed digit** — 56700 is not a
standard rate and **57600** is. Try `57600`, then `115200`, then the literal `56700`, then
`38400`, `9600`. ⚠️ A one-digit transposition produces garbage that reads **exactly** like
wrong pins or a dead UART, so do not conclude anything about your wiring until you have swept
the rates.

### Jumpers and probes
0.1" female Dupont jumpers plus test hooks or pogo probes, so the first attempt needs **no
soldering** and can be abandoned cleanly.

### An isolated network segment — before first power-on
Not a purchase, but do not skip it. See [`BRINGUP.md`](BRINGUP.md).
✅ **Verify the isolation with `dig` and `ping`. Do not trust the config.**

---

## 🔴 GPS: you probably do not need an antenna, and the reason matters

The internet will tell you these devices are hard-gated on a GPS fix. That is **true of the
interlock's existence and false about whether it will stop you.**

```
MEASURED, DPH-151:  registered, keyed its cell, and served four handsets
                    with GPS.Current.Locked = 0 and SatellitesLocked = 0
                    THROUGHOUT. 210 samples. The cell has never had a fix.
```

**Why both things are true at once:**

| claim | status |
|---|---|
| A GPS interlock exists in the vendor's userspace code (2 of 6 service-disable reasons) | ✅ measured in the binary |
| It is a **regulatory location gate**, enforced during **the carrier's** provisioning | ✅ measured |
| It does not latch — it re-arms and clears | ✅ measured at instruction level |
| **You never complete the carrier's provisioning**, so the check is never submitted to | ✅ and this is why it never fires |
| A DPH-151 serves handsets with no GPS fix, ever | ✅ **measured, and decisive** |

⭐ **And the reason everyone believes otherwise is worth knowing:** the management interface
reports `"Service disabled: boot"`, which is **literally true** — the cell has not completed
parameter selection, so it has not *reached* the GPS gate or any other gate. **The device was
saying "I have not started yet" and three people read it as "something is blocking me."**

### If you do buy an antenna, buy an **active** one
> ### ⚠️ A passive antenna gives no lock, and no lock looks **exactly** like "the interlock
> ### cannot be satisfied."
> The receiver supplies bias voltage up the coax and expects the antenna's amplifier to make
> up cable loss. Save money here and you get a confident wrong answer to the one question the
> purchase existed to settle.

Specification: **active, MCX male** (or an active SMA antenna plus an SMA-female→MCX-male
pigtail, usually cheaper and reusable), **3–5 V bias**, roughly **26–28 dB gain**.
⚠️ **The bias voltage is inferred from typical practice — the port was never measured.** Most
active GPS antennas accept 2.7–5.5 V, so the risk is low, but it is an inference.

⇒ **Cheap insurance, not a prerequisite.** Do not treat a missing MCX port as disqualifying,
and do not sequence a purchase ahead of a bring-up attempt.

⚠️ **The one scenario where GPS becomes load-bearing:** the assisted-GPS server these units
use is dead, and the ephemeris cache is deleted on every shutdown — so **every cold boot is a
cold start** with no assistance. If the gate ever does engage on your unit, an unattended boot
would need to get a fix within roughly 20 minutes, cold. That is a sky-view question, and it
is the part that would fail quietly.
