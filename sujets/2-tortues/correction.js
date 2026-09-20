// =====================================================================
//  DB 2 — Les tortues : la correction
//  Le modele document de reference, et les six questions de
//  controle.sql reposees a MongoDB.
// =====================================================================
//  Joue par  : make tortues-verifier    (CASSE=1 pour voir le KO)
//  Base de travail : tortues_correction — pas tortues, ou l'etudiant
//  ecrit son propre modele.
//
//  LE MODELE — treize tables deviennent quatre collections.
//    tortues        le document central : la tortue, son espece copiee,
//                   son habitat copie, ses mensurations en sous-document,
//                   ses tags en tableau, ses programmes en tableau avec la
//                   date d'inscription, et SES OBSERVATIONS DEDANS.
//                   727 observations pour 139 tortues : cinq par document,
//                   et une campagne par an. Ca tient.
//    programmes     le programme, son organisation copiee, et son
//                   protocole en sous-document : un 1:1 qui ne se lit
//                   jamais seul n'est pas une collection.
//    habitats       garde : l'exercice 4 declasse une aire protegee, et
//                   il faut un endroit ou ecrire le changement une fois.
//    sites          garde : c'est lui qui sait dans quel habitat une
//                   observation a eu lieu. Le copier dans chaque
//                   observation, ce serait 727 copies au lieu de 28.
//
//  CE QUI DISPARAIT
//    pays, organisation, observateur, espece  -> recopies, jamais modifies.
//    tag         -> M:N PUR : la liaison devient un tableau de libelles et
//                   la table s'evapore. Prix a payer : un libelle que
//                   personne ne porte n'existe plus nulle part (C5 ne le
//                   voyait deja pas, elle joignait tortue_tag).
//    protocole   -> dans son programme.
//    inscription -> M:N AVEC attribut : la date est portee COTE TORTUE.
//                   C'est ce qui rend la C4 chere — voir plus bas.
//    observation, site -> l'un dedans, l'autre reste.
//
//  CE QUE LE MODELE PERD
//    - la C2 (les sites les plus frequentes) doit deterrer 727
//      sous-documents avant de compter : en SQL c'etait un GROUP BY sur
//      une table indexee ;
//    - la C4 doit partir des programmes et aller chercher les tortues,
//      parce que la date d'inscription est chez la tortue. KEL, qui n'a
//      aucune inscrite, ne se verrait pas autrement.
// =====================================================================

load("/projet/sujets/verifier.js");

const base = db.getSiblingDB("tortues_correction");
const T    = tables("tortues");
const c    = controle("tortues");

const parId    = a => new Map(a.map(x => [x.id, x]));
const especes  = parId(T.espece);
const habitats = parId(T.habitat);
const sites    = parId(T.site);
const observateurs = parId(T.observateur);
const organisations = parId(T.organisation);
const pays     = parId(T.pays);
const tags     = parId(T.tag);
const programmesSql = parId(T.programme);
const protocoles = new Map(T.protocole.map(p => [p.programme_id, p]));

base.dropDatabase();

// ---------------------------------------------------------------------
// 1. Le territoire : l'habitat reste une collection, le site aussi
// ---------------------------------------------------------------------

base.habitats.insertMany(T.habitat.map(h => ({ _id: h.nom, aireProtegee: h.aire_protegee })));
base.sites.insertMany(T.site.map(s => ({ _id: s.nom, habitat: habitats.get(s.habitat_id).nom })));

// ---------------------------------------------------------------------
// 2. Les programmes, protocole compris
// ---------------------------------------------------------------------

base.programmes.insertMany(T.programme.map(p => {
  const org  = organisations.get(p.organisation_id);
  const prot = protocoles.get(p.id);
  const doc = {
    _id: p.acronyme,
    nom: p.nom,
    statut: p.statut,
    organisation: { nom: org.nom, pays: pays.get(org.pays_id).nom },
    protocole: { intervalleJours: prot.intervalle_jours, methodeMarquage: prot.methode_marquage }
  };
  // NULL = « toutes especes » et NULL = « sans terme » : cote document,
  // le champ est simplement ABSENT. C6 les compte comme tels.
  if (p.annee_fin !== null)       doc.anneeFin = p.annee_fin;
  if (p.espece_cible_id !== null) doc.especeCible = especes.get(p.espece_cible_id).nom_scientifique;
  return doc;
}));

