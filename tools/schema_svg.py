#!/usr/bin/env python3
# =====================================================================
#  Dessine le schema SQL de chaque sujet : sujets/<n>/schema.svg
#
#  Les tables, leurs colonnes, leurs cles et leurs relations sont LUES
#  dans le catalogue PostgreSQL de la base chargee, jamais recopiees a la
#  main : un schema.sql qui change, et le dessin suit. Seule la PLACE
#  des tables est ecrite ici (DISPOSITIONS), parce qu'un placement
#  automatique emmele les fleches.
#
#    make demarrer && make tout
#    python3 tools/schema_svg.py              # les trois sujets
#    python3 tools/schema_svg.py dune         # un seul
#
#  PSQL='podman exec -i autre-conteneur psql -U postgres' pour lire
#  ailleurs que dans sqlnosql-postgres.
# =====================================================================
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
PSQL = os.environ.get("PSQL", "docker exec -i sqlnosql-postgres psql -U postgres")

CATALOGUE = r"""
SELECT json_agg(t ORDER BY t.name) FROM (
 SELECT c.relname AS name,
  (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from %I', c.relname),
         false, true, '')))[1]::text::int AS lignes,
  (SELECT json_agg(json_build_object(
     'nom', a.attname,
     'type', replace(format_type(a.atttypid, a.atttypmod), ' without time zone', ''),
     'notnull', a.attnotnull,
     'pk', EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid
                   AND k.contype = 'p' AND a.attnum = ANY (k.conkey)),
     'pk_seule', EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid
                   AND k.contype = 'p' AND k.conkey = ARRAY[a.attnum]),
     'unique', EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid
                   AND k.contype = 'u' AND k.conkey = ARRAY[a.attnum]),
     'fk', (SELECT fc.relname FROM pg_constraint k JOIN pg_class fc ON fc.oid = k.confrelid
            WHERE k.conrelid = c.oid AND k.contype = 'f' AND a.attnum = ANY (k.conkey) LIMIT 1),
     'nuls', CASE WHEN a.attnotnull THEN 0 ELSE
       (xpath('/row/v/text()', query_to_xml(format('select count(*) - count(%I) as v from %I',
              a.attname, c.relname), false, true, '')))[1]::text::int END
   ) ORDER BY a.attnum)
   FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS colonnes
 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r') t;
"""

# ---------------------------------------------------------------------
#  La place des tables : colonne de la grille, puis ordre de haut en bas.
#  Un nombre a la place d'un nom est un blanc vertical, en pixels.
#  Une relation ne relie que deux colonnes VOISINES ou une meme colonne :
#  c'est ce qui garde les fleches hors des boites.
# ---------------------------------------------------------------------
DISPOSITIONS = {
    "dune": {
        "dossier": "1-dune",
        "titre": "Sujet 1 — Dune",
        "colonnes": [
            ["region", "ver", "puits", "releve_vibration"],
            [40, "collecte"],
            ["plateforme_minage", "compatibilite", "plateforme_transport", "contremaitre"],
        ],
    },
    "tortues": {
        "dossier": "2-tortues",
        "titre": "Sujet 2 — Les tortues",
        "colonnes": [
            ["tag", "tortue_tag", 60, "observateur"],
            ["tortue", 40, "observation"],
            ["espece", "inscription", "habitat", "site"],
            ["pays", "organisation", "programme", "protocole"],
        ],
    },
    "bateaux": {
        "dossier": "3-bateaux",
        "titre": "Sujet 3 — Les bateaux",
        "colonnes": [
            [60, "armateur", "bateau_civil", "bateau_militaire", "marine"],
            ["bateau", 40, "affectation", "capitaine"],
            ["pays", "port", "quai", "escale", "cargaison"],
        ],
    },
}

