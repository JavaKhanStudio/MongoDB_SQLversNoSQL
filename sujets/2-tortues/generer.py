#!/usr/bin/env python3
"""
Fabrique donnees.sql depuis le jeu de donnees Mongo du projet fil rouge.

    python3 sujets/2-tortues/generer.py            # ecrit sujets/2-tortues/donnees.sql

Source : ~/Documents/GitHub/MongoDB_Tortues/{turtles,habitats,programs}.json
Ce sont les memes 139 tortues que les eleves ont deja chargees pour la
section « Indexing » du deck. Rien n'est invente ici SAUF :
  - espece.nom_commun et espece.statut_uicn (statuts UICN reels) ;
  - inscription.date_inscription, tiree au sort de facon deterministe
    (graine fixe) : le document Mongo ne dit pas depuis quand la tortue
    est suivie, et c'est precisement l'attribut qui fait de la liaison
    M:N autre chose qu'un tableau d'identifiants.
Le nettoyage applique est decrit dans SUJET.md.

Le schema tient dans un budget de 46 colonnes (decision de Simon, d1 :
40 visees, 50 au maximum). Ce script n'ecrit que ces colonnes-la.
"""
import json, os, random, sys, datetime

SRC = os.path.expanduser("~/Documents/GitHub/MongoDB_Tortues")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "donnees.sql")

ESPECES = {   # nom scientifique -> (nom commun, statut UICN)
    "Chelonia mydas":          ("Tortue verte",      "EN"),
    "Caretta caretta":         ("Tortue caouanne",   "VU"),
    "Natator depressus":       ("Tortue a dos plat", "DD"),
    "Eretmochelys imbricata":  ("Tortue imbriquee",  "CR"),
    "Dermochelys coriacea":    ("Tortue luth",       "VU"),
    "Lepidochelys olivacea":   ("Tortue olivatre",   "VU"),
}

# Le seul tag qui ne suit pas la convention kebab-case du jeu : nettoye.
TAG_PROPRE = {"jamais revue": "jamais-revue"}


