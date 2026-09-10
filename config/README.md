# Core-network config templates

These are **templates with placeholders**, not deployable files. Replace every
`<PLACEHOLDER>` before use, and read the comments — several of them record a setting whose
default is wrong for this hardware.

| file | what it is |
|---|---|
| `osmo-hnbgw.cfg.example` | the Iuh gateway the femtocell talks to |

## ⛔ Before you run any "deploy" line in these files

A restore procedure's natural voice is *"run this to get back to known-good"*, which is
indistinguishable from *"run this over a working system"*. **Both situations produce
identical prose, and the document cannot tell which one you are in.**

If you already have a working config, an `install` from here **overwrites it** — including
anything you changed since. Diff first.

⚠️ **And diff per section.** A whole-line diff of a sectioned config file (`.conf`, `.cfg`,
`.ini`-shaped anything) compares lines across the *whole file*, so a directive that exists
under one section reads as PRESENT when the section that needs it lacks it. We lost a live
setting exactly that way and the diff reported nothing.

## What is not here

The rest of the core — `osmo-msc`, `osmo-mgw`, `osmo-hlr`, `osmo-stp`, SIP/PBX integration
— is ordinary Osmocom configuration and is documented far better upstream than we could do
here. This repo is about the *radio unit*. Start from the Osmocom manuals and come back
here for the femtocell-specific parts.
