// =====================================================================
//  DB 3 — Les bateaux : la correction
//  Le modele document de reference, et les six questions de
//  controle.sql reposees a MongoDB.
// =====================================================================
//  Joue par  : make bateaux-verifier    (CASSE=1 pour voir le KO)
//  Base de travail : bateaux_correction — pas bateaux, ou l'etudiant
//  ecrit son propre modele.
//
//  Le modele, dessine : modele.svg, en vis-a-vis de schema.svg
//  (python3 tools/modele_svg.py le redessine depuis la base chargee).
//
//  LE MODELE — douze tables deviennent quatre collections.
//    bateaux      UNE seule collection pour les civils ET les militaires.
//                 L'heritage en trois tables disparait : chaque document
//                 porte categorie, et les champs de sa categorie, et
//                 seulement ceux-la. La faiblesse que le SQL ne savait pas
//                 interdire — un CIVIL avec une ligne dans
//                 bateau_militaire — n'est plus exprimable.
//    ports        le port, et dedans ses quais. 1:N BORNE : cinq quais,
//                 et il n'y en aura pas cinquante.
//    escales      dehors, et c'est le contraire du quai : une escale par
//                 passage, pour toujours. Elle embarque ses cargaisons
//                 (elles n'existent pas sans elle) et une copie du bateau
//                 (nom, imo, categorie) et du port (nom, quai).
//    capitaines   avec ses commandements : l'affectation n'a pas d'autre
//                 vie que la paire qu'elle relie, et ses dates.
//
//  CE QUI DISPARAIT
//    pays, armateur, marine  -> trois tables qui ne portaient qu'un nom.
//                 armateur et marine n'existaient que parce qu'une cle
//                 etrangere doit pointer sur UNE table : cote document,
//                 c'est une chaine dans le bateau, et la gemellite
//                 s'evapore avec elles.
//    quai         -> dans son port.  cargaison -> dans son escale.
//    bateau_civil, bateau_militaire -> dans bateau.
//    affectation  -> dans le capitaine.
//
//  CE QUE LE MODELE PERD
//    - le nom du bateau est recopie dans chaque escale et dans chaque
//      commandement : le rebaptiser (exercice 3) se paie en ecritures.
//      L'imo, lui, ne change jamais — c'est pour ca qu'il est la cle.
//    - la C6 croise le tirant d'eau du bateau et celui du port : ni l'un
//      ni l'autre n'est dans l'escale, et c'est VOULU. Deux $lookup,
//      plutot qu'une profondeur de port recopiee 37 fois.
// =====================================================================

load("/projet/sujets/verifier.js");

const base = db.getSiblingDB("bateaux_correction");
const T    = tables("bateaux");
const c    = controle("bateaux");

const parId     = a => new Map(a.map(x => [x.id, x]));
const pays      = parId(T.pays);
const portsSql  = parId(T.port);
const quaisSql  = parId(T.quai);
const armateurs = parId(T.armateur);
const marines   = parId(T.marine);
const bateauxSql = parId(T.bateau);
const civils     = new Map(T.bateau_civil.map(x => [x.bateau_id, x]));
const militaires = new Map(T.bateau_militaire.map(x => [x.bateau_id, x]));

base.dropDatabase();

// ---------------------------------------------------------------------
// 1. Les ports, quais compris
// ---------------------------------------------------------------------

base.ports.insertMany(T.port.map(p => ({
  _id: p.nom,
  pays: pays.get(p.pays_id).nom,
  tirantEauMaxM: p.tirant_eau_max_m,
  quais: T.quai.filter(q => q.port_id === p.id).map(q => q.numero)
})));

// ---------------------------------------------------------------------
// 2. La flotte : une collection, deux formes
// ---------------------------------------------------------------------

