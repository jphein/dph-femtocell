# Access: getting into the device

**Scope: the shell-level detail is measured on a DPH-151. The two-processor architecture is
established for the 151 and 153. The DPH-154 is a different design — see
[`HARDWARE.md`](HARDWARE.md) — and none of the chip-level detail here should be assumed to
apply to it.**

---

> ## 🎯 **WHICH ROUTE REACHES WHICH CHIP — READ THIS BEFORE PICKING ONE**
> `[added 2026-09-13. This document listed six routes for months and never said which SoC each
>  one lands on. A lane with Ralink root read the whole file looking for the way onward.]`
>
> | route | lands on | works on a COLD unit? |
> |---|---|---|
> | **1 — SSH to the radio processor** | **picoChip** `.186` | ⛔ **NO** — *"available once you have installed a key."* **It does not tell you how to install one.** |
> | **2 — DMI console** | picoChip's attribute model | ⚠️ configures the cell. **Not a shell.** |
> | **3 — the Ralink gateway** (telnet · `guest`/pw · IPC injection · `wizard` UDP 14677) | **Ralink** `.185` | ✅ **YES** — this is the one that works cold |
> | **4 — serial console** | both had UART headers | ⚠️ case opening. **Not the path used here.** |
> | **5 — the management plane** (TR-069/CWMP) | picoChip config | ⚠️ **config only. Not a shell** — but see PATH D |
> | **6 — the nano3G's DMI** | ⛔ **a DIFFERENT DEVICE** | n/a to a DPH-151 |
>
> ### ⛔⛔ **SO THE HONEST SUMMARY: EVERY ROUTE THAT WORKS COLD LANDS ON THE *RALINK*.**
> **There is no documented route that gets you a shell on the *picoChip* from scratch.** Route 1
> presupposes the key; Routes 2 and 5 are configuration, not shells; Route 4 needs the case open.
> ⇒ ⭐⭐⭐ **The chain that closes it is PATH D — the CWMP route TO a shell:**
> ```
> CMHS/ACS binds -> Download RPC -> sdphook -> post_swdl_hook runs it AS ROOT
>                -> enables sshd + installs a key -> THEN Route 1 becomes available
> ```
> ⇒ **Route 1 is the DESTINATION, not an entry point.**
> ### ✅✅ **AND PATH D IS NOT A THEORY — IT IS HOW `.244`'s PICOCHIP ACTUALLY GOT ROOT.**
> `[findings-dph151-root-baseline.md:1-4 — "first root baseline, measured 2026-09-05 21:59Z.
>  READ OFF THE DEVICE OVER SSH AS uid=0 ON THE PICO (192.168.157.186, via the Ralink
>  10.0.6.244:22 DNAT). Everything below is measured, not inferred." — and :8 attributes the
>  nv_env write to "OUR v7 HOOK", :57 to "the hook installed JP's dph151-jp key".]`
> ⚠️ **This page previously said PATH D was "assembled from measured parts". That hedge was
> WRONG and it was mine** — it turns a demonstrated capability into a hypothesis, which is
> exactly what stops the next reader using it.
> ### ⛔ **TWO OBSTACLES, BOTH FROM THE SAME FILE, BOTH NAMED**
> ```
> :33  persistent_ssh.sh kills DslmSsp — THE MAIN APPLICATION. On a unit that is NOT
>      mid-transaction it plausibly CAUSES the reboot it exists to prevent.
>      ⇒ kill  rmmwd swdl_client post_swdl_hook  ONLY.
> :47  the retry authenticated with cwmp_rce_key while the hook had installed dph151-jp.
>      DIFFERENT KEYS, rc=255 six times. ⭐ A lost race and a rejected key are
>      indistinguishable from outside — only the return code separated them.
>      ✅ v8 installs BOTH public keys.
> ```
> ⏱️ **SSH opens for ~30–60 s and then the unit auto-reboots.** `persistent_ssh.sh` must run
> **inside that window** or the service closes again.
> ⛔ **The upstream hook installs a PUBLISHED private key** (tracked in a public third-party
> repo). **Mint a fresh pair before driving it.**
> ⛔ **Its upstream hook installs a PUBLISHED private key** (tracked in a public third-party repo).
> **Mint a fresh pair before it is ever driven.**

## There are two computers in the box

On the DPH-151 and DPH-153 the unit is **two SoCs**, and confusing them wastes days:

```
  picoChip SoC   the RADIO half. Runs the ip.access femtocell stack,
                 the DMI management interface, the cell, Iuh.
       │
       │  a private point-to-point link, /30, two usable addresses,
       │  fixed at the factory in RFC1918 space
       │
  Ralink SoC     the NETWORK GATEWAY half. DHCP server, NAT, and the
                 pico's default route to your LAN.
```

**Everything published about rooting these devices in 2012 is about the *Ralink*** — the
UART header, the SSH password, the `wizard` backdoor. **Everything that gates RF is on the
*picoChip*.** "Assume root" usually means root on the half that does not control the radio.

⭐ **But the Ralink is the gateway, so from Ralink root you control every packet the radio
half sees** — which is what makes "be the infrastructure" viable without ever rooting the
picoChip.

> ### ⚠️ Read the link addresses off your own unit
> `ip addr` / `ifconfig` on either side, or the boot log. They are factory-fixed, but write
> down what *your* unit says rather than trusting any number in a guide, including this one.

**The Ralink DNATs several TCP ports straight through to the picoChip.** On our unit that
includes 22, 80, 8080 and 20000. ⇒ **The SSH you reach at the unit's LAN address is the
picoChip's, not the Ralink's.** The Ralink's own SSH port is closed — because it has no SSH
server at all (below).

