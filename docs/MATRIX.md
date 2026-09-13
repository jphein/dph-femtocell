# The four-model matrix

**Side by side: the three Cisco/AT&T MicroCells and the ip.access nano3G S8.** This is the table we
actually use to decide things, with the per-unit columns removed — no addresses, serials, MACs or
deployment identifiers, because those are facts about our network and not about your hardware.

> ### 📋 HOW TO READ THE EVIDENCE MARKERS
> | | meaning |
> |---|---|
> | ● | **measured** on a live unit here, or read from a primary public record (FCC grant) |
> | ○ | **read** from a device banner, config file or vendor document |
> | ◐ | **partially measured** — the value is real but its conditions were narrower than the row implies |
> | ⊘ | **not checked.** Never asked of that unit. **Not the same as "absent".** |
> | — | not documented, and nobody has looked |
>
> ⭐ **A `⊘` is the most useful cell in the table** and the one most likely to be misread as a
> negative result. **It means nobody asked.** See
> [trap 59](TRAPS.md#59-the-manual-for-your-device-family-may-not-cover-your-model-and-the-one-that-does-has-a-different-version-number)
> for what happens when an absence is read as an answer.

---

## Identity

| | **DPH-151** | **DPH-153** | **DPH-154** | **nano3G S8** |
|---|---|---|---|---|
| **Vendor / OEM** | Cisco brand, Gemtek OEM ● | Cisco brand, Gemtek OEM ● | Cisco Systems ● | ip.access ltd ● |
| **Board code** | 205F ○ | 224F ○ | U58B243-T00 Rev 1.0 ● | 234H ○ |
| **Firmware train** | 563.21.8 ○ | 563.16.0-era ◐ | 9.0.0 ● (3G module: 579.11.x) | N3G_2.0.5 ○ |
| **Model codes seen** | `DPH151-AT` — dual band, 2 port ● | `SC-DPH153-LA` — dual band, 1 port ● | `SC-DPH154-4U-ATT` ○ | `QGGIPA237B` / `237C` / `243B` ○ |
| **FCC ID** | `MXF-3GFP980217` ● | `MXF-DPH153AT` ● | `LDKDPH150856` ● | `QGGIPA237B` ● |
| **FCC grant date** | 2009-05-14 ● | 2011-10-13 ● | 2013-10-21 ● | 2011-05-11 ● |

⚠️ **The nano3G's model suffix is a buying trap.** `237B` is UMTS Bands 2 & 5; **`237C` is the Band 4
variant** and **no US handset in this project can see it.** It commissions perfectly normally and is
then silently useless. ⭐ **Trust the sticker on the unit, not the listing and not the paperwork** —
we hold a unit whose vendor note records the wrong FCC ID.

---

## ⭐ Radio power — the row that decides coverage

**From the FCC grants. Public record, not our measurements.**

| | **DPH-151** | **DPH-153** | **DPH-154** | **nano3G S8** |
|---|---|---|---|---|
| **Band 2 (1900)** | 0.0112 W = **+10.5 dBm** ● | 0.030 W = **+14.8 dBm** ● | 0.310 W = **+24.9 dBm** ● | 0.320 W = **+25.1 dBm** ● |
| **Band 5 (850)** | 0.0055 W = **+7.4 dBm** ● | 0.020 W = **+13.0 dBm** ● | 0.107 W = **+20.3 dBm** ● | 0.500 W = **+27.0 dBm** ● |
| **Hardware ceiling, as configured** | 70 = +7.0 dBm = 5.0 mW ● | ⊘ | ⊘ — runtime-supplied | 130 = +13.0 dBm = 20 mW ○ |

> ### 🎯 **The DPH-151 is the weakest of the four by a wide margin — about 14.6 dB below the nano3G
> ### on Band 2.** That is roughly a 29× difference in radiated power.
> ⇒ ⭐ **For a one-room, deliberately-contained cell that is a feature, not a defect.** The 151's
> low ceiling is the reason it is easy to keep inside a single room. **If you want house-wide
> coverage it is the wrong unit, and no configuration will fix that.**
> ⚠️ **And the hardware ceiling row is not the FCC row.** What a unit *may* emit under its grant and
> what its firmware will *let you configure* are different numbers — **read your own unit's ceiling
> live rather than copying one from this table.**

📌 **One measured data point, for calibration:** a DPH-151 configured at the **floor** of its range
radiated **−10.0 dBm (0.1 mW)**. ⇒ **These devices can be turned down a very long way**, which is the
single most useful fact for legal containment.

---

## Silicon and RF

| | **DPH-151** | **DPH-153** | **DPH-154** | **nano3G S8** |
|---|---|---|---|---|
| **Processor** | picoChip PC7205 · ARM926EJ-S rev 5 ● | radio: PicoChip PC312-HXC · network: Ralink RT2 ● | baseband: picoChip (U-Boot is picoChip-patched) ◐ | picoChip PC7302 · ARMv6 ◐ |
| **RF front end** | — | — | transceiver **Analog Devices AD9365**, PAs AWB7125 ● | — |
| **Memory** | 61,484 kB total · **no swap** ● | ⊘ | DRAM 128 MiB · NAND 256 MiB ● | ⊘ |
| **Flash layout** | 15 MTD partitions, raw ● | ⊘ | `rwstore` mtd=8 · 11 MiB UBI ● | ⊘ |
| **Live config bank scheme** | `config_bank_1` ● | ⊘ | ⭐ **a third scheme — named UBI volumes** ● | `config_bank_2` ○ |

> ### ⛔ THE CONFIG-BANK ROW IS THE ONE THAT DESTROYS CELLS
> **Three models, three different answers, and the 154 does not use numbered banks at all.**
> ⇒ **Read the symlink on your own unit. Never carry a bank number across models** —
> [trap 2](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell).

⚠️ **On the 154's silicon:** an AD9365 transceiver and a picoChip part are **not contradictory** —
the AD9365 is the RF transceiver and a picoChip part would be the baseband. **Different components.**
The 154's full SoC identity is genuinely unsettled.

---

## Capability

| | **DPH-151** | **DPH-153** | **DPH-154** | **nano3G S8** |
|---|---|---|---|---|
| **Simultaneous voice** | — not documented | ⊘ | **4 UE contexts** ● | **8 calls** ○ |
| **HSDPA** | configured 3600 kbps ● | — | exposed, unread ● | **21 Mbit/s** ● |
| **HSUPA** | 🔴 **NO** — 0 controls in 898 attributes ● | — | exposed, unread ● | ✅ **YES — 5.7 Mbit/s** ● |
| **Downlink, measured here** | **2.31 Mbit/s** ● (64 % of the HSDPA 3.6 ceiling) | — | ⊘ radio never up | **0.48–0.71 Mbit/s** ● (two handsets, see below) |
| **Uplink, measured here** | **0.28 Mbit/s** ● (73 % of the R99 384k ceiling) | — | ⊘ radio never up | ⊘ not separately measured |

> ### ⭐ HOW "IS IT ACTUALLY HSDPA?" WAS SETTLED WITHOUT READING A SINGLE BEARER ATTRIBUTE
> A first measurement on the nano3G came back at **~300 kbit/s** — below the **R99 ceiling of 384
> kbit/s** — which is exactly what a cell that had silently fallen back to R99 would produce, on
> hardware rated far higher. **Two things could explain it and they need different fixes.**
> ```
> first try, mid-reattach      37 kB/s  = ~300 kbit/s     <- below the R99 ceiling
> settled, same handset        89 kB/s  = ~711 kbit/s     <- ABOVE it
> second, independent handset  60 kB/s  = ~484 kbit/s     <- ABOVE it
> ```
> ⇒ ✅ **Two independent handsets both exceeded the R99 ceiling, so the bearer cannot be R99.** The
> low first number was the **re-attach**, not the bearer type.
> ⭐ **The method is the transferable part: a capability ceiling makes a rate into a discriminator.**
> You do not need to read which bearer type is in use if you can show the throughput is impossible
> for the one you are worried about. ⚠️ **But only in one direction** — exceeding the ceiling rules
> R99 *out*; falling below it proves nothing, because a good bearer on a bad link looks identical.
> ⛔ **And never take the first measurement after a re-attach as the answer.** Both cells produced a
> misleadingly low figure in the settling window, and on a cell that has never carried data before,
> that figure is maximally convincing.

⚠️ **These nano3G figures are well under its rated capability**, and no conclusion is drawn from
that here: they were taken minutes after the cell first carried data, at a deliberately low
transmit setting, on handsets that had just rescanned onto it. **Throughput tracks the link.**
**Treat the row as "HSDPA confirmed active", not as a benchmark.**

⇒ ⭐ **HSUPA is the nano3G's real advantage**, and it is a hardware/firmware capability rather than a
setting — **the 151 exposes no control for it anywhere in 898 attributes.** If uplink throughput
matters to you, that row is the decision.

---

## Access and state

| | **DPH-151** | **DPH-153** | **DPH-154** | **nano3G S8** |
|---|---|---|---|---|
| **Serial console** | ✅ **enabled** — `console=ttyS0,115200` ● | — | ✅ **J4 pin 4 = TX**, 115200 8N1 ● | ⊘ never read on ours |
| **Tamper state** | ⊘ never asked | ⊘ | 🔴 **`X_00000C_Tampered = 1` — AND IT IS ENFORCED** ● | ⊘ never asked |
| **Boot time to kernel** | ⊘ | ⊘ | ~5 s power-on → `Starting kernel` ● (n=5) | ⊘ |
| **Route in** | proven here | published by someone else | **provider emulation, no exploit** | proven here |
| **Guide** | [`BRINGUP.md`](BRINGUP.md) | [`BRINGUP-DPH153.md`](BRINGUP-DPH153.md) | [`BRINGUP-DPH154.md`](BRINGUP-DPH154.md) | [`BRINGUP-NANO3G.md`](BRINGUP-NANO3G.md) |

> ### 🔴 THE TAMPER ROW IS THE MOST EXPENSIVE CELL IN THIS TABLE
> A 154 with that bit set **will provision, accept configuration, and refuse to transmit** —
> `FAPService.Enabled` is rejected with FAULT 9003/9007. **Every other instrument reads healthy.**
> ⛔ **The latch is one-way, and OPENING THE CASE IS WHAT TRIPS IT** — the jumper pattern is one-hot
> with six candidates, so a guess is far more likely wrong than right.
> ✅ **Buy one that has never been opened, and do not open it.** The working route needs no case
> access. 📌 [trap 41](TRAPS.md#41-opening-the-case-can-destroy-a-factory-configuration).

---

## What this table is not

⛔ **It is not a claim that the four are interchangeable.** Two rows here — the config-bank scheme and
the serial console — **already differ in ways that destroy a bring-up if carried across.**

⚠️ **And the `⊘` cells are not gaps in the devices. They are gaps in what we asked.** Several of them
would take one command on a unit we do not have. **If you own one of these and fill a cell in, that
is a genuinely useful contribution** — especially the 153 column, which is documentary here because
nobody in this project has held one.