base.bateaux.insertMany(T.bateau.map(b => {
  const doc = {
    _id: b.imo,                     // l'imo ne change jamais : c'est la cle
    nom: b.nom,
    categorie: b.categorie,
    pavillon: pays.get(b.pavillon_id).nom,
    tirantEauM: b.tirant_eau_m
  };
  if (b.port_attache_id !== null) doc.portAttache = portsSql.get(b.port_attache_id).nom;

  if (b.categorie === "CIVIL") {
    const bc = civils.get(b.id);
    doc.armateur     = armateurs.get(bc.armateur_id).nom;
    doc.typeCivil    = bc.type_civil;
    doc.portEnLourdT = bc.port_en_lourd_t;
    // NULL hors porte-conteneurs : le champ est absent, pas vide.
    if (bc.capacite_evp !== null) doc.capaciteEvp = bc.capacite_evp;
  } else {
    const bm = militaires.get(b.id);
    doc.marine              = marines.get(bm.marine_id).nom;
    doc.classe              = bm.classe;
    doc.equipage            = bm.equipage;
    doc.propulsionNucleaire = bm.propulsion_nucleaire;
  }
  return doc;
}));

// ---------------------------------------------------------------------
// 3. Le journal des escales, cargaisons comprises
// ---------------------------------------------------------------------

const cargaisonsParEscale = new Map();
for (const ca of T.cargaison) {
  if (!cargaisonsParEscale.has(ca.escale_id)) cargaisonsParEscale.set(ca.escale_id, []);
  cargaisonsParEscale.get(ca.escale_id).push({ marchandise: ca.marchandise, tonnes: ca.tonnes });
}

base.escales.insertMany(T.escale.map(e => {
  const b = bateauxSql.get(e.bateau_id);
  const q = quaisSql.get(e.quai_id);
  const doc = {
    _id: e.id,
    arrivee: quand(e.arrivee),
    motif: e.motif,
    bateau: { nom: b.nom, imo: b.imo, categorie: b.categorie },
    port:   { nom: portsSql.get(q.port_id).nom, quai: q.numero },
    cargaisons: cargaisonsParEscale.get(e.id) || []
  };
  // depart NULL = le bateau est encore a quai : champ absent.
  if (e.depart !== null) doc.depart = quand(e.depart);
  return doc;
}));

// ---------------------------------------------------------------------
// 4. Les capitaines et leurs commandements
// ---------------------------------------------------------------------

base.capitaines.insertMany(T.capitaine.map(cap => ({
  _id: cap.nom,
  brevet: cap.brevet,
  commandements: T.affectation.filter(a => a.capitaine_id === cap.id).map(a => {
    const b = bateauxSql.get(a.bateau_id);
    const co = { bateau: b.nom, imo: b.imo, debut: quand(a.debut) };
    if (a.fin !== null) co.fin = quand(a.fin);   // absent = affectation en cours
    return co;
  })
})));

titre("Le modele charge");
["ports", "bateaux", "escales", "capitaines"].forEach(n =>
  dire(g(n, 12) + d(base.getCollection(n).countDocuments(), 4) + " documents"));

if (typeof CASSE !== "undefined" && CASSE) {
  const e = base.escales.findOne({ cargaisons: { $ne: [] } }, { sort: { _id: 1 } });
  base.escales.updateOne({ _id: e._id }, { $pop: { cargaisons: 1 } });
  base.escales.updateOne({ depart: { $exists: false } }, { $set: { depart: new Date() } });
  dire("");
  dire("CASSE=1 : l escale " + e._id + " perd une cargaison, et un bateau encore a quai");
  dire("          est declare reparti. C3 et C4 doivent sortir KO.");
}

// =====================================================================
//  Les six questions, reposees au modele document
// =====================================================================

titre("Les six chiffres de controle, cote MongoDB");

// --- C1 et C2 : la meme question, deux fois, disait controle.sql —
// parce que le SQL ne savait pas la poser une seule fois. Ici c'est la
// MEME collection, filtree sur categorie. Les champs civils n'existent
// pas sur un militaire : aucune colonne vide nulle part.
c.question("C1", "La flotte civile",
  base.bateaux.find({ categorie: "CIVIL" }).sort({ portEnLourdT: -1 }).toArray()
    .map(b => "    " + g(b.nom, 18) + g(b.typeCivil, 18) + g(b.armateur, 20)
        + d(b.portEnLourdT, 7) + " tpl"
        + (b.capaciteEvp === undefined ? "" : "   " + b.capaciteEvp + " EVP")));

