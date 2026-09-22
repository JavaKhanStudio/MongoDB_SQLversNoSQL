# =====================================================================
#  Le trace commun des dessins de schema : des boites posees sur une
#  grille, des lignes dans chaque boite, et des fleches qui passent par
#  les couloirs entre les colonnes. Ne sait rien de SQL ni de MongoDB :
#  schema_svg.py (les tables) lui donne ses boites, et la correction
#  (les collections) les siennes.
#
#  Une boite :  dict(titre, compte, badge=None|(texte, classe),
#                    liaison=False, lignes=[...])
#  Une ligne :  dict(cle, nom, type, info=("", classe), note="",
#                    gras=False)
#               cle sert a y accrocher une fleche ; une note (texte a
#               droite, en couleur d'alerte) surligne la ligne.
#  Un lien :    dict(de=(boite, cle), vers=(boite, cle),
#                    depart="N", arrivee="1", tirets=False)
#  La grille :  une liste de colonnes, chacune une liste de noms de
#               boites de haut en bas ; un nombre y est un blanc en px.
#               Un lien ne relie que deux colonnes VOISINES ou une meme
#               colonne : c'est ce qui garde les fleches hors des boites.
# =====================================================================
import sys

CAR = 7.25          # largeur d'un caractere mono a 12 px
LIGNE = 18          # hauteur d'une ligne
ENTETE = 28         # hauteur de l'en-tete d'une boite
PAD = 12            # marge interieure
ECART_V = 30        # entre deux boites d'une meme colonne
COULOIR = 34        # couloir minimal entre deux colonnes de boites
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
  .tirets { stroke-dasharray: 5 3; }
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