// ---------------------------------------------------------------------
// 3. Les tortues, observations comprises
// ---------------------------------------------------------------------

const obsParTortue = new Map();
for (const o of T.observation) {
  if (!obsParTortue.has(o.tortue_id)) obsParTortue.set(o.tortue_id, []);
  obsParTortue.get(o.tortue_id).push({
    date: quand(o.date_obs),
    site: sites.get(o.site_id).nom,
    observateur: observateurs.get(o.observateur_id).nom,
    scoreSante: o.score_sante
  });
}

const tagsParTortue = new Map();
for (const tt of T.tortue_tag) {
  if (!tagsParTortue.has(tt.tortue_id)) tagsParTortue.set(tt.tortue_id, []);
  tagsParTortue.get(tt.tortue_id).push(tags.get(tt.tag_id).libelle);
}

const inscParTortue = new Map();
for (const i of T.inscription) {
  if (!inscParTortue.has(i.tortue_id)) inscParTortue.set(i.tortue_id, []);
  inscParTortue.get(i.tortue_id).push({
    acronyme: programmesSql.get(i.programme_id).acronyme,
    dateInscription: quand(i.date_inscription)
  });
}

base.tortues.insertMany(T.tortue.map(t => {
  const e = especes.get(t.espece_id);
  const doc = {
    _id: t.id,
    nom: t.nom,
    espece: { nomScientifique: e.nom_scientifique, nomCommun: e.nom_commun, statutUicn: e.statut_uicn },
    mensurations: { longueurDossiereCm: t.longueur_dossiere_cm, poidsKg: t.poids_kg },
    tags: tagsParTortue.get(t.id) || [],
    programmes: inscParTortue.get(t.id) || [],
    observations: obsParTortue.get(t.id) || []
  };
  // habitat_id NULLABLE : Goliath n'a pas d'habitat, son document n'a
  // pas le champ. C6 compte exactement ca.
  if (t.habitat_id !== null) {
    const h = habitats.get(t.habitat_id);
    doc.habitat = { nom: h.nom, aireProtegee: h.aire_protegee };
  }
  return doc;
}));

titre("Le modele charge");
["habitats", "sites", "programmes", "tortues"].forEach(n =>
  dire(g(n, 14) + d(base.getCollection(n).countDocuments(), 5) + " documents"));
dire(g("dont", 14) + d(base.tortues.aggregate([
  { $group: { _id: null, n: { $sum: { $size: "$observations" } } } }]).toArray()[0].n, 5)
  + " observations embarquees");

if (typeof CASSE !== "undefined" && CASSE) {
  base.tortues.updateOne({ nom: "Crush" }, { $set: { "espece.nomCommun": "Tortue qui n existe pas" } });
  base.tortues.updateOne({ nom: "Crush" }, { $pop: { observations: 1 } });
  dire("");
  dire("CASSE=1 : Crush change d espece et perd une observation. C1, C2 et C3 doivent sortir KO.");
}

// =====================================================================
//  Les six questions, reposees au modele document
// =====================================================================

titre("Les six chiffres de controle, cote MongoDB");

// --- C1 : les tortues par espece.  L'espece est copiee dans chaque
// tortue : un $group, rien d'autre. Une espece que personne ne porte
// disparaitrait — le LEFT JOIN du SQL, lui, l'aurait montree a zero.
c.question("C1", "Les tortues par espece",
  base.tortues.aggregate([
    { $group: { _id: "$espece", n: { $sum: 1 } } },
    { $sort: { n: -1, "_id.nomScientifique": 1 } }
  ]).toArray().map(r => "    " + g(r._id.nomScientifique, 24) + g(r._id.nomCommun, 20)
      + r._id.statutUicn + d(r.n, 5) + " tortues"));

