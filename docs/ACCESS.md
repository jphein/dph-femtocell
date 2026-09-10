# Access: getting into the device

**Scope: the shell-level detail is measured on a DPH-151. The two-processor architecture is
established for the 151 and 153. The DPH-154 is a different design — see
[`HARDWARE.md`](HARDWARE.md) — and none of the chip-level detail here should be assumed to
apply to it.**

---

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
> 2. **"Unauthenticated" is INFERRED, not measured.** No login step appears in any documented
>    sequence, but nobody here has demonstrated the port is unauthenticated on a MicroCell.
>    Our own notes say so in as many words. Do not plan around it.
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

What it does have is **`telnetd`, bound to the internal point-to-point address only** — so
it is not reachable from your LAN, and every path to it goes through the picoChip.

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

The TR-069 / CWMP stack is a legitimate **configuration** path. If you control DNS for the
device — and you do, since it is on your network and its management hostnames are dead — you
can answer as its management server without touching the device at all. See
[`CONFIG.md`](CONFIG.md).

⚠️ **It is not how root is obtained on this device**, despite a widely-repeated name that says
otherwise. See the correction under Route 3.

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

⛔ **What this repo does not contain, deliberately:** working payloads, or the construction of
anything meant to be *served to* a device. Where a trap can only be explained by reproducing
such a chain, this guide describes the **symptom and the defence** and stops. That boundary is
in the [README](../README.md#scope-your-hardware-your-core) and it is not an oversight.

---

## Which of these are verified?

| route | status |
|---|---|
| SSH to the picoChip with legacy algorithms | **measured live**, DPH-151 |
| DMI one-shot client answering get/set/action | **measured live**, DPH-151 |
| DMI on TCP 8090 | **measured live: not listening by default** on our DPH-151, and its telnet front end did not answer once started. Works on sibling ip.access hardware. "Unauthenticated" is **inferred, never measured**. |
| Ralink has no SSH server | **read from a firmware image**, not confirmed on a live device |
| Ralink telnet / IPC / `wizard` backdoor | **reported** (fail0verflow 2012); `wizard` binary **present** in 151 and 153 images |
| serial console pinout and baud | **reported** (fail0verflow 2012) |
| anything at all on the DPH-154 | **unverified** |