c.question("C2", "La flotte militaire",
  base.bateaux.find({ categorie: "MILITAIRE" }).sort({ equipage: -1 }).toArray()
    .map(b => "    " + g(b.nom, 18) + g(b.classe, 18) + g(b.marine, 20)
        + d(b.equipage, 5) + " hommes"
        + (b.propulsionNucleaire ? "   nucleaire" : "")));

// --- C3 : le tonnage par port.  Le port est DANS l'escale et les
// cargaisons aussi : un $group, aucun $lookup. C'est l'exercice 3.2.
// Le compte d'escales est celui des escales qui portent une cargaison —
// le SQL comptait pareil, par sa jointure.
c.question("C3", "Tonnage manipule par port",
  base.escales.aggregate([
    { $match: { cargaisons: { $ne: [] } } },
    { $group: { _id: "$port.nom", tonnes: { $sum: { $sum: "$cargaisons.tonnes" } }, n: { $sum: 1 } } },
    { $sort:  { tonnes: -1 } }
  ]).toArray().map(r => "    " + g(r._id, 12) + d(deci(r.tonnes, 0), 9) + " t en "
      + d(r.n, 3) + " escales de commerce"));

// --- C4 : encore a quai.  « depart non renseigne » devient « le champ
// n'est pas la ». Le nom du bateau, sa categorie, le port et le quai
// sont tous dans l'escale : la ligne se lit sans rien ouvrir d'autre.
c.question("C4", "Encore a quai (depart non renseigne)",
  base.escales.find({ depart: { $exists: false } }).sort({ arrivee: 1 }).toArray()
    .map(e => "    " + g(e.bateau.nom, 18) + g(e.bateau.categorie, 11) + g(e.port.nom, 12)
        + "quai " + g(e.port.quai, 4) + "depuis le " + jjmmaaaa(e.arrivee)));

// --- C5 : les capitaines.  Les affectations sont dans le capitaine :
// compter, et trouver celle qui n'a pas de fin.
c.question("C5", "Les capitaines et leurs commandements",
  base.capitaines.aggregate([
    { $set: { n: { $size: "$commandements" },
              enCours: { $max: { $map: {
                input: { $filter: { input: "$commandements",
                                    cond: { $eq: [{ $type: "$$this.fin" }, "missing"] } } },
                in: "$$this.bateau" } } } } },
    { $sort: { n: -1, _id: 1 } }
  ]).toArray().map(r => "    " + g(r._id, 18) + g(r.brevet, 20)
      + r.n + " bateaux, en cours : " + (r.enCours === null ? "aucun" : r.enCours)));

// --- C6 : les escales impossibles.  La regle croise deux tables en SQL,
// deux collections ici : ni le tirant du bateau ni celui du port n'est
// recopie dans l'escale. Deux $lookup, et un $expr pour comparer deux
// champs entre eux.
c.question("C6", "Escales impossibles : le bateau tire plus que le port n autorise",
  base.escales.aggregate([
    { $lookup: { from: "bateaux", localField: "bateau.imo", foreignField: "_id", as: "b" } },
    { $lookup: { from: "ports",   localField: "port.nom",   foreignField: "_id", as: "p" } },
    { $set: { tirant: { $first: "$b.tirantEauM" }, maxi: { $first: "$p.tirantEauMaxM" } } },
    { $match: { $expr: { $gt: ["$tirant", "$maxi"] } } },
    { $sort:  { _id: 1 } }
  ]).toArray().map(e => "    escale " + d(e._id, 3) + "   " + g(e.bateau.nom, 18)
      + deci(e.tirant, 1) + " m  >  " + g(e.port.nom, 12) + deci(e.maxi, 1) + " m"));

c.bilan();
