# Bring-up: Cisco DPH-154 — the provider-emulation route, and the one bit that stops it

> ### 📋 EVIDENCE CLASS — and it is genuinely two different answers
> ✅ **ACCESS IS SOLVED.** There is a working route into a DPH-154 that needs **no memory-corruption
> exploit, no JTAG, no case opening and no serial console** — you stand up the management server the
> unit is already looking for, and let its own provisioning path do the work.
> ⛔ **THE RADIO IS SEPARATELY GATED, and on the unit measured here that gate is CLOSED.**
> `X_00000C_Tampered = 1` — **14 readbacks** — and `FAPService.Enabled` is refused with
> **FAULT 9003/9007.**
> ⇒ ⭐ **That is a per-unit condition, not a model-level wall.** A 154 with the bit clear should go
> all the way. **We do not have one, so the last phase is unproven and is labelled as such.**
>
> ⚠️ **An earlier revision of this page said "there is no route in."** That was written from an
> out-of-date reading of the corpus and **was wrong** — the access work had already been done. It is
> corrected here rather than quietly replaced, because *"we could never do X"* is exactly the kind of
> claim that survives past its own refutation.

---

## Why this route exists at all

The 154 is the hardened one. Every direct door is shut, and each of these was **measured**:

| door | state |
|---|---|
| the `wizard` UDP backdoor (works on older siblings) | **port 14677 closed** |
| anything listening | **13 ports probed, 13 closed** — and they are **ICMP-unreachable rejects**, the signature of a **firewall rule**, not of absent listeners |
| catching it phone home and answering as its server | **initiated nothing at all in 60 s of passive capture** |
| a public firmware dump to analyse | none exists, and the only software dump path **requires the access it would provide** |

⇒ **Public exploits are 2012–2018 and target the 151/153. This is a 2019 build.**
⭐ **So you do not attack it. You become the thing it is waiting for.**

---

## Phase 0 — Isolate, as always

