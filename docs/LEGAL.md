# Operating one of these legally

**This page is not legal advice, and it is written from a US point of view.** It is the
practical checklist one lab worked through. **Rules differ by country — find out which apply
to you.**

⭐ **The short version: the writing is not your risk. The transmitter is.** Reading, buying,
opening, rooting and reconfiguring a femtocell you own are not the parts that carry exposure.
**Energising the radio is.**

---

## 1. ⛔ The transmitter — the only item here with real enforcement history

These are **UMTS Band 2 (1900 MHz PCS)** and **Band 5 (850 MHz Cellular)** devices. **Both
bands are licensed, and both are in active use today** — the carriers refarmed them for LTE
and 5G when they retired UMTS. ⚠️ **Empty of the old technology is not the same as vacant.**

In the US, **47 U.S.C. § 301** is the operative provision: transmitting without a licence is
prohibited. A femtocell is **not** an unlicensed device the way a Wi-Fi access point is.

### ✅ The clean route: a Part 5 experimental licence

**47 CFR Part 5** exists for exactly this and an individual can hold one.

| | |
|---|---|
| **eligibility** | **§ 5.51** — issued to persons qualified to conduct the operations in § 5.3. ⛔ **No foreign government or representative may hold one.** |
| **form** | **FCC Form 442** for a new conventional experimental licence |
| **filed through** | the **Experimental Licensing System (ELS)**, `fcc.gov/els` |
| **you need first** | an **FRN** (FCC Registration Number), from the CORES system |
| **term** | **6 months or less → file an STA** (Special Temporary Authority) instead. **Longer → Form 442.** |
| **processing** | roughly **30–45 days**, so start before you want to transmit |
| **fee** | there is one. **Check the current schedule — do not trust a number quoted second-hand, including this page's absence of one.** |

**What the application asks you for.** Have these ready before you open the form:

```
purpose of the experiment      what you are actually testing, in plain words
frequencies / UARFCN           the exact channel, not "Band 2"
emission designator            the 3GPP UMTS designator for your carrier
power                          ERP, and keep it LOW -- see section 2
antenna                        type, gain, height
station location               a fixed address for a bench cell
times of operation             not "continuous" unless you mean it
```

### ⛔ The condition that never goes away, licence or not

**§ 5.84 — non-interference.** An experimental station operates **only** on the condition that
it causes **no harmful interference** to any station operating under the Table of Frequency
Allocations.

> ### ☠️ **AND IF IT DOES, THE RULE IS NOT "TURN IT DOWN". IT IS *STOP*.**
> **On becoming aware of harmful interference, the licensee shall IMMEDIATELY CEASE
> TRANSMISSIONS** — and **shall not resume** until the Commission is satisfied that further
> harmful interference will not be caused.
> ⇒ ⭐ **An experimental licence is permission to try, on a non-protected, non-interfering
> basis. It is not a small slice of spectrum that becomes yours.**

### ⚠️ And the honest note about the other route

Some people run these with minimum power and physical containment and no licence, accepting a
known risk rather than an unknown one. **This page is not going to pretend that does not
happen.** But be clear with yourself about what it is: **§ 301 does not have a low-power
exception for you**, and the containment below is **harm reduction, not compliance.**
⭐ **If the cell is going to live on a bench for more than a weekend, the licence is genuinely
the easier path** — it is 30–45 days and a form, not an exotic undertaking.

---

## 2. ⛔ Containment — do this whether or not you hold a licence

**The goal is that your cell is audible to your handsets and to nothing else.**

| do | why |
|---|---|
| **minimum transmit power the unit will accept** | start at the floor and raise only if a handset will not attach. **Coverage is not the objective.** |
| **the smallest antenna that works** | a stock internal antenna is usually already more than you need |
| **one room, interior, away from exterior walls** | every metre of building material is attenuation you do not have to ask for |
| **a shielded enclosure if you have one** | the strongest containment available on a bench |
| **run it only while you are testing** | a cell radiating unattended for weeks is the one that eventually meets a complaint |