# ---------------------------------------------------------------------
#  Metrique
# ---------------------------------------------------------------------
CAR = 7.25          # largeur d'un caractere mono a 12 px
LIGNE = 18          # hauteur d'une ligne de colonne
ENTETE = 28         # hauteur de l'en-tete d'une table
PAD = 12            # marge interieure
ECART_V = 30        # entre deux tables d'une meme colonne
COULOIR = 34        # couloir minimal entre deux colonnes de tables
PISTE = 13          # ecart entre deux fleches paralleles d'un couloir
MARGE = 24
HAUT = 58           # place du titre

STYLE = """
  .fond { fill: #fbfdfc; }
  .boite { fill: #ffffff; stroke: #c3d1cb; stroke-width: 1; }
  .entete { fill: #e6edf4; }
  .entete-liaison { fill: #efe7f4; }
  .nul { fill: #b64d28; opacity: .10; }
  .t { font-family: ui-monospace, "SF Mono", Menlo, Consolas, "DejaVu Sans Mono", "Liberation Mono", monospace; font-size: 12px; fill: #0f221e; }
  .ttable { font-weight: 700; fill: #2c5a86; }
  .tliaison { fill: #6b3d86; }
  .tdoux { fill: #6b7f78; }
  .tcle { fill: #2c5a86; font-weight: 600; }
  .tnul { fill: #b64d28; font-weight: 600; }
  .titre { font-family: "Public Sans", "Helvetica Neue", Arial, sans-serif; font-size: 19px; font-weight: 700; fill: #0f221e; }
  .sous { font-family: "Public Sans", "Helvetica Neue", Arial, sans-serif; font-size: 13px; fill: #4c635c; }
  .lien { fill: none; stroke: #2c5a86; stroke-width: 1.4; }
  .pointe { fill: #2c5a86; }
  .card { font-family: "Public Sans", "Helvetica Neue", Arial, sans-serif; font-size: 11px; font-weight: 700; fill: #2c5a86; }
  @media (prefers-color-scheme: dark) {
    .fond { fill: #0d1714; }
    .boite { fill: #111e1a; stroke: #2e443a; }
    .entete { fill: #16283a; }
    .entete-liaison { fill: #2a1d33; }
    .nul { fill: #e2865e; opacity: .16; }
    .t { fill: #e4ede8; }
    .ttable, .tcle, .card { fill: #83b0dc; }
    .tliaison { fill: #c49be0; }
    .tdoux { fill: #8fa39c; }
    .tnul { fill: #e2865e; }
    .titre { fill: #e4ede8; }
    .sous { fill: #a3b7af; }
    .lien { stroke: #83b0dc; }
    .pointe { fill: #83b0dc; }
  }
"""