> ⚠️ **"NO SSH" IS NOT "NO REMOTE SHELL" — TWO READERS MADE THAT LEAP ON 2026-09-13.**
> **The Ralink has `telnetd`, and it is reachable.** See Route 3 below. **Do not read this
> paragraph as "the gateway SoC is unreachable"; it says only that the protocol is not SSH.**

---

## Route 0 — **THE ONE THAT ACTUALLY WORKS, AND IT IS ALL OVER THE NETWORK**

> ### 🎯 **THIS IS HOW A DPH GETS ROOT ON ITS PICOCHIP. NO JTAG. NO SERIAL. NO SOLDERING.**
> `[JP, 2026-09-13, verbatim: **"no we did it all over netork"** · and Osmocom Discourse topic 2625
>  post 41 (tempest → nickvsnetworking), recovered by JP because Anubis blocks automated fetch.
>  Full text: `~/Projects/microcell/docs/reference/forum-extracts/post-41-tempest-2026-09-04.md`]`
>
> ⛔ **EVERY OTHER ROUTE ON THIS PAGE LANDS ON THE RALINK, OR NEEDS A KEY THAT IS ALREADY ON THE
> PICO.** **Route 0 is the step that crosses between them, and it was missing from this document
> until 2026-09-13 — which cost a lane an entire evening on Route 5, which this page says in bold
> is *not* how root is obtained.**

### The procedure

```
1. ROUTE + FIREWALL + TWO LAN IPs
   a host route to 192.168.157.186/30 via the DPH's LAN IP, allowed through your firewall,
   and TWO LAN IPs on your side (the ACS and CMHS must be on DIFFERENT addresses —
   the femto sends NO TLS SNI, so the handler and certificate are chosen BY DESTINATION IP).

2. ./certpatch.sh  — IT BUILDS TWO CERTS FOR TWO DIFFERENT LEGS. THE RCE IS ON THE ACS LEG.
     chain203.pem  ACS   femtocell.wireless.att.com   O=att, no OU        IP:10.0.0.228  <- THE TARGET
     chain202.pem  CMHS  cmhs*.wireless.att.com       O=attmobility,TPE   IP:10.0.0.36
   ⭐ tempest activates ONE CMHS FQDN and it differs per unit ("my unit likes looking up
     cmhsse-decatur..."), but CMHS IS NEVER DEFEATED — IT IS BYPASSED. The shell comes from
     the ACS/TR-069 leg. WATCH WHAT YOUR UNIT DIALS; do not guess and do not activate all eight.

3. SERVE THE DOWNLOAD. The unit pulls it from the python server.

4. ⏱ SSH IS OPEN FOR ~30-60 SECONDS, AND THEN THE UNIT REBOOTS ITSELF.

5. ./persistent_ssh.sh  — INSIDE THAT WINDOW.
   ⛔ Without it the unit reboots and shuts the SSH server off again.
```

> ### ⏱ **THE 30-60 SECOND WINDOW IS THE WHOLE OPERATION — HAVE STEP 5 READY TO RUN BEFORE STEP 3.**
> **The self-reboot is EXPECTED BEHAVIOUR, not a fault and not a sign you broke something.**
> ⇒ **Plan it as a race you have already staged for, not as a step you perform when you see it.**

> ### ⚠️ **THE CERTIFICATE DATES, AND THE ORIGINAL AUTHOR'S OWN DOUBT — KEPT BECAUSE IT IS HONEST**
> The reason given is that **the Ralink's clock resets to 1/1/2000 whenever power is pulled**, so
> certificate validity must start at 1/1/2000. ⚠️ **tempest is explicitly sceptical of that
> reasoning:** *"I ran the date command over telnet, and it had no effect on the problem where the
> DPH terminated the connection early, maybe it's something else? **But it does work**."*
> ⇒ ⭐ **The BACKDATING IS LOAD-BEARING; the EXPLANATION for it is not established.** Do the
> backdating; do not build on the reason.

> ### 📋 **WHAT "IT TERMINATED THE CONNECTION EARLY" LOOKS LIKE — so you recognise it**
> **Completes mutual TLS, presents its factory Cisco client certificate, sends ZERO application
> bytes, and FINs at ~11-12 ms.** `[measured on the wire here 2026-09-13, and matching
> findings-lead-howwegotin.md's description of the pre-fix state]`
> ⇒ **That is the symptom Route 0 exists to cure. It is NOT a firewall, NOT a routing fault, and
> NOT a server-side bug — a same-endpoint control shows a working unit succeeding against the
> identical IP, handler and server certificate.**

> ### ✅✅ **AND IT IS CONFIRMED ON A DPH-151 — BY THE PERSON WHO RAN IT**
> `[JP, 2026-09-13, verbatim: **"the 153 exploit to access the pico worked on the 151 we did it
>  alrday"** · and **"no we did it all over netork"**]`
> ⇒ ⭐⭐⭐ **THE 153's PICO EXPLOIT WORKS ON THE 151. IT HAS BEEN DONE ON `10.0.6.244`, WHICH HAS A
> LIVE ROOT SHELL ON BOTH CHIPS TODAY** (`ip202ff`, uid 0 — verified 2026-09-13).
> ⛔ **THIS REPO'S OWN `reference/working-scripts/README.md` CARRIES THE OPPOSITE CAUTION:**
> *"These target a **DPH-153**. Our unit is a **DPH-151**… tempest states plainly that the 151/154
> have no reliable instructions."* ⇒ **That caution was correct WHEN WRITTEN and is now superseded
> by our own operational result. It is the reason nobody here reached for this route for days.**
> ⭐⭐ **The SOFTWARE half transfers. It is only the 153's JTAG/HARDWARE half that does not — and
> Route 0 needs none of it.**