The general caution in [`BRINGUP.md`](BRINGUP.md#before-you-plug-anything-in) applies. ⚠️ **On this
model it is doubly true**, because the whole route depends on the unit talking to *your* server
rather than reaching the internet and finding nothing.

---

## Phase 1 — Become its management server

The unit speaks **CWMP/TR-069** to an ACS. **Stand one up and let it connect.** Nothing here is an
exploit: you are answering a protocol the device initiates, with the identity it expects.

⚠️ **The CWMP store and the NV environment are different places, and confusing them costs a day:**
```
our ACS writes  ->  the CWMP store only   (/var/ipaccess/cisco/dslg_cur_cfg.xml.gz)
                    the TR-069 client has NO path to /var/ipaccess/nv_env.sh
```
⇒ **You cannot write the NV environment directly over CWMP.** The next phase is how you reach it.

---

## Phase 2 — ⭐⭐ The lever: a software download you supply

**There is exactly one CWMP-reachable writer of the NV environment, and it is the software-download
path.** Serve the unit a firmware image and it runs, unprompted:

```
CWMP Download -> swdl_client -> activate_bank -> activate_fs -> set_hardened_state
      (loop-mounts OUR fs.bin, reads FS_VARIANT from its /etc/sw_description.dat)
   -> init_nv_env -> setnv_env.sh <variables>
```

> ### 🎯 **THE LEVER IS NOT THE FILE WRITE. IT IS `FS_VARIANT`, AND IT COMES FROM THE IMAGE YOU SUPPLY.**
> `set_hardened_state` loop-mounts the filesystem **you served** and reads `FS_VARIANT` out of its own
> `/etc/sw_description.dat`. The hardening decision is then **a pure function of the 4th character**:
> ```
> rcS:48   FS_LETTER=$(echo $FS_VARIANT | cut -c4)   ->  DEFAULT_UNHARDENED
>          hardened only for:  A C E G I W X Z
> ```
> ⇒ ⭐ **You choose that character.** The unit hardens or unhardens *itself*, on your say-so, through
> its own vendor code path. **Same door, different handle.**

> ### ⚠️ A LATENT DISAGREEMENT BETWEEN TWO IMPLEMENTATIONS OF THE SAME TEST
> ```
> rcS:84-93          A C E G I W X Y Z   (9 letters — INCLUDES Y)
> swdl init_nv_env   A C E G I W X   Z   (8 letters — NO Y)
> ```
> ⇒ **A `…Y…` variant is treated as UNHARDENED by `rcS` and as HARDENED by `swdl_client`.** Not
> needed for this route, **but someone will trip over it** — and a unit in that state disagrees with
> itself about what it is.

⛔ **`-noswap` is never passed** (the operation type is hardcoded), so `activate_bank` **does** run —
which means **`uboot-install` rewrites both U-Boot banks first.** ⇒ **This is not a reversible probe.
It rewrites bootloaders.** Treat it as the irreversible step it is.

📌 **And do not expect `ENV_FIREWALL_DISABLED` in `nv_env.sh` to do anything on its own** — that
value is **dead state** for the running environment. The firewall follows `FS_VARIANT`, not the file.
**The file write is inert; the variant letter is the lever.**

---

## Phase 3 — What you have now

A unit that hardens or unhardens on your instruction, with NV variables you chose — which is the
same primitive the other models reach through a console. **From here the software half of
[`BRINGUP.md`](BRINGUP.md) Phases 4–8 applies**: point it at your core, give the radio parameters,
unlock, connect.

---

## 🔴 Phase 4 — The tamper bit, and why this page stops here

**The radio has its own gate, and it is enforced independently of everything above.**

```
X_00000C_Tampered = 1         14 readbacks, consistent
FAPService.Enabled            REFUSED — FAULT 9003 / 9007
```

⇒ **A tampered unit will provision, accept configuration, and refuse to transmit.** Every other
instrument reads healthy. ⭐ **This is the failure that looks exactly like a configuration mistake
and is not one.**

> ### ⛔ AND THE MOST IMPORTANT THING ON THIS PAGE: **THE BIT CAN BE SET BY YOU, AND IT IS ONE-WAY**
> [`Trap 41`](TRAPS.md#41-opening-the-case-can-destroy-a-factory-configuration) is the full entry.
> **Opening the case and guessing the jumper pattern trips a one-way tamper latch in flash.** The
> pattern is **one-hot — one real jumper among blanks, six candidates** — so a guess is far more
> likely wrong than right.
> ✅ **Leaving jumpers off is safe. Restoring a pattern from memory is not.**
> ⇒ 🎯 **If you buy a 154, buy one that has never been opened, and do not open it.** The route above
> needs no case access at all — **and the case is where the radio gets lost.**

---

## What would finish this guide

**One DPH-154 with `X_00000C_Tampered = 0`**, taken through Phases 1–3 and then the software half of
[`BRINGUP.md`](BRINGUP.md). Specifically still unknown:

- **Whether `FAPService.Enabled` is accepted** once the tamper bit is clear — **the fault codes are
  the only evidence we have, and they were taken on a tampered unit.**
- **Whether the tamper bit is clearable at all.** ⛔ **Assume not.** Nothing here has cleared one, and
  a one-way latch in flash is exactly the sort of thing that is not meant to be.
- **Which config-bank layout applies.** The 154 selects **named UBI volumes, not numbered banks** —
  U-Boot reads a 4-byte `default_bank` value, and `config_bank_1`/`config_bank_2` **do not exist on
  it at all.** ⇒ [`Trap 2`](TRAPS.md#2-which-config-bank-is-live-differs-per-model--and-guessing-kills-the-cell)
  does not apply to this model in the same form.

---

## Two model-specific facts worth having

- **Its U-Boot environment sets `consoledev=/dev/null`** ⇒ **Linux never opens that UART**, and a
  serial capture goes silent after `Starting kernel`. ⚠️ Two people spent ~20 minutes on baud sweeps
  before finding it — **97 % `0x00` is a line held LOW, not misframed data.**
  ⛔ **Do not carry this to another model.** It was measured on the **154's** environment; applying
  it elsewhere has already caused one serial route to be written off wrongly on a different device.
  ⭐ **And note what it does *not* say: U-Boot's own console is a separate stage, and nobody has
  confirmed it dead on a 154.**
- **The external antenna port was deleted** relative to the 151's MCX. ⇒ **The "one room, heavily
  attenuated, remote antenna" deployment is not available on this model.**

> ### ⚠️ One thing this repo nearly published as settled, kept visible
> *"The DPH-154 is not picoChip"* is **not** established. A teardown identifies an **AD9365**
> transceiver with Band 2 and Band 5 power amplifiers; another source attributes a picoChip part.
> ⭐ **These are reconcilable — the AD9365 is the RF transceiver, a picoChip part would be the
> processor/baseband. Different components.** The 154's SoC identity is genuinely unsettled.