def echapper(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def lire_catalogue(base):
    cmd = shlex.split(PSQL) + ["-d", base, "-tA", "-v", "ON_ERROR_STOP=1"]
    sortie = subprocess.run(cmd, input=CATALOGUE, capture_output=True, text=True, check=True).stdout
    return {t["name"]: t for t in json.loads(sortie)}


def court(type_):
    return type_.replace("character varying", "varchar")


def nature(table):
    """'M:N' pour une liaison, '1:1' pour une table dont la cle est une cle etrangere."""
    pk = [c for c in table["colonnes"] if c["pk"]]
    if len(pk) >= 2 and sum(1 for c in pk if c["fk"]) >= 2:
        return "M:N"
    if len(pk) == 1 and pk[0]["fk"]:
        return "1:1"
    return None


def cle(c):
    morceaux = []
    if c["pk"]:
        morceaux.append("PK")
    if c["fk"]:
        morceaux.append("→ " + c["fk"])
    elif c["unique"]:
        morceaux.append("unique")
    return " ".join(morceaux)


def nul(c, lignes):
    if c["notnull"] or not c["nuls"] or not lignes:
        return ""
    return f"NULL {round(100 * c['nuls'] / lignes)} %"


def dessiner(nom, disp, tables):
    grille = disp["colonnes"]
    places = [n for col in grille for n in col if isinstance(n, str)]
    manquantes = sorted(set(tables) - set(places))
    inconnues = sorted(set(places) - set(tables))
    if manquantes or inconnues:
        sys.exit(f"{nom} : DISPOSITIONS ne correspond plus au schema — "
                 f"absentes du dessin {manquantes}, absentes de la base {inconnues}")

    # largeur de chaque colonne de la grille : la plus large de ses tables
    largeurs, champs = [], []
    for col in grille:
        noms = [n for n in col if isinstance(n, str)]
        cs = [(c, tables[n]["lignes"]) for n in noms for c in tables[n]["colonnes"]]
        w_nom = max(len(c["nom"]) for c, _ in cs)
        w_type = max(len(court(c["type"])) for c, _ in cs)
        w_cle = max(len(cle(c)) for c, _ in cs)
        w_nul = max(len(nul(c, l)) for c, l in cs)
        w_tete = max(len(n) + len(f" · {tables[n]['lignes']} lignes") + 5 for n in noms)
        corps = (w_nom + 2 + w_type + 2 + w_cle + (2 + w_nul if w_nul else 0)) * CAR
        largeurs.append(max(corps, w_tete * CAR) + 2 * PAD)
        champs.append((w_nom, w_type, w_cle))

    # les relations, pour dimensionner les couloirs
    col_de = {n: i for i, col in enumerate(grille) for n in col if isinstance(n, str)}
    relations = []
    for n, t in tables.items():
        for c in t["colonnes"]:
            if c["fk"]:
                a, b = col_de[n], col_de[c["fk"]]
                if abs(a - b) > 1:
                    sys.exit(f"{nom} : {n} -> {c['fk']} saute une colonne de la grille")
                relations.append((n, c, c["fk"]))

    # positions
    boites = {}
    x = MARGE + 3 * PISTE
    xs = []
    for i, col in enumerate(grille):
        xs.append(x)
        y = HAUT
        for n in col:
            if not isinstance(n, str):
                y += n
                continue
            h = ENTETE + LIGNE * len(tables[n]["colonnes"]) + 8
            boites[n] = dict(x=x, y=y, w=largeurs[i], h=h, col=i)
            y += h + ECART_V
        x += largeurs[i] + COULOIR + 4 * PISTE
    largeur_totale = x - COULOIR - 4 * PISTE + 3 * PISTE + MARGE

    def y_colonne(n, nom_col):
        b = boites[n]
        k = [c["nom"] for c in tables[n]["colonnes"]].index(nom_col)
        return b["y"] + ENTETE + LIGNE * k + LIGNE / 2 + 1

    # chaque relation : un depart (ligne de la cle etrangere), une arrivee
    # (ligne de la cle primaire visee), et un couloir. Le couloir k est
    # celui de gauche de la colonne k ; le dernier borde la derniere colonne.
    charge = [0] * (len(grille) + 1)
    for n, c, cible in relations:
        a, b = col_de[n], col_de[cible]
        if a != b:
            charge[max(a, b)] += 1
    traces = []
    for n, c, cible in relations:
        s, d = boites[n], boites[cible]
        pk_cible = next(k["nom"] for k in tables[cible]["colonnes"] if k["pk"])
        y1, y2 = y_colonne(n, c["nom"]), y_colonne(cible, pk_cible)
        i = s["col"]
        if i < d["col"]:
            x1, x2, couloir = s["x"] + s["w"], d["x"], i + 1
        elif i > d["col"]:
            x1, x2, couloir = s["x"], d["x"] + d["w"], i
        elif i == 0 or (i < len(grille) - 1 and charge[i] < charge[i + 1]):
            # meme colonne : par l'exterieur, du cote le moins charge
            x1, x2, couloir = s["x"], d["x"], i
            charge[i] += 1
        else:
            x1, x2, couloir = s["x"] + s["w"], d["x"] + d["w"], i + 1
            charge[i + 1] += 1
        traces.append(dict(de=n, col=c, vers=cible, x1=x1, y1=y1, x2=x2, y2=y2, couloir=couloir))

    # pistes : deux traces d'un meme couloir dont les etendues verticales se
    # chevauchent ne partagent pas la meme piste. Deux traces qui visent la
    # meme cle primaire, elles, peuvent : elles se rejoignent avant la fleche.
    par_couloir = {}
    for t in traces:
        par_couloir.setdefault(t["couloir"], []).append(t)
    for k_c, ts in par_couloir.items():
        ts.sort(key=lambda t: (abs(t["y1"] - t["y2"]), min(t["y1"], t["y2"])))
        pistes = []
        for t in ts:
            lo, hi = sorted((t["y1"], t["y2"]))
            for k, occupe in enumerate(pistes):
                if all(hi + 10 < a or lo - 10 > b for a, b, _ in occupe):
                    occupe.append((lo, hi, t))
                    t["piste"] = k
                    break
            else:
                pistes.append([(lo, hi, t)])
                t["piste"] = len(pistes) - 1
        n_pistes = len(pistes)
        if k_c == 0:
            bord = xs[0]
            for t in ts:
                t["xl"] = bord - 16 - t["piste"] * PISTE
        elif k_c == len(grille):
            bord = xs[-1] + largeurs[-1]
            for t in ts:
                t["xl"] = bord + 16 + t["piste"] * PISTE
        else:
            milieu = xs[k_c - 1] + largeurs[k_c - 1] + (COULOIR + 4 * PISTE) / 2
            for t in ts:
                t["xl"] = milieu + (t["piste"] - (n_pistes - 1) / 2) * PISTE

    hauteur_boites = max(b["y"] + b["h"] for b in boites.values())
    hauteur = hauteur_boites + 70

    o = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largeur_totale:.0f} {hauteur:.0f}" '
             f'width="{largeur_totale:.0f}" height="{hauteur:.0f}" role="img" '
             f'aria-label="{echapper(disp["titre"])} : schema relationnel, {len(tables)} tables">')
    o.append(f"<style>{STYLE}</style>")
    o.append('<defs><marker id="pointe" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
             'markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" class="pointe"/></marker></defs>')
    o.append(f'<rect class="fond" x="0" y="0" width="{largeur_totale:.0f}" height="{hauteur:.0f}" rx="6"/>')

    n_col = sum(len(t["colonnes"]) for t in tables.values())
    n_fk = len(relations)
    n_lignes = sum(t["lignes"] for t in tables.values())
    o.append(f'<text class="titre" x="{MARGE}" y="30">{echapper(disp["titre"])}</text>')
    o.append(f'<text class="sous" x="{MARGE}" y="48">{len(tables)} tables · {n_col} colonnes · '
             f'{n_fk} clés étrangères · {n_lignes} lignes — lu dans le catalogue PostgreSQL</text>')

    # les traces sous les boites
    arrivees = set()
    for t in traces:
        x1, y1, x2, y2, xl = t["x1"], t["y1"], t["x2"], t["y2"], t["xl"]
        pts = f"{x1:.1f},{y1:.1f} {xl:.1f},{y1:.1f} {xl:.1f},{y2:.1f} {x2:.1f},{y2:.1f}"
        o.append(f'<polyline class="lien" points="{pts}" marker-end="url(#pointe)"/>')
        un_un = t["col"]["pk_seule"] or t["col"]["unique"]
        dx1 = 5 if xl > x1 else -5
        dx2 = 5 if xl > x2 else -5
        anc1 = "start" if dx1 > 0 else "end"
        anc2 = "start" if dx2 > 0 else "end"
        o.append(f'<text class="card" x="{x1 + dx1:.1f}" y="{y1 - 4:.1f}" text-anchor="{anc1}">'
                 f'{"1" if un_un else "N"}</text>')
        if (x2, y2) not in arrivees:
            arrivees.add((x2, y2))
            o.append(f'<text class="card" x="{x2 + dx2:.1f}" y="{y2 - 4:.1f}" text-anchor="{anc2}">1</text>')

    # les boites
    for n, b in boites.items():
        t = tables[n]
        w_nom, w_type, w_cle = champs[b["col"]]
        x, y, w, h = b["x"], b["y"], b["w"], b["h"]
        genre = nature(t)
        liaison = genre == "M:N"
        o.append(f'<rect class="boite" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="4"/>')
        o.append(f'<path class="{"entete-liaison" if liaison else "entete"}" '
                 f'd="M{x + .5:.1f},{y + ENTETE:.1f} V{y + 4.5:.1f} Q{x + .5:.1f},{y + .5:.1f} {x + 4.5:.1f},{y + .5:.1f} '
                 f'H{x + w - 4.5:.1f} Q{x + w - .5:.1f},{y + .5:.1f} {x + w - .5:.1f},{y + 4.5:.1f} V{y + ENTETE:.1f} Z"/>')
        o.append(f'<text class="t ttable{" tliaison" if liaison else ""}" x="{x + PAD:.1f}" y="{y + 18.5:.1f}">'
                 f'{echapper(n)}<tspan class="tdoux" font-weight="400"> · {t["lignes"]} lignes</tspan></text>')
        if genre:
            o.append(f'<text class="t {"tliaison" if liaison else "tcle"}" x="{x + w - PAD:.1f}" y="{y + 18.5:.1f}" '
                     f'text-anchor="end" font-weight="700">{genre}</text>')
        for k, c in enumerate(t["colonnes"]):
            yl = y + ENTETE + LIGNE * k
            base = yl + LIGNE / 2 + 5
            v = nul(c, t["lignes"])
            if v:
                o.append(f'<rect class="nul" x="{x + 1:.1f}" y="{yl + 1:.1f}" width="{w - 2:.1f}" height="{LIGNE - 2}"/>')
            poids = ' font-weight="700"' if c["pk"] else ""
            o.append(f'<text class="t" x="{x + PAD:.1f}" y="{base:.1f}"{poids}>{echapper(c["nom"])}</text>')
            o.append(f'<text class="t tdoux" x="{x + PAD + (w_nom + 2) * CAR:.1f}" y="{base:.1f}">{echapper(court(c["type"]))}</text>')
            if cle(c):
                classe = "tcle" if (c["pk"] or c["fk"]) else "tdoux"
                o.append(f'<text class="t {classe}" x="{x + PAD + (w_nom + w_type + 4) * CAR:.1f}" y="{base:.1f}">'
                         f'{echapper(cle(c))}</text>')
            if v:
                o.append(f'<text class="t tnul" x="{x + w - PAD:.1f}" y="{base:.1f}" text-anchor="end">{v}</text>')

    # legende
    yl = hauteur_boites + 34
    o.append(f'<text class="sous" x="{MARGE}" y="{yl}">'
             f'<tspan class="card">N ──▸ 1</tspan>  la flèche part de la clé étrangère et vise la clé primaire'
             f'   ·   <tspan class="card">PK</tspan> clé primaire   ·   '
             f'<tspan class="card">1:1</tspan> sa clé primaire est une clé étrangère   ·   '
             f'<tspan fill="#6b3d86" font-weight="700">M:N</tspan> table de liaison</text>')
    o.append(f'<text class="sous" x="{MARGE}" y="{yl + 20}"><tspan class="tnul" font-weight="700">NULL x %</tspan>'
             f'  la colonne est vide sur x % des lignes : elle ne concerne pas toutes les lignes</text>')
    o.append("</svg>")
    return "\n".join(o) + "\n"


def main():
    noms = sys.argv[1:] or list(DISPOSITIONS)
    for nom in noms:
        disp = DISPOSITIONS[nom]
        svg = dessiner(nom, disp, lire_catalogue(nom))
        cible = RACINE / "sujets" / disp["dossier"] / "schema.svg"
        cible.write_text(svg, encoding="utf-8")
        print(f"  {cible.relative_to(RACINE)}")


if __name__ == "__main__":
    main()
