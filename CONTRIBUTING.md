# Contributing

Corrections are welcome — **especially measurements that contradict what is written here.**
This repository is one lab's logbook and the logbook was wrong a lot. A correction with a
reading attached is worth more than agreement.

## How to state a claim

Use the same evidence vocabulary the README does, and put the uncertainty **in the sentence**,
not in a footnote:

- **measured** — you observed it on real hardware and wrote down the reading
- **inferred** — it follows from something measured, but was not itself observed
- **reported** — someone else published it and you did not reproduce it

**Always say which model and which firmware train you measured on.** The models differ in ways
that matter, and an instruction that is correct for one can destroy another.

## Licence of contributions

By submitting a pull request you agree that your contribution is licensed under the same terms
as this repository — **CC BY-SA 4.0 for documentation, GPL-3.0 for code** — and that you have
the right to grant that licence. If you are contributing on behalf of an employer, confirm you
are authorised to do so.

## ⛔ Do not contribute

- **vendor firmware**, firmware images, or extracted filesystems
- **private keys**, SIM secrets (Ki / OPc / ADM), IMEIs, or device serial numbers
- **anything obtained from a network or a device you do not own**
- **your own LAN addresses** — use the placeholder style already in the docs

`tools/pre-publish-check.sh` scans for most of these and carries its own positive control.
Run it before you open a PR. **A red gate is a blocker, not a warning.**

## Safety content

This repository documents access paths to hardware people own, and warnings are part of the
content, not decoration. **If you add a step that enables radio transmission, carry the
spectrum and emergency-calling warnings with it.** A warning that lives only on the front page
is a warning the reader never meets.