def q(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def bloc(table, colonnes, lignes):
    if not lignes:
        return ""
    out = [f"INSERT INTO {table} ({', '.join(colonnes)}) VALUES"]
    out += ["  (" + ", ".join(q(v) for v in l) + ")," for l in lignes[:-1]]
    out += ["  (" + ", ".join(q(v) for v in lignes[-1]) + ");", ""]
    return "\n".join(out) + "\n"


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"jeu de donnees introuvable : {SRC}\n"
                 f"(depot MongoDB_Tortues — donnees.sql est deja genere, "
                 f"ce script ne sert qu'a le refaire)")
    turtles  = json.load(open(f"{SRC}/turtles.json"))
    habitats = json.load(open(f"{SRC}/habitats.json"))
    programs = json.load(open(f"{SRC}/programs.json"))

    # --- referentiels -------------------------------------------------
    pays      = {}
    especes   = {}
    orgs      = {}
    habs      = {}
    sites     = {}
    obsvs     = {}
    tags      = {}

    def cle(d, k):
        if k not in d:
            d[k] = len(d) + 1
        return d[k]

    for p in programs:
        cle(pays, p["coordinationCountry"])
    for nom in ESPECES:
        cle(especes, nom)
    for p in programs:
        cle(orgs, p["organisation"])
    for h in habitats:
        cle(habs, h["name"])

    org_pays = {p["organisation"]: p["coordinationCountry"] for p in programs}
    oid_hab  = {h["_id"]["$oid"]: h["name"] for h in habitats}
    oid_prog = {p["_id"]["$oid"]: p["acronym"] for p in programs}

    # site -> habitat, deduit des observations (un site n'appartient qu'a un habitat)
    site_hab = {}
    for t in turtles:
        hid = t.get("habitatId", {}).get("$oid")
        if not hid:
            continue
        for o in t.get("observations", []):
            site_hab.setdefault(o["site"], oid_hab[hid])
    for t in turtles:
        for o in t.get("observations", []):
            cle(sites, o["site"])
            cle(obsvs, o["observer"])
        for tg in t.get("tags", []):
            cle(tags, TAG_PROPRE.get(tg, tg))

    manquants = [s for s in sites if s not in site_hab]
    if manquants:
        sys.exit(f"sites sans habitat deductible : {manquants}")

    # --- lignes -------------------------------------------------------
    L = {}
    L["pays"]         = [(i, n) for n, i in pays.items()]
    L["espece"]       = [(especes[n], n, c, s) for n, (c, s) in ESPECES.items()]
    L["organisation"] = [(i, n, pays[org_pays[n]]) for n, i in orgs.items()]
    L["habitat"]      = [(habs[h["name"]], h["name"], h["protectedArea"])
                         for h in habitats]
    L["site"]         = [(i, n, habs[site_hab[n]]) for n, i in sites.items()]
    L["observateur"]  = [(i, n) for n, i in obsvs.items()]
    L["tag"]          = [(i, n) for n, i in tags.items()]

    tortues, t_tags, observations, inscriptions = [], [], [], []
    rng = random.Random(1998)          # graine fixe : le fichier est reproductible
    nid = 0
    for n, t in enumerate(turtles, start=1):
        hid = t.get("habitatId", {}).get("$oid")
        m = t["measurements"]
        tortues.append((n, t["name"], especes[t["species"]],
                        habs[oid_hab[hid]] if hid else None,
                        m["shellLengthCm"], m["weightKg"]))
        for tg in dict.fromkeys(t.get("tags", [])):
            t_tags.append((n, tags[TAG_PROPRE.get(tg, tg)]))
        for o in t.get("observations", []):
            nid += 1
            observations.append((nid, n, sites[o["site"]], obsvs[o["observer"]],
                                 o["date"]["$date"][:10], o["healthScore"]))
        vus = set()
        for p in t.get("programs", []):
            acr = oid_prog[p["programId"]["$oid"]]
            if acr in vus:
                continue                # le document en duplique quelques-uns
            vus.add(acr)
            pr = next(x for x in programs if x["acronym"] == acr)
            deb = max(pr["startYear"], t["annee_naissance"])
            fin = pr.get("endYear", 2026)
            an  = rng.randint(deb, max(deb, min(fin, 2026)))
            inscriptions.append((n, [x["acronym"] for x in programs].index(acr) + 1,
                                 f"{an:04d}-{rng.randint(1,12):02d}-{rng.randint(1,28):02d}"))
    L["tortue"]       = tortues
    L["tortue_tag"]   = t_tags
    L["observation"]  = observations

    L["programme"] = [(i, p["name"], p["acronym"], orgs[p["organisation"]],
                       p.get("endYear"), p["status"], especes.get(p["focusSpecies"]))
                      for i, p in enumerate(programs, start=1)]
    L["protocole"] = [(i, p["protocol"]["samplingIntervalDays"], p["protocol"]["taggingMethod"])
                      for i, p in enumerate(programs, start=1)]
    L["inscription"] = inscriptions

    COLS = {
        "pays":         ["id", "nom"],
        "espece":       ["id", "nom_scientifique", "nom_commun", "statut_uicn"],
        "organisation": ["id", "nom", "pays_id"],
        "habitat":      ["id", "nom", "aire_protegee"],
        "site":         ["id", "nom", "habitat_id"],
        "observateur":  ["id", "nom"],
        "tortue":       ["id", "nom", "espece_id", "habitat_id",
                         "longueur_dossiere_cm", "poids_kg"],
        "tag":          ["id", "libelle"],
        "tortue_tag":   ["tortue_id", "tag_id"],
        "observation":  ["id", "tortue_id", "site_id", "observateur_id",
                         "date_obs", "score_sante"],
        "programme":    ["id", "nom", "acronyme", "organisation_id",
                         "annee_fin", "statut", "espece_cible_id"],
        "protocole":    ["programme_id", "intervalle_jours", "methode_marquage"],
        "inscription":  ["tortue_id", "programme_id", "date_inscription"],
    }
    ORDRE = ["pays", "espece", "organisation", "habitat", "site",
             "observateur", "tag", "tortue", "tortue_tag", "observation",
             "programme", "protocole", "inscription"]

    with open(OUT, "w") as f:
        f.write("-- =====================================================================\n"
                "--  DB 2 — Les tortues : le jeu de donnees\n"
                "--  GENERE par sujets/2-tortues/generer.py depuis MongoDB_Tortues.\n"
                "--  Ne pas editer a la main : relancer le script.\n"
                f"--  Genere le {datetime.date.today()}.\n"
                "-- =====================================================================\n\n")
        f.write("TRUNCATE " + ", ".join(reversed(ORDRE)) + " RESTART IDENTITY CASCADE;\n\n")
        for t in ORDRE:
            f.write(bloc(t, COLS[t], L[t]))
        for t in ORDRE:
            if "id" in COLS[t]:
                f.write(f"SELECT setval('{t}_id_seq', (SELECT MAX(id) FROM {t}));\n")

    print(f"{OUT} ecrit")
    for t in ORDRE:
        print(f"  {t:16} {len(L[t]):5} lignes")


if __name__ == "__main__":
    main()