> ### ⚠️ **BAND 5 IS THE TRAP, AND IT IS EXACTLY WHAT YOU WILL REACH FOR**
> **Band 5 (850 MHz) propagates roughly 7 dB better than Band 2 (1900 MHz).** ⇒ **So when
> coverage disappoints, Band 5 is the obvious fix — and it is the wrong one.**
> ⭐ **Better propagation is LESS containment.** It reaches further into your neighbours' homes,
> further outdoors, and further into the coverage of whoever holds that licence.
> ⛔ **If you are choosing a band for a contained bench cell, choose Band 2.**

---

## 3. ☠️ Emergency calling — the one that can actually hurt somebody

**A handset camped onto your cell cannot complete a 911 / 112 / 999 call, and it will not tell
its user that.** It shows bars. It looks like service. The call fails when it matters most.

⛔ **This is not a configuration problem.** A private core has no route to emergency services
and no setting creates one.

⇒ **So containment is not only a spectrum question. It is the thing that keeps a stranger's
handset off your cell.**

| ✅ do | ⛔ do not |
|---|---|
| use **only SIMs you programmed**, so your handsets treat your cell as *home* | do not run an **open** cell that any handset can attach to |
| keep **CSG / closed-access ON** where the device supports it | ⚠️ **verify it ON THE AIR** — this hardware has a trap where the database and the broadcast disagree |
| power the cell **down when you are not testing** | do not leave it radiating unattended |

☠️ **If anyone in the building might need a phone to call for help, do not run the cell.**

---

## 4. ⛔ Never broadcast a real carrier's PLMN

A unit that served a carrier **still carries that carrier's MCC/MNC in its live configuration.**
**Broadcasting it is impersonating a licensed network operator**, and it will pull in handsets
that have no idea they have left the real network.

| use | what it is |
|---|---|
| **999-99** | **ITU-reserved** for exactly this. What this repo uses throughout. |
| **001-01** | the **3GPP test network** |

⚠️ **Change it BEFORE you enable the radio, and verify it on the air, not in the database.**

---

## 5. What you can publish, and the one line not to cross

This repository is a reuse guide for hardware people own. That framing is doing real work and
it is worth keeping.

| ✅ fine | ⛔ not fine |
|---|---|
| describing how the hardware works, in full | **redistributing vendor firmware**, images, or extracted filesystems |
| documenting an access path **on a device you own** | publishing private keys or SIM secrets (Ki / OPc / ADM) |
| naming the vendor's own identifiers and behaviour | anything obtained from **a network or device you do not own** |
| quoting short excerpts to explain a mechanism | reproducing a vendor's source file wholesale |
| citing credentials with their provenance stated | passing off someone else's finding as your own |

⭐ **Reverse engineering for interoperability is specifically protected** — that is the whole
purpose here, and it is the strongest position this work has. **But protection for *reading*
the code is not permission to *republish* it.** Keep excerpts short, functional, and in service
of an explanation.

> ### 🎯 **THE BRIGHT LINE, STATED ONCE AND PLAINLY**
> ⛔ **Do not put vendor firmware in the repository.** Not an image, not a bank, not an
> extracted root filesystem, not a base64 blob, not a mirror link.
> ⭐ **Everything else on this page is a judgement call. This one is not.**
> 📌 `tools/pre-publish-check.sh` scans for firmware shapes and oversized binaries and carries
> its own positive control. **A red gate is a blocker, not a warning.**

---

## 6. Scope — and why it is not a disclaimer

This repository deliberately does not cover attacking, intercepting or impersonating anyone
else's equipment or network. **Some of the same mechanisms would apply** — that is true of most
networking knowledge — **but the material is organised around reuse, and that is not a
formality.**

⭐ **Owning the device is the substance of the position, not the packaging.** A guide to
reusing your own hardware and a guide to attacking someone else's are different documents even
where a paragraph overlaps. **Keep it that way.**