📌 **Also known to work on at least 4 DPH-153 units** (tempest, post 41).

---

## Route 1 — SSH to the radio processor

This is the comfortable route, and it is available once you have installed a key.

> ### ⛔ A modern OpenSSH client will refuse this device three times, for three different
> ### reasons, in sequence.
> The daemon is an old dropbear on a 2.6-series kernel and offers **only** algorithms modern
> OpenSSH has disabled. You will hit **key exchange**, then **host key**, then **cipher** —
> fixing each one reveals the next. Several people here rediscovered one flag at a time over
> weeks because each error looks like the final answer.
>
> ✅ **Put it all in `~/.ssh/config` once:**
> ```
> Host mycell
>     HostName <ip>
>     User root
>     KexAlgorithms +diffie-hellman-group1-sha1
>     HostKeyAlgorithms +ssh-rsa
>     PubkeyAcceptedAlgorithms +ssh-rsa
>     Ciphers +aes128-cbc
>     MACs +hmac-sha1
> ```
> A bare `ssh <ip>` will keep failing. That is the client refusing, not the device being down.

### Making SSH survive a reboot
Four independent layers, all worth having, because any one of them can be undone by a
firmware operation:

1. **Keys on persistent flash.** Put the authorised-keys file on the durable jffs2 partition
   and symlink root's home at it — the rootfs does not survive.
2. **Re-assert the console/access flag at every boot**, from a startup script. A software
   download can flip the daemon to listen on loopback only, which looks exactly like the box
   being dead.
3. **Relaunch the daemon each boot** if it is not already listening.
4. **Re-check periodically**, unconditionally, and **before any radio logic** — so a fault in
   the radio path can never strand the box with no way in.

---

## Route 2 — the DMI management console

The ip.access stack exposes a **DMI** interface that speaks `get` / `set` / `action` against
the device's attribute model. **This is the interface that actually configures the cell** —
and, critically, the one that moves what goes on the air. The management/TR-069 tree is a
*different store*; see trap 15 in [`TRAPS.md`](TRAPS.md).

**Probe 8090 first on any new unit.** If it is open you may not need a root shell at all, and
the whole project collapses to a config exercise.