def dessiner(nom, titre, sous_titre, aria, grille, boites, liens, legende):
    """legende : des lignes de texte SVG deja balisees (tspan permis)."""
    places = [n for col in grille for n in col if isinstance(n, str)]
    manquantes = sorted(set(boites) - set(places))
    inconnues = sorted(set(places) - set(boites))
    if manquantes or inconnues:
        sys.exit(f"{nom} : la grille ne correspond plus — "
                 f"absentes du dessin {manquantes}, inconnues {inconnues}")
    col_de = {n: i for i, col in enumerate(grille) for n in col if isinstance(n, str)}

    # largeur de chaque colonne de la grille : la plus large de ses boites
    largeurs, champs = [], []
    for col in grille:
        noms = [n for n in col if isinstance(n, str)]
        ls = [l for n in noms for l in boites[n]["lignes"]]
        w_nom = max(len(l["nom"]) for l in ls)
        w_type = max(len(l["type"]) for l in ls)
        w_info = max(len(l.get("info", ("", ""))[0]) for l in ls)
        w_note = max(len(l.get("note", "")) for l in ls)
        w_tete = max(len(boites[n]["titre"]) + len(f" · {boites[n]['compte']}")
                     + (len(boites[n]["badge"][0]) if boites[n].get("badge") else 0) + 5 for n in noms)
        corps = (w_nom + 2 + w_type + 2 + w_info + (2 + w_note if w_note else 0)) * CAR
        largeurs.append(max(corps, w_tete * CAR) + 2 * PAD)
        champs.append((w_nom, w_type))

    for l in liens:
        a, b = col_de[l["de"][0]], col_de[l["vers"][0]]
        if abs(a - b) > 1:
            sys.exit(f"{nom} : {l['de']} -> {l['vers']} saute une colonne de la grille")

    # positions
    pos = {}
    x = MARGE + 3 * PISTE
    xs = []
    for i, col in enumerate(grille):
        xs.append(x)
        y = HAUT
        for n in col:
            if not isinstance(n, str):
                y += n
                continue
            h = ENTETE + LIGNE * len(boites[n]["lignes"]) + 8
            pos[n] = dict(x=x, y=y, w=largeurs[i], h=h, col=i)
            y += h + ECART_V
        x += largeurs[i] + COULOIR + 4 * PISTE
    largeur_totale = x - COULOIR - 4 * PISTE + 3 * PISTE + MARGE

    def y_ligne(n, cle):
        cles = [l["cle"] for l in boites[n]["lignes"]]
        if cle not in cles:
            sys.exit(f"{nom} : pas de ligne {cle!r} dans {n}")
        return pos[n]["y"] + ENTETE + LIGNE * cles.index(cle) + LIGNE / 2 + 1

    # chaque lien : un depart, une arrivee, et un couloir. Le couloir k est
    # celui de gauche de la colonne k ; le dernier borde la derniere colonne.
    charge = [0] * (len(grille) + 1)
    for l in liens:
        a, b = col_de[l["de"][0]], col_de[l["vers"][0]]
        if a != b:
            charge[max(a, b)] += 1
    traces = []
    for l in liens:
        s, d = pos[l["de"][0]], pos[l["vers"][0]]
        y1, y2 = y_ligne(*l["de"]), y_ligne(*l["vers"])
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
        traces.append(dict(lien=l, x1=x1, y1=y1, x2=x2, y2=y2, couloir=couloir))

    # pistes : deux traces d'un meme couloir dont les etendues verticales se
    # chevauchent ne partagent pas la meme piste
    par_couloir = {}
    for t in traces:
        par_couloir.setdefault(t["couloir"], []).append(t)
    for k_c, ts in par_couloir.items():
        ts.sort(key=lambda t: (abs(t["y1"] - t["y2"]), min(t["y1"], t["y2"])))
        pistes = []
        for t in ts:
            lo, hi = sorted((t["y1"], t["y2"]))
            for k, occupe in enumerate(pistes):
                if all(hi + 10 < a or lo - 10 > b for a, b in occupe):
                    occupe.append((lo, hi))
                    t["piste"] = k
                    break
            else:
                pistes.append([(lo, hi)])
                t["piste"] = len(pistes) - 1
        n_pistes = len(pistes)
        if k_c == 0:
            for t in ts:
                t["xl"] = xs[0] - 16 - t["piste"] * PISTE
        elif k_c == len(grille):
            for t in ts:
                t["xl"] = xs[-1] + largeurs[-1] + 16 + t["piste"] * PISTE
        else:
            milieu = xs[k_c - 1] + largeurs[k_c - 1] + (COULOIR + 4 * PISTE) / 2
            for t in ts:
                t["xl"] = milieu + (t["piste"] - (n_pistes - 1) / 2) * PISTE

    hauteur_boites = max(b["y"] + b["h"] for b in pos.values())
    hauteur = hauteur_boites + 30 + 20 * len(legende)

    o = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largeur_totale:.0f} {hauteur:.0f}" '
             f'width="{largeur_totale:.0f}" height="{hauteur:.0f}" role="img" '
             f'aria-label="{echapper(aria)}">')
    o.append(f"<style>{STYLE}</style>")
    o.append('<defs><marker id="pointe" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
             'markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" class="pointe"/></marker></defs>')
    o.append(f'<rect class="fond" x="0" y="0" width="{largeur_totale:.0f}" height="{hauteur:.0f}" rx="6"/>')
    o.append(f'<text class="titre" x="{MARGE}" y="30">{echapper(titre)}</text>')
    o.append(f'<text class="sous" x="{MARGE}" y="48">{echapper(sous_titre)}</text>')

    # les traces sous les boites
    arrivees = set()
    for t in traces:
        l = t["lien"]
        x1, y1, x2, y2, xl = t["x1"], t["y1"], t["x2"], t["y2"], t["xl"]
        pts = f"{x1:.1f},{y1:.1f} {xl:.1f},{y1:.1f} {xl:.1f},{y2:.1f} {x2:.1f},{y2:.1f}"
        classe = "lien tirets" if l.get("tirets") else "lien"
        o.append(f'<polyline class="{classe}" points="{pts}" marker-end="url(#pointe)"/>')
        dx1 = 5 if xl > x1 else -5
        dx2 = 5 if xl > x2 else -5
        anc1 = "start" if dx1 > 0 else "end"
        anc2 = "start" if dx2 > 0 else "end"
        if l.get("depart"):
            o.append(f'<text class="card" x="{x1 + dx1:.1f}" y="{y1 - 4:.1f}" text-anchor="{anc1}">'
                     f'{echapper(l["depart"])}</text>')
        if l.get("arrivee") and (x2, y2) not in arrivees:
            arrivees.add((x2, y2))
            o.append(f'<text class="card" x="{x2 + dx2:.1f}" y="{y2 - 4:.1f}" text-anchor="{anc2}">'
                     f'{echapper(l["arrivee"])}</text>')

    # les boites
    for n, b in pos.items():
        bo = boites[n]
        w_nom, w_type = champs[b["col"]]
        x, y, w, h = b["x"], b["y"], b["w"], b["h"]
        liaison = bo.get("liaison")
        o.append(f'<rect class="boite" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="4"/>')
        o.append(f'<path class="{"entete-liaison" if liaison else "entete"}" '
                 f'd="M{x + .5:.1f},{y + ENTETE:.1f} V{y + 4.5:.1f} Q{x + .5:.1f},{y + .5:.1f} {x + 4.5:.1f},{y + .5:.1f} '
                 f'H{x + w - 4.5:.1f} Q{x + w - .5:.1f},{y + .5:.1f} {x + w - .5:.1f},{y + 4.5:.1f} V{y + ENTETE:.1f} Z"/>')
        o.append(f'<text class="t ttable{" tliaison" if liaison else ""}" x="{x + PAD:.1f}" y="{y + 18.5:.1f}">'
                 f'{echapper(bo["titre"])}<tspan class="tdoux" font-weight="400"> · {echapper(bo["compte"])}</tspan></text>')
        if bo.get("badge"):
            texte, classe = bo["badge"]
            o.append(f'<text class="t {classe}" x="{x + w - PAD:.1f}" y="{y + 18.5:.1f}" '
                     f'text-anchor="end" font-weight="700">{echapper(texte)}</text>')
        for k, l in enumerate(bo["lignes"]):
            yl = y + ENTETE + LIGNE * k
            base = yl + LIGNE / 2 + 5
            if l.get("note"):
                o.append(f'<rect class="nul" x="{x + 1:.1f}" y="{yl + 1:.1f}" width="{w - 2:.1f}" height="{LIGNE - 2}"/>')
            poids = ' font-weight="700"' if l.get("gras") else ""
            o.append(f'<text class="t" x="{x + PAD:.1f}" y="{base:.1f}" xml:space="preserve"{poids}>'
                     f'{echapper(l["nom"])}</text>')
            o.append(f'<text class="t tdoux" x="{x + PAD + (w_nom + 2) * CAR:.1f}" y="{base:.1f}">{echapper(l["type"])}</text>')
            info, classe = l.get("info", ("", ""))
            if info:
                o.append(f'<text class="t {classe}" x="{x + PAD + (w_nom + w_type + 4) * CAR:.1f}" y="{base:.1f}">'
                         f'{echapper(info)}</text>')
            if l.get("note"):
                o.append(f'<text class="t tnul" x="{x + w - PAD:.1f}" y="{base:.1f}" text-anchor="end">'
                         f'{echapper(l["note"])}</text>')

    for k, ligne in enumerate(legende):
        o.append(f'<text class="sous" x="{MARGE}" y="{hauteur_boites + 34 + 20 * k}">{ligne}</text>')
    o.append("</svg>")
    return "\n".join(o) + "\n"
