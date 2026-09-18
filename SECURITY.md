# Security

This repository documents access paths to **end-of-life femtocell hardware, for owners reusing
their own devices.** It is not a vulnerability disclosure channel and it does not publish
working attack payloads.

## Scope and posture

**The DPH-151 / 153 / 154** are end-of-life. AT&T's UMTS network, the only network they served,
was **shut down on 2022-02-22**, and Cisco has published end-of-life and end-of-sale notices for
its 3G femtocell line. These units are surplus, in the hands of the people reusing them — who
are the audience for these pages. There is no fleet to protect and no vendor fix pipeline.

**The ip.access nano3G** is a legacy 3G product whose vendor was **acquired by Mavenir in
September 2020** and now runs as a business unit there. No public end-of-life notice for the
nano3G was found. Where this repository describes a root path on it — the DMI management
console — **it also describes the one-write defence that closes it**, because a reader who owns
one needs to be able to close it.

## Vendors

If you represent **Cisco, ip.access or Mavenir** and want something here handled differently,
**open an issue or contact the maintainer.** Requests from a vendor with an affected product
still in market will be taken seriously, and this repository will act on a reasonable one.

### Why there was no advance notification

**Stated plainly, because the alternative is for a reader to assume it was an oversight.**

This material was published without notifying a vendor first. That was a considered decision,
not a gap:

- **The DPH-151/153/154 are end-of-life** and the only network they served was shut down on
  **2022-02-22**. There is no fleet to protect and no fix pipeline to give notice to.
- **The nano3G's vendor, ip.access, was acquired by Mavenir in September 2020**, so a corporate
  successor does exist. But the nano3G is a **legacy 3G product**, 3G is being retired
  worldwide, and the root path described here is **reachable only by someone who already has
  the device on their own network.**
- ⭐ **The defence is published alongside the finding.** Where this repository documents the DMI
  console as a root path, it also documents **the boot-script branch that gates the port and the
  one-write change that closes it** — which is the part an owner actually needs.

⇒ **The posture is responsive, not proactive.** No vendor has been contacted, and if one makes
contact, this repository will engage in good faith and act on a reasonable request.

## Readers

Nothing here should be used against equipment or a network you do not own. The material is
organised around **reuse of your own hardware against your own core**, and that scope limit is
deliberate.

⚠️ **Two operational hazards are documented throughout and are worth repeating here:** these
cells transmit on **licensed spectrum**, and **a private cell cannot complete emergency calls**
— a handset camped onto one will fail a 911 / 112 / 999 call with no warning to the user.