> ### ⚠️ Three things about port 8090 that are not what you would guess
> 1. **It was NOT listening by default on our DPH-151.** Measured: zero listeners, with
>    `/proc/net/tcp` confirmed readable so it is a real zero rather than a blind one. It has to
>    be started — and **the library path is required or the binary dies immediately.**
> 2. **"Unauthenticated" is now MEASURED — but on the sibling, not on a MicroCell.** On an
>    ip.access nano3G the port is a telnet DMI console with **no authentication step of any
>    kind**, demonstrated rather than assumed, and it is a full root path from there
>    ([Route 6](#route-6--the-nano3gs-dmi-console-where-the-management-plane-is-the-root-path)).
>    **On a DPH-151 it remains inferred**: no login step appears in any documented sequence, and
>    nobody here has demonstrated it, because on our unit the port never listened.
>    ⇒ **Plan for it being unauthenticated; do not claim it is, on a MicroCell.**
> 3. ✅ **There is a better path that bypasses the socket entirely** — the DMI client has a
>    one-shot command mode you can run over SSH. It is non-interactive, scriptable, and does
>    not consume the single-client port. **Prefer it.**

> ### ⚠️ And two ways the telnet front end fails without telling you
> - The client sends a Telnet **linemode negotiation** on connect, and **if nobody answers it,
>   the prompt never arrives and every command times out.**
> - A *failed* read returns the **bare prompt**, not empty output. So an emptiness check
>   **passes a non-answer** and you act on it.

> ### ⚠️ Two transports, and the wrong one is silent rather than broken
> On our DPH-151 the **telnet front end accepted input and never answered a `get`** — bare
> LF, CRLF, and Telnet linemode negotiation all returned a banner and a `dmi>` prompt with no
> result — while the **local one-shot client answered the byte-identical commands**.
>
> ✅ **Validate your transport with a known-present attribute before believing any silence.**
> Otherwise "attribute not found" and "transport dead" are the same observation.

⚠️ **One command per invocation.** A single bad attribute aborts a whole DMI batch, so a
valid attribute in a bad batch reads as *does not exist*.

⚠️ **Put a timeout on every call.** A `get` can hang indefinitely even as the only client on
the box. Without a bound, one hung call stalls everything after it — and a killed call must
not abort the run.

⛔ **Never kill the management daemon.** It owns the TR-069 session, the data model **and**
the DMI action path. Killing it destroys the channel you are working over; on our unit a
published "clean up these processes" list caused a reboot.

---

## Route 3 — the Ralink gateway

**The Ralink has no SSH server as shipped.** `[read from both extracted rootfs banks of a
firmware image — ⚠️ this is a read of the IMAGE, not of a live device. If something was
installed at runtime this read would look identical and be wrong.]` The `/etc/ssh` directory
is empty and dated 2011; there is no `sshd` and no dropbear; busybox has no ssh applets.

What it does have is **`telnetd`, bound to the internal point-to-point address only.**

> ### 🔴🔴 **CORRECTED 2026-09-13 — THE INFERENCE THAT USED TO SIT HERE IS FALSE AND IT COST A LANE AN EVENING**
> ~~*"so it is not reachable from your LAN, and every path to it goes through the picoChip."*~~
> `[MEASURED 2026-09-13: root obtained on .106's Ralink from katana, by host route + telnet,
>  WITHOUT touching the picoChip. This sentence is why nobody tried it for weeks.]`
> ### ⭐⭐⭐ **A BIND ADDRESS DECIDES WHICH PACKETS A DAEMON *ACCEPTS*. *ROUTING* DECIDES WHICH PACKETS *ARRIVE*.**
> **The Ralink owns BOTH the LAN address AND `192.168.157.185`.** So a host route pointed at the
> LAN address is delivered **locally, to `telnetd`,** with no picoChip in the path:
> ```sh
> sudo ip route add 192.168.157.185/32 via <lan-ip>     # additive, reversible
> telnet 192.168.157.185                                 # guest / 1qaz@WSX
> ```
> ⇒ ⛔ **"Bound to an address that is not on your LAN" is NOT "unreachable from your LAN."**
> ⚠️ **The premise was true and stayed true** — `telnetd` really is bound `-b 192.168.157.185`.
> **Only the conclusion was wrong**, which is why re-reading the sentence kept confirming it.
> 📌 See [`BRINGUP.md`](BRINGUP.md) Phase 1b, and `~/Projects/microcell/keys/dph151/rroot.py`.

> ### ⛔ And it structurally CANNOT keep an SSH server, which is why nobody should try
> The Ralink's root filesystem is an **initramfs embedded in the kernel image**. There is no
> rootfs partition, `/var` and `/tmp` are RAM, and the small flash has no data partition.
> ⇒ **Persistent SSH there means rebuilding and reflashing the kernel — on the processor that
> NATs every packet to the radio half. Brick it and the radio becomes unreachable too.**
>
> ⭐ Note why the inference from an image is sound *here specifically*: the image **is** the
> root filesystem by construction, so "no daemon in the image" really does mean "no daemon
> after any reboot". **That inference would be invalid on a device with writable flash** — do
> not carry it across.

Access routes, all from fail0verflow's 2012 work:
- **telnet with the shipped default credentials.** We are deliberately not reprinting the
  credential pair here; it is in the fail0verflow write-up, which you should read anyway.
  ⚠️ **The accounts are bank-dependent**: on our unit one firmware bank carries a `guest`
  account and no `root`, and the other carries `root` and no `guest`. ⇒ **`Login incorrect`
  may mean "wrong bank", not "wrong password".** Which bank your unit booted is a separate
  question — see trap 2 in [`TRAPS.md`](TRAPS.md).
- **a local IPC client** on the Ralink that runs commands as root.
- **the `wizard` UDP backdoor** on **port 14677** — unauthenticated remote command
  execution, bound to all interfaces because it was only ever meant to be reachable inside
  the operator's IPsec tunnel.

> ### ⚠️ The commonly-cited NAME for this route is wrong, and the artefact carries the error
> The route that actually yields root on a DPH-151 is **telnet, a hardcoded vendor guest
> password, and a command injection through the local IPC client** — the three bullets above.
> It is frequently called a *"CWMP RCE"*, and it is not one: **CWMP is not involved.**
>
> ⭐ The misnomer is baked into the tooling — the key file people pass around is *named* for
> CWMP — so it propagates every time someone quotes the filename. **Expect every other
> write-up you find to use the wrong name**, and do not go looking for a TR-069 vulnerability
> that is not there.

> ### ⭐ The backdoor survived a hardware generation
> fail0verflow published against the **151** in 2012 and the same binary is still present in
> the **153**. It was not patched between them. ⚠️ That raises the prior for the 154; it does
> not settle it, and a negative there is a result worth publishing.
>
> ⚠️ **Searching a firmware image for the decimal string `14677` returns zero** — a port
> lives in code as a number, not as text. It appears as an immediate load of the byte-swapped
> value. **A string search is the wrong instrument for a port number**, and its zero is not
> evidence of absence.

---

## Route 4 — serial console

Both SoCs had UART headers. On the 151, fail0verflow used header **JP1** at **56700 baud**
(try 57600 too).

**Header JP1 on the 151:** pin 1 RX, pin 2 TX, pin 3 GND.

⛔ **Use a 3.3 V-only adapter**, and ⭐ **make your first session receive-only** — with the
adapter's TX unconnected, even a 5 V adapter cannot damage the device, so you can start
capturing before you have proved anything about voltages. Full rationale, pinout and the baud
transposition trap are in [`HARDWARE.md`](HARDWARE.md).

The boot log is the richest single artefact on these devices: it names the boot order, the
configuration mechanism, the inter-processor link, and precisely what fails when the
operator's infrastructure is unreachable. **Capture it to a file the first time.**

---

## Route 5 — the management plane itself

> ### ⚠️ **READ THE RECONCILIATION EIGHT LINES BELOW BEFORE ACTING ON THIS ROUTE'S VERDICT.**
> **Short form: *"TR-069 is not how root is obtained"* is TRUE OF THE RALINK and FALSE OF THE
> PICOCHIP.** ⇒ **For a pico shell, TR-069 IS the route** — `persistent_ssh.sh:6` runs
> `ssh -i cwmp_rce_key root@192.168.157.186`, and that is how `.244` first got root
> `[findings-dph151-root-baseline.md:1-4]`. **See [Route 0](#route-0).**
>
> ### 🔴 **CORRECTION TO MY OWN BANNER, WHICH STOOD HERE FOR FOUR MINUTES**
> `[nebula-librarian3 — three errors in one edit, all mine, none caught by my own review]`
> ```
> 1. I wrote "TR-069 IS how root is obtained" FLATLY. The reconciliation below already said it
>    better: BOTH claims are correct and they are ABOUT DIFFERENT PROCESSORS. My version would
>    send someone to CWMP for a RALINK shell, where it is the WRONG route.
> 2. I wrote that the correction sat "~115 lines BELOW". IT IS EIGHT. I estimated a distance
>    instead of counting it -- the relative-coordinate error this corpus cards -- inside a
>    banner whose entire subject was placement.
> 3. My diagnosis followed from that wrong number: "a correction downstream of its error is
>    invisible". At eight lines and clearly written, that explains nothing.
> ```
> ⭐⭐ **THE REAL EXPLANATION IS AMBIGUITY, NOT DISTANCE, and the reconciliation already named it:
> *"THIS SENTENCE IS TRUE OF THE RALINK AND FALSE OF THE PICOCHIP, AND THE AMBIGUITY COST AN
> EVENING."*** ⇒ **On a two-processor device, a sentence true of one chip and false of the other
> is read as whichever chip the reader has in mind.**
> ⛔ **I "fixed" a document that had already fixed itself, less accurately, and justified it with
> a number I had not measured.**

The TR-069 / CWMP stack is a legitimate **configuration** path. If you control DNS for the
device — and you do, since it is on your network and its management hostnames are dead — you
can answer as its management server without touching the device at all. See
[`CONFIG.md`](CONFIG.md).

> ### 🔴🔴 **THIS SENTENCE IS TRUE OF THE *RALINK* AND FALSE OF THE *PICOCHIP*, AND THE AMBIGUITY COST AN EVENING**
> `[reconciled 2026-09-13 after JP: "we have all the info there you are still guesiing"]`
> ```
> ACCESS.md Route 5 (here)           "TR-069 is NOT how root is obtained on this device"
> reference/working-scripts/README   "Root on the PICOCHIP is obtained via RCE over CWMP/TR-069
>                                     on the ACS leg, then an SSH key is planted."
> ```
> ⇒ ⭐⭐⭐ **BOTH ARE CORRECT AND THEY ARE ABOUT DIFFERENT PROCESSORS.** **The RALINK is rooted by
> telnet + a vendor guest password + IPC injection (Route 3) — and calling THAT a "CWMP RCE" is the
> misnomer.** **The PICOCHIP is rooted over the ACS/TR-069 leg — see [Route 0](#route-0).**
> ⛔ **Neither document cited the other, so a reader arriving at Route 5 is told the management plane
> is a dead end and sent away from the only route that produces a pico shell.**
⚠️ **It is not how root is obtained ON THE RALINK**, despite a widely-repeated name that says
otherwise. See the correction under Route 3 — **and [Route 0](#route-0) for the picoChip, where it
IS the route.**

The point for a reader is the *architecture*: the device is designed to be provisioned
remotely by whoever answers those hostnames, and on your own network that is you.

> ### On getting root: the **method** is documented, the **key** is yours to make
> Root on a DPH-151 comes from a **publicly documented procedure**, not from anything
> discovered here — the `wizard` backdoor above is the published route, and it lands you a
> root shell from which you install **your own** SSH key.
>
> ✅ **Generate your own keypair.** Nobody else's key is of any use to you, and a key that has
> been published is worse than no key. There is no credential in this repo for the same reason
> there is no point in one.
>
> ⛔ **And do not "confirm it worked" by running the tool a second time** — that check cannot
> fail. See trap 22 in [`TRAPS.md`](TRAPS.md); it is the single most likely way a reader
> misleads themselves here.

## Route 6 — the nano3G's DMI console, where the management plane **is** the root path

**Measured on an ip.access nano3G**, not on a MicroCell — see
[`HARDWARE.md`](HARDWARE.md#the-ipaccess-nano3g--the-sibling-these-findings-are-cross-checked-against) for what
does and does not transfer. On our DPH-151 port 8090 was **not listening at all**, so none of
this was reachable there. It is here because the two devices run the same software train,
because the shape is a *class* of bug worth recognising, and because **the defence is one write
and nobody would think to apply it.**

### The console, and the whole of its access control

TCP **8090** is a plain telnet DMI console with **no authentication step of any kind** —
measured on this hardware, not inferred. It exposes the attribute model read/write plus the
action table. Everything below follows from it being open.

It is open only when **two conditions hold at once**. From `/etc/init.d/opnormal`'s
`dmistart()`:

```sh
if [ -f ${DMISCRIPT} ]; then          # /var/ipaccess/init.dmi EXISTS
    clean_sets_from_initdmi
    IS_DMI_AUTOGEN=`grep -c "// init.dmi - THIS FILE IS AUTO-GENERATED" ${DMISCRIPT}`
    if [ $IS_DMI_AUTOGEN -eq 0 ] && [ -x ${PROG_DMI} ]; then
        ${PROG_DMI} -c "call ${DMISCRIPT}" &      # run it
    fi
else                                  # init.dmi ABSENT -- the ONLY telnet path
    if [ ${ENV_START_DMI_TELNET:-"FALSE"} == "TRUE" ]; then
        ${PROG_DMI} -u ${DMI_TELNET_PORT} &
        open_firewall_port ${DMI_TELNET_PORT}
    fi
fi
```

⇒ **`init.dmi` absent AND `ENV_START_DMI_TELNET=TRUE`.** Both, or there is no port at all.
⚠️ **Note what else lives in that branch:** `open_firewall_port`. **The firewall is not a second
layer here — it is opened by the same code that opens the port.**

### Where that flag comes from — and it is a button, not a bug

**The firmware never writes `ENV_START_DMI_TELNET`.** Enumerated over the whole of `rcS`:

```
$SETNVENV call sites, entire file        2      ENV_VERBOSE_CONSOLE_ENABLED
                                                ENV_FIREWALL_DISABLED
ENV_START_DMI_TELNET, anywhere in rcS    0      <- never written by the firmware
CONTROL: ENV_VERBOSE_CONSOLE_ENABLED     4      <- the reader works, so the 0 means something
```

And a **factory restore deletes `nv_env.sh` outright**, so on the next boot the variable is not
set to `FALSE` — it is **absent**, and `opnormal` falls through to its own `:-"FALSE"` default.

⇒ ⭐ **A virgin or factory-restored unit has the console OFF BY ABSENCE**, and the commissioning
web UI's toggle is its **only** writer — `dmi_config.cgi`, which serves exactly this:

```html
<input type="submit" name="dmi_telnet" value=Enable >
```

✅ **Confirmed end to end on one unit:** the toggle was pressed during commissioning, and after
*Complete Commissioning* plus two power cycles the variable read `TRUE`. **Since no firmware path
writes it, that `TRUE` can only have come from the button — and it persists.**

> ### ⭐⭐ So the chain has two stages, and the first one is a supported feature
> ```
> STAGE 1   the COMMISSIONING WEB UI enables the console. Not an exploit -- a BUTTON,
>           and the only thing that sets the flag the branch above depends on.
> STAGE 2   the console, now reachable, is unauthenticated.
> ```
> ⇒ **A vendor-supported commissioning control turns on an unauthenticated, root-equivalent
> interface, and nothing else can turn it on.**
>
> ⭐ **This sharpens the defence rather than weakening it.** There is no patch to wait for and no
> subtle hardening to get right: **the operator's entire control surface is that checkbox and the
> two conditions in that `if`.** Nothing else in the firmware touches the flag.
>
> ⚠️ **And it closes symmetrically, which is worth knowing before you press anything:** a factory
> restore deletes `nv_env.sh`, so **a restore turns the console back off — along with whatever
> else you had configured.** That is the same event as
> [trap 49](TRAPS.md#49-the-reset-button-reaches-factory-restore-sooner-than-the-manual-says),
> where the threshold is shorter than the manuals say. **The reset button is both the recovery
> path and the thing that removes your access.**
>
> ⛔ **Measured on an ip.access nano3G. The DPH equivalent is UNMEASURED** and should not be
> assumed — on our DPH-151 the port never listened at all.

### The read primitive: `call` echoes what it cannot parse

`call` is documented as *"Executes a DMI script"*. It takes a path, opens it, and echoes every
line as `### Executing: <line>` before failing to parse it. ⇒ **Any file the DMI process can
open is readable** — every config file, every init script, the NV environment.

⭐ **Read the `### Executing:` lines and not the error echo** — the error path **lowercases**,
so a value's case is destroyed in exactly the copy most people scroll to.

📌 **This is genuinely useful for legitimate work**, which is worth saying plainly: it is how
you answer *"is that key actually in the config file"* without having a shell at all.

### The write primitive: a URL-shaped attribute landing in a file that is sourced as root

`/var/ipaccess/nv_env.sh` is **sourced as root** early in boot. Several MIB string attributes
are written into it **verbatim**, as `export` lines. `crlServerBaseUrl` (2203) is one:

```
set crlServerBaseUrl="http://example/"   ->   export ENV_CRL_BASE_SERVER="http://example/"
```

**That is the whole bug, and it is worth stating as a class rather than as a trick:** a
configuration string is interpolated into a shell file that is later executed, with **no
validation and no quoting discipline**. `;`, backticks, `$(` and `|` all round-trip unmodified.

⚠️ **The detail that makes it work where you might expect it not to:** the DMI parser owns the
double quote, so the shell string cannot be *terminated* from inside the value. **It does not
need to be — `$(...)` command substitution is evaluated inside double quotes.** A value of the
shape `x$(…)` therefore has its contents run **as root, at every boot**, when `nv_env.sh` is
sourced. No second service, no network fetch, no memory corruption: the device does it because
that is what sourcing a shell file means.

⚠️ **A structural caveat, which is also why this is a two-reboot procedure and not a one-shot:**
`$( )` runs in a **subshell**, so it cannot change the environment of the parent. Altering an
NV variable means editing the **file** and booting **again**.

### A second write path, through the web UI — and it skips the validator the first one has

The attribute route above goes through the DMI console. There is another, through the
**commissioning web UI**, and the pair is worth seeing together because they are guarded
differently:

```
attribute route   set <a URL-shaped attribute>      -> a URL-field validator exists here
file route        dmi_config.cgi, multipart upload  -> the file field BYPASSES that validator
                  form field `dmi_filename`            entirely
```

⇒ **The uploaded file lands as `init.dmi`, and `opnormal` executes it as root at boot**, through
the first branch of the `if` above (`ipa-dmi -c "call …"`). ⚠️ **No injection is needed on this
path at all — the file is a script, and the device runs it because that is the feature.**

⭐ **The shape worth carrying away: somebody DID think about validation here.** There **is** a
validator, on the field that looks like the input. **The multipart file field is a second path to
the same sink and does not pass through it.** ⇒ **When you find input validation on an embedded
device, ask what else reaches the same place.**

> ### ⚠️ And this changes what the defence below COSTS you
> Installing an `init.dmi` to close `:8090` is still the right move. **But the file you install is
> executed as root at every boot — that is not a side effect, it is the mechanism.** ⇒ **You are
> not disabling a feature; you are choosing to use it.** Write the file accordingly, and read the
> marker rule immediately below before you do.

> ### ⭐⭐ Both guards on the `init.dmi` path are a `grep` for a COMMENT
> Look again at `dmistart()`. The device decides whether to execute `init.dmi` by counting
> occurrences of the string `// init.dmi - THIS FILE IS AUTO-GENERATED`. **A file carrying that
> marker is not run; a file without it is.** There is a second marker of the same kind —
> `// !--- This comment is used by WebIf to save the ---!` — which decides whether `set` lines
> inside the file get commented out before it runs.
>
> ⇒ **Both markers are provenance claims carried in a comment, and a comment is not
> provenance.** A file that simply omits them is executed in full, with its `set` lines intact.
> ⚠️ **And they were not written as security controls** — they exist to stop the device
> re-running its own generated configuration. **They are load-bearing for security anyway**,
> which is the usual way this happens.
>
> ⭐ **The transferable lesson: when you meet an integrity check on an embedded device, ask what
> it would cost an author to omit. If the answer is "delete one line", it is a marker, not a
> check.**
>
> ☠️ **And it bites the author, not just the attacker — we nearly shipped this exact failure.** A
> first draft of one of our own `init.dmi` files carried a comment *explaining* the autogen
> banner, and **that explanatory comment contained the banner text**. The device's `grep -c` is
> unanchored and counts occurrences anywhere in the file, so it returned 1, and the script would
> have been **silently skipped** — no error, no log line, just a boot where nothing applied.
> ⇒ **The warning would have caused the exact failure it was warning about.** **Do not write the
> marker string into a file you want executed, in any context, including a comment about the
> marker.**

### ✅ The defence — which is the reason this is written down at all

**Close the console. Either condition breaks the chain, and either is one write:**

```
ENV_START_DMI_TELNET = FALSE      # via the vendor's own NV setter, then reboot
```
— or install **any** `init.dmi` at all, which takes the other branch and never opens the port.

> ### ⚠️ And the trade nobody discovers until it has cost them a cycle
> **Installing an `init.dmi` CLOSES `:8090`.** The two are **mutually exclusive by
> construction** — they are the two arms of one `if`. And `init.dmi` is a genuinely useful
> feature: it is how you make settings apply at boot with no management server anywhere.
> ⇒ **Deploy one and you have closed your own way in.** **Have another route working first**,
> and test it before you upload.
>
> ⚠️ **And the consequence reaches your tooling, not just your next session.** Any bring-up
> script that drives the console over `:8090` **cannot run against a unit that has an
> `init.dmi`** — not because it is broken, but because the port it needs does not exist on that
> unit. ⇒ **A tool written for a unit without `init.dmi` cannot bring up a unit with one**, and
> it will fail at connect with no indication that the cause is a file you installed deliberately
> weeks earlier. **If you install one, your bring-up path has to move to a transport that does
> not depend on that port** — the one-shot client over SSH, per
> [Route 2](#route-2--the-dmi-management-console).

**On the injection itself there is nothing to patch** — no vendor, no firmware update — so the
defence is architectural:

- ⭐ **Treat the DMI console as a root-equivalent interface, because on this hardware it is
  one.** It is not a "config port" with a smaller blast radius. Anything that can write
  attributes can write a file that runs as root.
- **Put it behind what you would put a root shell behind** — in practice an isolated segment,
  since as noted the device's own firewall is opened by the same branch that opens the port.
- **Neither of those is exotic, and both are things you would do anyway** for a surplus carrier
  device with a dead management path.

⚠️ **One robustness note if you edit `nv_env.sh` by any route:** it has **no backup and is
rewritten non-atomically on every boot** — two whole-file `sed` passes and an append. **A power
cut inside that window leaves a corrupted environment with nothing to restore from.** That is a
hazard for ordinary configuration work, quite apart from anything above.

> ### ⭐ "No backup" is measured, and it is worth knowing *why* it is not obvious
> The vendor's setter edits with `sed -ie`, which **looks** like it requests a backup suffix.
> On this firmware's BusyBox it does not — **`-i` there takes no attached suffix, so `-ie` parses
> as `-i -e` and nothing is backed up.** `[measured on the device: BusyBox v1.9.2 (2011), whose
> own help prints a bare `-i`; a direct run left no suffixed file.]` ⚠️ **On a modern BusyBox the
> identical flag DOES write a backup** — see
> [trap 56](TRAPS.md#56-sed--ie-may-or-may-not-have-made-a-backup-and-the-flag-cannot-tell-you),
> because the version boundary is the whole finding.
>
> ✅ **So back it up yourself, by convention, before you touch it.** On our unit the only copies
> that exist are ones we made by hand. ⇒ **A reader who trusts the flag gets nothing; a reader
> who copies first gets everything.**

---

⛔ **What this repo does not contain, deliberately:** a working payload, or a construction
sequence you could follow without understanding it. **Mechanisms are described** — in enough
detail to verify on your own unit, because a description too vague to check is not
documentation — **and the assembled article is not.** The test applied above: a reader should
finish understanding the *class* of bug, and be unable to skip straight to a tool. That boundary
is in the [README](../README.md#scope-your-hardware-your-core) and it is not an oversight.

---

## Which of these are verified?

| route | status |
|---|---|
| SSH to the picoChip with legacy algorithms | **measured live**, DPH-151 |
| DMI one-shot client answering get/set/action | **measured live**, DPH-151 |
| DMI on TCP 8090 | **measured live: not listening by default** on our DPH-151, and its telnet front end did not answer once started. **"Unauthenticated" is inferred on a MicroCell, never measured there.** |
| DMI on TCP 8090, unauthenticated, as a root path | **measured live, ip.access nano3G** — console, file read, and the `nv_env.sh` injection sink. **Not reproduced on any DPH**, where the port did not listen. See [Route 6](#route-6--the-nano3gs-dmi-console-where-the-management-plane-is-the-root-path). |
| `init.dmi` closing `:8090` | **read from `opnormal` on a nano3G** — the two paths are arms of one `if`. Not tested by installing one. |
| Ralink has no SSH server | **read from a firmware image**, not confirmed on a live device |
| Ralink telnet / IPC / `wizard` backdoor | **reported** (fail0verflow 2012); `wizard` binary **present** in 151 and 153 images |
| serial console pinout and baud | **reported** (fail0verflow 2012) |
| anything at all on the DPH-154 | **unverified** |

---

## Route 0b — **THE RALINK IS THE FIRST BEACHHEAD, AND IT IS OPEN ON AN UNPROVISIONED UNIT**

> ### 🎯 **MEASURED LIVE ON `.106` (151#2), 2026-09-13 ~17:0x PDT. Root in one connect, no exploit, no injection, nothing mutated.**

```
1. HOST ROUTES (already present on katana; add on any host that needs them)
     ip route add 192.168.157.185/32 via <the unit's LAN IP>     <- Ralink
     ip route add 192.168.157.186/32 via <the unit's LAN IP>     <- picoChip
2. telnet 192.168.157.185     ->  login: root     ->  NO PASSWORD ASKED
     BusyBox v1.8.2 (2012-04-20) ash.  uid 0.
```

### ⛔ **THE THREE THINGS THAT COST HOURS HERE, ALL INSTRUMENT FAILURES, NOT DEVICE FACTS**

```
katana has NO telnet binary        -> `apt install telnet`. Do this FIRST. I narrated this
                                      blocker three times instead of spending 20 seconds on it.
Ralink busybox has NO nc, NO head, -> `nc -z .186 3001` printed "shut3001" because nc DOES NOT
NO tr, NO id, no `busybox --list`     EXIST. That is a FALSE ZERO, not a closed port.
UDP/14677 tested over TCP          -> the wizard backdoor is UDP. A TCP probe of a UDP service
                                      answers "closed" for every unit, working or not.
```
⭐ **Every one is the same species: a true statement about a narrower universe than the claim it
supported.** ✅ **On this device, run the utility check BEFORE the measurement**, and treat
"not found" as a broken instrument rather than a result.

### 📋 **WHAT THE RALINK GIVES YOU, AND WHAT IT DOES NOT**

```
/usr/sbin:  rmm_client  cs_client  ipc_client  ipc_server  config_server
            telnetd  udhcpd  chpasswd  setlogcons          <- that is the WHOLE toolbox

rmm_client <ip> <command>, command list:
  reset  factory_reset  clear_tamper  do_software_download  get_software_status
  set_bandwidth  get_bandwidth  switch_fw_boot  set_telnetd  set_port_fwd
  get_uptime  cs_cmd  sleep  crash
     rmm_client 192.168.157.185 set_telnetd 0/1
     rmm_client 192.168.157.185 set_port_fwd proto port action
```
⛔⛔ **`factory_reset` AND `crash` ARE IN THAT LIST, ONE WORD FROM `cs_cmd`. Never type them.**

✅ **Works:** `rmm_client 192.168.157.185 cs_cmd "<cmd>"` — runs as root ON THE RALINK. Verified
with an echo marker.
🔴 **Does NOT work on an unprovisioned unit:** the same call against `192.168.157.186` returns
**`Can't read response from peer`**, and so does `get_uptime`. ⇒ **The pico's rmm/IPC responder
is DOWN, not filtered.** `findings-dph151-pico.md` recorded this on 2026-09-05 and it is still
true on a different unit eight days later — so it is a property of the UNPROVISIONED STATE, not
of that one box.

### 🔴 **AND THE PICO IS SEALED FROM EVERY INBOUND DIRECTION ON AN UNPROVISIONED UNIT**
`[measured on .106, each with a passing control]`
```
10.0.6.106:22 / .186:22   CLOSED   <- dropbear is NOT on 0.0.0.0 because
                                      ENV_VERBOSE_CONSOLE_ENABLED != TRUE. THIS IS THE LOCK.
udp/69 TFTP               no answer
tcp 80 / 443 / 8080 / 8090  CLOSED  <- so the dmi_config.cgi FILE-UPLOAD route is NOT available
pico IPC 3001             responder down
CONTROL: .185:23          OPEN      <- the probe works; the zeros above are real
```
⇒ ⭐⭐⭐ **THE RALINK IS ROOT AND THE PICO IS UNTOUCHED. Getting one does NOT get you the other,
and the guides that teach pico→Ralink have the dependency BACKWARDS** — on a factory-fresh unit
the Ralink is reachable first and the pico is behind default-deny.

### ✅ **THE EXACT COMMAND THAT UNLOCKED `.244`'s PICO — recovered from `microcell/build/dph151/pico-dump-*.dbg`**
```sh
grep -q pounce-rce /var/ipaccess/root_home/.ssh/authorized_keys 2>/dev/null || \
  echo "ssh-rsa AAAA… cwmp_rce_proof pounce-rce" >> /var/ipaccess/root_home/.ssh/authorized_keys
/opt/ipaccess/bin/setnv_env.sh ENV_START_DMI_TELNET TRUE
# DPH151_SSH_PERSIST_BEGIN
/opt/ipaccess/bin/setnv_env.sh ENV_VERBOSE_CONSOLE_ENABLED TRUE
/opt/ipaccess/bin/setnv_env.sh ENV_START_DMI_TELNET TRUE
iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT
```
⚠️ **THAT IS THE PERSISTENCE STEP, NOT THE ENTRY.** The `.dbg` shows it delivered **over SSH to
`10.0.6.244:22`, answered by `dropbear_0.50`** — i.e. the pico's sshd was ALREADY listening when
this ran. ⛔ **Do not read it as the way in.** `ENV_START_DMI_TELNET TRUE` is what opens `:8090`.

### ⛔ **STILL OPEN, STATED AS OPEN: RALINK ROOT → A WRITE ON THE PICO'S FILESYSTEM**
**That single step is the whole remaining gap on an unprovisioned unit.** Candidates, none yet
demonstrated: `rmm_client … do_software_download` / `switch_fw_boot` (the swdl path, where
`post_swdl_hook` runs as root — ⚠️ it also `rm -rf`s the config bank, so stage a payload FIRST),
or the pico's own outbound ACS leg per Route 0.
