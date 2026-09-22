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

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dessin  # noqa: E402

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
#  Une relation ne relie que deux colonnes VOISINES ou une meme colonne
#  (tools/dessin.py, qui trace, le refuse sinon).
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
    boites = {}
    for n, t in tables.items():
        genre = nature(t)
        boites[n] = dict(
            titre=n, compte=f"{t['lignes']} lignes", liaison=genre == "M:N",
            badge=(genre, "tliaison" if genre == "M:N" else "tcle") if genre else None,
            lignes=[dict(cle=c["nom"], nom=c["nom"], type=court(c["type"]), gras=c["pk"],
                         info=(cle(c), "tcle" if (c["pk"] or c["fk"]) else "tdoux"),
                         note=nul(c, t["lignes"]))
                    for c in t["colonnes"]])
    # la fleche part de la cle etrangere et vise la cle primaire
    liens = []
    for n, t in tables.items():
        for c in t["colonnes"]:
            if c["fk"]:
                pk = next(k["nom"] for k in tables[c["fk"]]["colonnes"] if k["pk"])
                liens.append(dict(de=(n, c["nom"]), vers=(c["fk"], pk), arrivee="1",
                                  depart="1" if (c["pk_seule"] or c["unique"]) else "N"))
    n_col = sum(len(t["colonnes"]) for t in tables.values())
    n_lignes = sum(t["lignes"] for t in tables.values())
    sous = (f"{len(tables)} tables · {n_col} colonnes · {len(liens)} clés étrangères · "
            f"{n_lignes} lignes — lu dans le catalogue PostgreSQL")
    legende = [
        '<tspan class="card">N ──▸ 1</tspan>  la flèche part de la clé étrangère et vise la clé primaire'
        '   ·   <tspan class="card">PK</tspan> clé primaire   ·   '
        '<tspan class="card">1:1</tspan> sa clé primaire est une clé étrangère   ·   '
        '<tspan class="tliaison" font-weight="700">M:N</tspan> table de liaison',
        '<tspan class="tnul" font-weight="700">NULL x %</tspan>'
        '  la colonne est vide sur x % des lignes : elle ne concerne pas toutes les lignes',
    ]
    return dessin.dessiner(nom, disp["titre"], sous,
                           f"{disp['titre']} : schema relationnel, {len(tables)} tables",
                           disp["colonnes"], boites, liens, legende)


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
