#!/usr/bin/env python3
# =====================================================================
#  Dessine le modele document de la correction : sujets/<n>/modele.svg
#  Le vis-a-vis de schema.svg — la meme base, cote MongoDB.
#
#  La forme des documents est LUE dans <sujet>_correction, la base que
#  correction.js vient de charger : chaque champ, son type, la part des
#  documents qui le portent, la taille des tableaux. Rien n'est recopie.
#  Ce qui est ecrit ici, c'est ce qu'aucune base ne sait dire : la place
#  des collections, quel champ reference ou recopie quel document, et de
#  quelle table SQL vient chaque morceau.
#
#    make demarrer && make tout
#    make dune-verifier && make tortues-verifier && make bateaux-verifier
#    python3 tools/modele_svg.py              # les trois sujets
#    python3 tools/modele_svg.py dune         # un seul
#
#  MONGOSH='podman exec -i autre-conteneur mongosh --quiet' pour lire
#  ailleurs que dans sqlnosql-mongo.
#
#  Ce fichier ne vit que sur la branche correction : il decrit le modele.
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
MONGOSH = os.environ.get("MONGOSH", "docker exec -i sqlnosql-mongo mongosh --quiet")

# Parcourt TOUS les documents de chaque collection et en tire un arbre :
# pour chaque champ, dans l'ordre ou il apparait, ses types, combien de
# documents le portent, et pour un tableau ses tailles et ses elements.
FORME = r"""
function typeDe(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  if (v instanceof Date) return "date";
  if (v instanceof ObjectId) return "objectId";
  if (v instanceof Decimal128) return "decimal";
  if (typeof v === "number") return "number";
  if (v instanceof Long || (v && v._bsontype === "Int32") || (v && v._bsontype === "Double")) return "number";
  if (typeof v === "object") return "object";
  return typeof v;
}
function noeud() { return { n: 0, champs: {}, ordre: [] }; }
function voir(arbre, doc) {
  arbre.n++;
  for (const k of Object.keys(doc)) {
    let f = arbre.champs[k];
    if (!f) { f = arbre.champs[k] = { present: 0, types: {}, min: null, max: null, sous: null, elem: {} };
              arbre.ordre.push(k); }
    const v = doc[k], t = typeDe(v);
    f.present++; f.types[t] = 1;
    if (t === "object") { f.sous = f.sous || noeud(); voir(f.sous, v); }
    if (t === "array") {
      f.min = f.min === null ? v.length : Math.min(f.min, v.length);
      f.max = Math.max(f.max || 0, v.length);
      for (const e of v) { const te = typeDe(e); f.elem[te] = 1;
        if (te === "object") { f.sous = f.sous || noeud(); voir(f.sous, e); } }
    }
  }
}
function sortie(a) {
  return { n: a.n, champs: a.ordre.map(k => { const f = a.champs[k];
    return { nom: k, present: f.present, types: Object.keys(f.types), min: f.min, max: f.max,
             elem: Object.keys(f.elem), sous: f.sous ? sortie(f.sous) : null }; }) };
}
const base = db.getSiblingDB(BASE), r = {};
for (const c of base.getCollectionNames().sort()) {
  const a = noeud();
  base.getCollection(c).find().sort({ _id: 1 }).forEach(d => voir(a, d));
  r[c] = sortie(a);
}
print(JSON.stringify(r));
"""