// --- C2 : les cinq sites les plus frequentes.  Les observations sont
// enfouies : il faut les ressortir une par une ($unwind) avant de
// compter. C'est le cout de l'embarquement. L'habitat du site, lui, est
// alle le chercher dans sites — pas recopie 727 fois.
c.question("C2", "Les cinq sites les plus frequentes",
  base.tortues.aggregate([
    { $unwind: "$observations" },
    { $group: { _id: "$observations.site", n: { $sum: 1 } } },
    { $sort:  { n: -1, _id: 1 } },
    { $limit: 5 },
    { $lookup: { from: "sites", localField: "_id", foreignField: "_id", as: "s" } },
    { $set: { habitat: { $first: "$s.habitat" } } }
  ]).toArray().map(r => "    " + g(r._id, 18) + g(r.habitat, 28) + d(r.n, 4) + " observations"));

// --- C3 : le score moyen par habitat DES TORTUES QUI Y VIVENT.  En SQL,
// trois jointures (tortue, habitat, observation). Ici l'habitat et les
// observations sont dans le meme document : zero jointure.
c.question("C3", "Score de sante moyen par habitat (des tortues qui y vivent)",
  base.tortues.aggregate([
    { $match: { habitat: { $exists: true } } },
    { $unwind: "$observations" },
    { $group: { _id: "$habitat.nom",
                somme: { $sum: "$observations.scoreSante" },
                n: { $sum: 1 } } },
    { $set:  { moyenne: { $divide: ["$somme", "$n"] } } },
    { $sort: { moyenne: -1 } }
  ]).toArray().map(r => "    " + g(r._id, 28) + moyenne(r.somme, r.n, 2)
      + "   sur " + d(r.n, 4) + " observations"));

// --- C4 : les programmes et leurs inscrites.  La date d'inscription est
// portee cote tortue : le programme ne sait pas qui est inscrit chez
// lui. KEL n'a aucune inscrite et doit quand meme apparaitre — on part
// donc des programmes, et on paie un $lookup. C'est la facture du choix
// de l'exercice 3.
c.question("C4", "Les programmes et leurs inscrites",
  base.programmes.aggregate([
    { $lookup: { from: "tortues", localField: "_id",
                 foreignField: "programmes.acronyme", as: "inscrites" } },
    { $set:  { n: { $size: "$inscrites" } } },
    { $sort: { n: -1, _id: 1 } }
  ]).toArray().map(r => "    " + g(r._id, 7) + g(r.statut, 10) + g(r.organisation.nom, 38)
      + d(r.n, 4) + " tortues"));

// --- C5 : les tags.  Un tableau de libelles : $unwind et $group.
c.question("C5", "Les tags, du plus porte au moins porte",
  base.tortues.aggregate([
    { $unwind: "$tags" },
    { $group: { _id: "$tags", n: { $sum: 1 } } },
    { $sort:  { n: -1, _id: 1 } }
  ]).toArray().map(r => "    " + g(r._id, 22) + d(r.n, 4) + " tortues"));

// --- C6 : les trous.  En SQL, IS NULL et NOT EXISTS. Ici, un champ
// absent et un tableau vide : ce n'est pas la meme chose qu'un NULL, et
// c'est precisement ce que le modele document dit mieux.
c.question("C6", "Les trous du jeu de donnees", [
  "    tortues sans habitat        " + d(base.tortues.countDocuments({ habitat: { $exists: false } }), 4),
  "    tortues jamais observees    " + d(base.tortues.countDocuments({ observations: { $size: 0 } }), 4),
  "    tortues dans aucun programme" + d(base.tortues.countDocuments({ programmes: { $size: 0 } }), 4),
  "    programmes toutes especes   " + d(base.programmes.countDocuments({ especeCible: { $exists: false } }), 4),
  "    programmes sans terme       " + d(base.programmes.countDocuments({ anneeFin: { $exists: false } }), 4)
]);

c.bilan();
