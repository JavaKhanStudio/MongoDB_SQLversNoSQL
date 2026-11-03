#!/usr/bin/env python3
"""Joue dans le vrai programme d'un pack hors ligne les lignes que les SUJET.md
donnent a l'eleve : le menu, puis \\i sujets/relations.sql et \\i .../controle.sql
dans psql, et mongosh avec use <base>. Le pack se fabrique dans le depot ficelle.

    ./ficelle pack ~/Documents/GitHub/MongoDB_SQLversNoSQL --manifest tests/pack/sqlversnosql.toml --out <d>
    tools/pack_lignes.py <d>/SQL_vers_NoSQL <sortie> [attendu-<sujet>.txt ...]

Chaque attendu est la sortie de make <sujet>-controle. Sort en 1 si une ligne manque.
"""
import os, re, subprocess, sys, tempfile, threading, time
from pathlib import Path

pack, out = Path(sys.argv[1]).resolve(), Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
attendus = {Path(a).stem.split('-')[-1]: Path(a) for a in sys.argv[3:]}
SUJETS = [('dune', '1-dune'), ('tortues', '2-tortues'), ('bateaux', '3-bateaux')]
work = tempfile.mkdtemp(prefix='pack-lignes-')
env = dict(os.environ, FICELLE_NO_BROWSER='1', HOME=work, XDG_DATA_HOME=work + '/xdg')
p = subprocess.Popen([str(pack / 'Ouvrir - Linux')], cwd=tempfile.gettempdir(), env=env, stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
buf = bytearray()
threading.Thread(target=lambda: [buf.extend(c) for c in iter(lambda: p.stdout.read1(65536), b'')], daemon=True).start()
vu = 0
def jusqua(mot, delai=240):
    global vu
    fin = time.time() + delai
    while time.time() < fin:
        i = buf.find(mot.encode(), vu)
        if i >= 0:
            s = buf[vu:i].decode('utf-8', 'replace'); vu = i + len(mot); return s
        time.sleep(.1)
    raise SystemExit('rien vu : ' + mot + '\n' + buf[vu:].decode('utf-8', 'replace')[-2000:])
def envoie(*l):
    p.stdin.write(('\n'.join(l) + '\n').encode()); p.stdin.flush()

mauvais = []
jusqua('Votre choix')
for n, (s, d) in enumerate(SUJETS, 1):
    envoie(str(n)); time.sleep(.5)
    envoie('\\i sujets/relations.sql', '\\i sujets/%s/controle.sql' % d, '\\q')
    dit = jusqua('Votre choix')
    (out / (s + '.txt')).write_text(dit)
    if 'error' in dit.lower() or 'erreur' in dit.lower() or 'No such file' in dit:
        mauvais.append(s + ' : une erreur dans psql')
    if s in attendus:
        manque = [l for l in attendus[s].read_text().splitlines() if l.strip() and l.rstrip() not in dit]
        print(s, 'controle :', 'identique' if not manque else '%d lignes manquent' % len(manque))
        if manque: mauvais.append(s + ' : ' + manque[0])
envoie('4'); time.sleep(1)
envoie('db.getName()', 'use tortues', 'db.getName()', 'exit')
dit = jusqua('Votre choix')
(out / 'mongosh.txt').write_text(dit)
print('mongosh :', re.findall(r'(?m)(?:^|> )(dune|tortues)\s*$', dit))
envoie('0')
try: p.wait(60)
except subprocess.TimeoutExpired: p.kill()
print('\n'.join(mauvais) or 'all ok')
sys.exit(1 if mauvais else 0)
