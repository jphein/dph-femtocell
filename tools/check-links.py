#!/usr/bin/env python3
r"""Validate every relative link and #anchor across this repo's Markdown.

Once these pages are served as a site, a broken anchor is broken navigation
rather than a cosmetic miss, and nothing else in this repo checks them.

    python3 tools/check-links.py

Exit 0  every link resolves
Exit 1  at least one does not
Exit 2  the checker failed its own positive control, and its results -- pass
        OR fail -- mean nothing. Do not interpret them.

WHY THE CONTROL MATTERS HERE. `slug()` below is a reimplementation of GitHub's
heading-to-anchor rule. A reimplementation that has drifted does not fail
loudly: it reports either everything broken or everything fine, depending on
which way it drifted, and both look like a decisive answer. So there are two
controls, because either one alone leaves a blind side:

  (a) the rule must reproduce MEASURED heading->anchor pairs  -> catches drift
                                                                toward false alarms
  (b) a deliberately bad anchor must be CAUGHT                -> catches drift
                                                                toward false silence

The first version of this file got (a) wrong in a way worth recording, since
the same shape will recur. It shipped with `\s+` instead of `\s` -- collapsing
runs of whitespace -- so every heading containing an em-dash or an ampersand
("Flashing -- the last resort") produced one hyphen where GitHub produces two,
and five perfectly good links were reported broken.

Two things let that through:

  1. The docstring claimed control (a) and the code did not implement it. What
     stood in for it was the ordinary run, which is circular: a wrong rule
     produces broken links, and the code reported those as broken links rather
     than as a failed control.
  2. Even a correct implementation of "reproduce the anchors already in this
     repo" would have PASSED, because at the time every heading in this repo
     used commas rather than em-dashes. The corpus never exercised the rule
     under test. A control that cannot fail is decoration.

So CONTROL_SLUGS below is a fixture table of pairs MEASURED against rendered
documents that actually contain the awkward cases -- not derived from anyone's
belief about what the rule is.

Known limitation, stated rather than hidden: GitHub disambiguates repeated
identical headings with -1/-2 suffixes. This checker does not model that, so a
link to the second of two identical headings is reported broken. It has not
come up; if it does, fix it here rather than working around it in the docs.
"""
import os
import re
import sys
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# (heading, expected anchor) -- MEASURED, not reasoned. The first two exercise
# the case that broke this checker once: a character that is DELETED from
# between two spaces, leaving two spaces, which become two hyphens.
CONTROL_SLUGS = [
    ("12. Prior art & credits", "12-prior-art--credits"),
    ("10. Flashing \u2014 the last resort", "10-flashing--the-last-resort"),
    ("6. `show hnb` on the core lies in **both** directions",
     "6-show-hnb-on-the-core-lies-in-both-directions"),
    ("25. It registers, de-registers ~15 seconds later, and it is **not** the famous bug",
     "25-it-registers-de-registers-15-seconds-later-and-it-is-not-the-famous-bug"),
]


def slug(heading: str) -> str:
    r"""GitHub's heading -> anchor rule: lowercase, drop punctuation, EACH space to a hyphen.

    `\s` and not `\s+`. Deleting a character from between two spaces leaves two
    spaces, and GitHub emits two hyphens. See CONTROL_SLUGS.
    """
    t = re.sub(r"[^\w\s-]", "", heading.strip().lower()).strip()
    return re.sub(r"\s", "-", t)


def md_files():
    out = []
    for pat in ("*.md", "docs/*.md", "config/*.md", "tools/*.md"):
        out += sorted(glob.glob(os.path.join(ROOT, pat)))
    return out


def headings(text):
    return {slug(m.group(2)) for m in re.finditer(r"^(#{1,6})\s+(.+?)\s*$", text, re.M)}


LINK = re.compile(r"\]\(\s*([^)\s#]*)\s*(?:#([A-Za-z0-9\-_]+))?\s*\)")


def check(files, texts, heads):
    """Return a list of (file, link, reason)."""
    bad = []
    for f in files:
        for m in LINK.finditer(texts[f]):
            path, anchor = m.group(1), m.group(2)
            if path.startswith(("http://", "https://", "mailto:")):
                continue
            if not path and not anchor:
                continue
            target = f if not path else os.path.normpath(
                os.path.join(os.path.dirname(f), path))
            if path:
                if not os.path.exists(target):
                    bad.append((f, m.group(0), "target file does not exist"))
                    continue
                if not target.endswith(".md"):
                    continue          # a real file, not a page we parse
            if anchor:
                if target not in heads:
                    bad.append((f, m.group(0), "target not scanned"))
                elif anchor not in heads[target]:
                    bad.append((f, m.group(0), "no such heading in target"))
    return bad


def main():
    files = md_files()
    if not files:
        print("FAIL: no Markdown found. The checker is looking in the wrong place.")
        return 2
    texts = {f: open(f, encoding="utf-8").read() for f in files}
    heads = {f: headings(texts[f]) for f in files}

    total_links = sum(len(LINK.findall(t)) for t in texts.values())
    total_heads = sum(len(h) for h in heads.values())

    # --- positive control (a): the rule reproduces MEASURED pairs --------------
    drift = [(h, want, slug(h)) for h, want in CONTROL_SLUGS if slug(h) != want]
    if drift:
        print("  🔴 CONTROL FAILED: slug() no longer matches measured GitHub anchors.")
        for h, want, got in drift:
            print(f"     {h!r}\n       want {want}\n       got  {got}")
        print("     Every result from this run is meaningless, including a clean one.")
        return 2
    print(f"  control ✅ slug rule reproduces {len(CONTROL_SLUGS)} measured anchors")

    real = check(files, texts, heads)
    # --- positive control (b): a planted bad anchor is caught ------------------
    probe_file = files[0]
    probe = "\n\n[control probe](#anchor-that-cannot-exist-zzqq)\n"
    texts_p = dict(texts)
    texts_p[probe_file] = texts[probe_file] + probe
    caught = [b for b in check(files, texts_p, heads) if "zzqq" in b[1]]

    print(f"  files {len(files)} · headings {total_heads} · links {total_links}")
    if not caught:
        print("  🔴 CONTROL FAILED: a deliberately broken anchor was NOT caught.")
        print("     Every result from this run is meaningless, including a clean one.")
        return 2
    print(f"  control ✅ planted anchor caught ({len(caught)})")

    if real:
        print(f"  🔴 {len(real)} broken link(s):")
        for f, link, why in real:
            print(f"     {os.path.relpath(f, ROOT)}: {link}  -- {why}")
        return 1
    print("  ✅ all links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