# ---------------------------------------------------------------------
#  Par sujet :
#    colonnes   la place des collections (meme grammaire que schema_svg.py)
#    liens      (collection, champ) -> (collection, champ), "ref" ou "copie"
#               ref   : la valeur est la cle d'un document d'ailleurs
#               copie : des champs d'un document d'ailleurs, recopies ici
#    origines   la table SQL qui vit maintenant a cet endroit
#    formes     les collections dont les documents n'ont pas tous la meme forme
# ---------------------------------------------------------------------
MODELES = {
    "dune": {
        "dossier": "1-dune",
        "titre": "Sujet 1 — Dune, la correction",
        "colonnes": [
            ["regions", 40, "releves"],
            [20, "collectes"],
            ["contremaitres", "plateformesMinage", "plateformesTransport"],
        ],
        "liens": [
            (("collectes", "puits"), ("regions", "puits"), "copie"),
            (("collectes", "ver"), ("regions", "vers"), "copie"),
            (("collectes", "contremaitre"), ("contremaitres", "_id"), "copie"),
            (("collectes", "plateformes.minage"), ("plateformesMinage", "_id"), "ref"),
            (("collectes", "plateformes.transport"), ("plateformesTransport", "_id"), "ref"),
            (("plateformesMinage", "transports"), ("plateformesTransport", "_id"), "ref"),
            (("releves", "puits"), ("regions", "puits.code"), "ref"),
        ],
        "origines": {
            "regions": {"_id": "= region.nom", "puits": "← table puits", "vers": "← table ver"},
            "releves": {"_id": "← table releve_vibration"},
            "collectes": {"tonnes": "si REUSSIE", "cause": "si ECHOUEE"},
            "contremaitres": {"_id": "= contremaitre.nom"},
            "plateformesMinage": {"_id": "= matricule", "transports": "← table compatibilite"},
            "plateformesTransport": {"_id": "= matricule"},
        },
        "formes": {"collectes": "2 formes"},
    },
    "tortues": {
        "dossier": "2-tortues",
        "titre": "Sujet 2 — Les tortues, la correction",
        "colonnes": [
            [20, "programmes"],
            ["tortues"],
            [20, "habitats", "sites"],
        ],
        "liens": [
            (("tortues", "programmes.acronyme"), ("programmes", "_id"), "ref"),
            (("tortues", "habitat"), ("habitats", "_id"), "copie"),
            (("tortues", "observations.site"), ("sites", "_id"), "ref"),
            (("sites", "habitat"), ("habitats", "_id"), "ref"),
        ],
        "origines": {
            "tortues": {"espece": "← table espece, recopiée",
                        "mensurations": "colonnes de tortue",
                        "tags": "← tortue_tag + tag",
                        "programmes": "← table inscription",
                        "observations": "← table observation",
                        "observations.observateur": "← table observateur"},
            "programmes": {"_id": "= programme.acronyme",
                           "organisation": "← organisation + pays",
                           "protocole": "← table protocole (1:1)",
                           "especeCible": "← espece, recopiée"},
            "habitats": {"_id": "= habitat.nom"},
            "sites": {"_id": "= site.nom"},
        },
        "formes": {},
    },
    "bateaux": {
        "dossier": "3-bateaux",
        "titre": "Sujet 3 — Les bateaux, la correction",
        "colonnes": [
            [20, "capitaines"],
            ["bateaux", "escales"],
            [20, "ports"],
        ],
        "liens": [
            (("capitaines", "commandements.imo"), ("bateaux", "_id"), "ref"),
            (("escales", "bateau"), ("bateaux", "_id"), "copie"),
            (("escales", "port"), ("ports", "_id"), "copie"),
            (("bateaux", "portAttache"), ("ports", "_id"), "ref"),
        ],
        "origines": {
            "bateaux": {"_id": "= bateau.imo",
                        "pavillon": "← table pays",
                        "marine": "← bateau_militaire + marine",
                        "armateur": "← bateau_civil + armateur"},
            "ports": {"_id": "= port.nom", "pays": "← table pays", "quais": "← table quai"},
            "escales": {"cargaisons": "← table cargaison"},
            "capitaines": {"_id": "= capitaine.nom", "commandements": "← table affectation"},
        },
        "formes": {"bateaux": "2 formes"},
    },
}


