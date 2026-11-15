"""Statische controle met luac5.1:
1. CarefreeBag schrijft alleen naar de globals die het echt nodig heeft.
2. Geen bestand leest een gedeelde naam als global terwijl die in `ns` staat
   (dan ben je `ns.` of `local X = ns.X` vergeten).
Gebruik (vanuit de repo):  python3 tests/check_globals.py"""
import re, subprocess, sys

ALLOWED_WRITES = {"CarefreeBagDB", "SLASH_CAREFREEBAG1", "SLASH_CAREFREEBAG2"}
toc = open("CarefreeBag.toc", encoding="utf-8").read()
files = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
shared = set()
for f in files:
    shared |= set(re.findall(r"\bns\.([A-Za-z_]\w*)", open(f, encoding="utf-8").read()))
bad = False
for f in files:
    out = subprocess.run(["luac5.1", "-p", "-l", f], capture_output=True, text=True)
    if out.returncode:
        print(out.stderr); bad = True; continue
    for line in out.stdout.splitlines():
        m = re.search(r"\[(\d+)\]\s+(SETGLOBAL|GETGLOBAL)\s.*;\s*(\S+)", line)
        if not m: continue
        lineno, op, name = m.groups()
        if op == "SETGLOBAL" and name not in ALLOWED_WRITES:
            print(f"{f}:{lineno}: writes global '{name}'"); bad = True
        if op == "GETGLOBAL" and name in shared and name not in ("L",):
            print(f"{f}:{lineno}: reads '{name}' as a global, but it lives in ns (use ns.{name})"); bad = True
print("globals: " + ("PROBLEMS found" if bad else "ok"))
sys.exit(1 if bad else 0)
