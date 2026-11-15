"""Controleert of elke tekst T("...") in alle 7 vertalingen staat (Engels is de tekst zelf).
Gebruik (vanuit de repo):  python3 tests/check_locales.py"""
import glob, re, sys

code = "".join(open(f, encoding="utf-8").read() for f in glob.glob("*.lua") if f != "Locales.lua")
keys = set(re.findall(r'\bT\("((?:[^"\\]|\\.)*)"\)', code))
loc = open("Locales.lua", encoding="utf-8").read()
blocks = re.split(r"^ns\.L\.(\w+) = \{", loc, flags=re.M)
langs = {blocks[i]: set(re.findall(r'\["((?:[^"\\]|\\.)*)"\]', blocks[i + 1])) for i in range(1, len(blocks), 2)}

bad = False
for lang in ["nl", "de", "fr", "es", "pt", "it", "ru"]:
    have = langs.get(lang)
    if have is None:
        print(f"{lang}: missing table"); bad = True; continue
    missing = sorted(k for k in keys if k not in have)
    for k in missing:
        print(f"{lang}: missing {k!r}")
    bad = bad or bool(missing)
print(f"{len(keys)} texts, {len(langs)} languages: " + ("NOT complete" if bad else "complete"))
sys.exit(1 if bad else 0)