def lire_formes(base):
    cmd = shlex.split(MONGOSH) + ["--eval", f"const BASE = {json.dumps(base)};" + FORME]
    sortie = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    formes = json.loads(sortie.strip().splitlines()[-1])
    if not formes:
        sys.exit(f"{base} est vide : lancer d'abord make {base.split('_')[0]}-verifier")
    return formes


def type_de(f):
    def simple(types):
        ts = [t for t in types if t != "null"]
        noms = {"string": "string", "number": "number", "date": "date", "boolean": "bool",
                "object": "{ }", "decimal": "decimal", "objectId": "ObjectId"}
        return " | ".join(noms.get(t, t) for t in ts) or "null"
    if f["types"] == ["array"]:
        taille = f"{f['min']}" if f["min"] == f["max"] else f"{f['min']}–{f['max']}"
        return f"[ {simple(f['elem'])} ] ×{taille}"
    return simple(f["types"])


def lignes(arbre, origines, chemin="", prof=0):
    """Aplatit l'arbre : un sous-document ou un tableau d'objets est suivi
    de ses champs, en retrait."""
    sortie = []
    for f in arbre["champs"]:
        cle = chemin + f["nom"]
        absent = arbre["n"] - f["present"]
        note = f"absent {round(100 * absent / arbre['n'])} %" if absent else ""
        sortie.append(dict(cle=cle, nom="  " * prof + f["nom"], type=type_de(f), note=note,
                           gras=(cle == "_id"), info=(origines.pop(cle, ""), "tdoux")))
        if f["sous"]:
            sortie += lignes(f["sous"], origines, cle + ".", prof + 1)
    return sortie


def dessiner(nom, m, formes):
    boites = {}
    for c, arbre in formes.items():
        origines = dict(m["origines"].get(c, {}))
        ls = lignes(arbre, origines)
        if origines:
            sys.exit(f"{nom} : origines sans champ dans {c} : {sorted(origines)}")
        badge = m["formes"].get(c)
        boites[c] = dict(titre=c, compte=f"{arbre['n']} documents", lignes=ls,
                         badge=(badge, "tnul") if badge else None)
    liens = [dict(de=de, vers=vers, depart=genre if genre == "ref" else "copie",
                  tirets=genre == "copie")
             for de, vers, genre in m["liens"]]
    n_docs = sum(a["n"] for a in formes.values())
    sous = (f"{len(formes)} collections · {n_docs} documents — lu dans {nom}_correction, "
            f"la base que charge make {nom}-verifier")
    legende = [
        '<tspan class="card">ref ──▸</tspan>  la valeur est la clé d\'un document d\'ailleurs : '
        'le lire demande un $lookup ou une seconde requête',
        '<tspan class="card">copie ╌╌▸</tspan>  des champs d\'un document d\'ailleurs, recopiés ici : '
        'lus sans jointure, mais à réécrire aux deux endroits',
        '<tspan class="card">[ ] ×a–b</tspan>  tableau de a à b éléments   ·   '
        '<tspan class="card">{ }</tspan> sous-document, ses champs en retrait   ·   '
        '<tspan class="tdoux">← table</tspan> la table SQL qui vit maintenant là',
        '<tspan class="tnul" font-weight="700">absent x %</tspan>  le champ manque dans x % des '
        'documents — il n\'y est pas, ce n\'est pas un NULL',
    ]
    return dessin.dessiner(nom, m["titre"], sous,
                           f"{m['titre']} : modele document, {len(formes)} collections",
                           m["colonnes"], boites, liens, legende)


def main():
    noms = sys.argv[1:] or list(MODELES)
    for nom in noms:
        m = MODELES[nom]
        svg = dessiner(nom, m, lire_formes(f"{nom}_correction"))
        cible = RACINE / "sujets" / m["dossier"] / "modele.svg"
        cible.write_text(svg, encoding="utf-8")
        print(f"  {cible.relative_to(RACINE)}")


if __name__ == "__main__":
    main()
