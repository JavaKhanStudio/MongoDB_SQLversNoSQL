// =====================================================================
//  DB 1 — « Dune » : la correction
//  Le modele document de reference, et les six questions de
//  controle.sql reposees a MongoDB.
// =====================================================================
//  Joue par  : make dune-verifier    (make dune-verifier CASSE=1 casse
//              volontairement un document, pour voir le verificateur mordre)
//  Base de travail : dune_correction — surtout PAS dune, ou l'etudiant
//  ecrit son propre modele.
//
//  LE MODELE
//    regions              une region, et dedans ses puits et ses vers.
//                         1:N bornes : cinq puits, sept vers, et ce sera tout.
//    releves              PAS dans regions : une mesure par heure et par
//                         puits, pour toujours. Le seul 1:N non borne du
//                         sujet est le seul qui reste dehors.
//    contremaitres        le referentiel : il faut pouvoir citer un
//                         contremaitre qui n'a encore rien sorti (C5).
//    collectes            le document polymorphe. Une reussie porte
//                         tonnes/puretePct/dureeMinutes ; une echouee porte
//                         cause/ver/materielPerdu/pertesHumaines. Aucune ne
//                         porte les champs de l'autre : ils sont ABSENTS,
//                         pas NULL. Elle embarque une copie du puits (code,
//                         region) et du contremaitre (nom, maison) : un log
//                         s'ecrit une fois et se lit mille fois.
//    plateformesMinage    compatibilite n'avait que ses deux cles : elle
//    plateformesTransport devient un tableau de matricules, pas une collection.
//
//  CE QUE LE MODELE PERD, et c'est le prix a payer :
//    - changer la maison d'un contremaitre demande DEUX ecritures (le
//      referentiel, puis toutes les collectes qui le citent) — exercice 3 ;
//    - rien n'empeche les deux copies de diverger : le serveur ne le sait pas.
// =====================================================================

load("/projet/sujets/verifier.js");

const base = db.getSiblingDB("dune_correction");
const T    = tables("dune");
const c    = controle("dune");

const parId = a => new Map(a.map(x => [x.id, x]));
const regionsSql = parId(T.region);
const puitsSql   = parId(T.puits);
const versSql    = parId(T.ver);
const chefsSql   = parId(T.contremaitre);
const minageSql  = parId(T.plateforme_minage);
const transpSql  = parId(T.plateforme_transport);

base.dropDatabase();

// ---------------------------------------------------------------------
// 1. Le territoire : une region, ses puits, ses vers
// ---------------------------------------------------------------------

base.regions.insertMany(T.region.map(r => ({
  _id: r.nom,
  hemisphere: r.hemisphere,
  indiceTempete: r.indice_tempete,
  puits: T.puits.filter(p => p.region_id === r.id).map(p => ({ code: p.code, epuise: p.epuise })),
  vers:  T.ver.filter(v => v.region_id === r.id).map(v => ({ nom: v.nom, statut: v.statut }))
})));

// ---------------------------------------------------------------------
// 2. Les hommes et le materiel
// ---------------------------------------------------------------------

base.contremaitres.insertMany(T.contremaitre.map(cm => ({
  _id: cm.nom, maison: cm.maison, ancienneteAnnees: cm.anciennete_annees
})));

base.plateformesMinage.insertMany(T.plateforme_minage.map(m => ({
  _id: m.matricule,
  modele: m.modele,
  // compatibilite, la table de liaison PURE, tient ici en une ligne.
  transports: T.compatibilite.filter(x => x.plateforme_minage_id === m.id)
                             .map(x => transpSql.get(x.plateforme_transport_id).matricule)
})));

base.plateformesTransport.insertMany(T.plateforme_transport.map(t => ({
  _id: t.matricule, modele: t.modele
})));

// ---------------------------------------------------------------------
// 3. Le journal des collectes : le document polymorphe
// ---------------------------------------------------------------------

base.collectes.insertMany(T.collecte.map(co => {
  const p  = puitsSql.get(co.puits_id);
  const cm = chefsSql.get(co.contremaitre_id);
  const doc = {
    _id: co.id,
    debut: quand(co.debut),
    statut: co.statut,
    puits: { code: p.code, region: regionsSql.get(p.region_id).nom },
    contremaitre: { nom: cm.nom, maison: cm.maison },
    plateformes: {
      minage:    minageSql.get(co.plateforme_minage_id).matricule,
      transport: transpSql.get(co.plateforme_transport_id).matricule
    }
  };
  if (co.statut === "REUSSIE") {
    doc.tonnes        = co.tonnes_epice;
    doc.puretePct     = co.purete_pct;
    doc.dureeMinutes  = co.duree_minutes;
  } else {
    doc.cause          = co.cause;
    doc.materielPerdu  = co.materiel_perdu;
    doc.pertesHumaines = co.pertes_humaines;
    if (co.ver_id !== null) doc.ver = { nom: versSql.get(co.ver_id).nom };
  }
  return doc;
}));

// ---------------------------------------------------------------------
// 4. Les relevés : dehors, et references par le code du puits
// ---------------------------------------------------------------------

base.releves.insertMany(T.releve_vibration.map(rv => ({
  _id: rv.id,
  puits: puitsSql.get(rv.puits_id).code,
  mesureLe: quand(rv.mesure_le),
  amplitude: rv.amplitude
})));

titre("Le modele charge");
["regions", "contremaitres", "plateformesMinage", "plateformesTransport", "collectes", "releves"]
  .forEach(n => dire(g(n, 22) + d(base.getCollection(n).countDocuments(), 5) + " documents"));

if (typeof CASSE !== "undefined" && CASSE) {
  const cassee = base.collectes.findOne({ statut: "REUSSIE" }, { sort: { _id: 1 } });
  base.collectes.updateOne({ _id: cassee._id }, { $set: { tonnes: 0 } });
  dire("");
  dire("CASSE=1 : la collecte " + cassee._id + " passe a 0 tonne. C1, C3 et C5 doivent sortir KO.");
}

// =====================================================================
//  Les six questions, reposees au modele document
// =====================================================================

titre("Les six chiffres de controle, cote MongoDB");

// --- C1 : le tonnage par region.  La region est DANS la collecte : un
// seul $group, aucun $lookup. C'est ce que la copie a achete.
c.question("C1", "Tonnage d epice collecte par region",
  base.collectes.aggregate([
    { $match: { statut: "REUSSIE" } },
    { $group: { _id: "$puits.region", total: { $sum: "$tonnes" } } },
    { $sort:  { total: -1 } }
  ]).toArray().map(r => "    " + g(r._id, 22) + d(deci(r.total, 2), 10) + " t"));

// --- C2 : les echecs par cause. Les champs d'echec n'existent que sur
// les documents echoues : le $match sur statut suffit.
c.question("C2", "Echecs par cause",
  base.collectes.aggregate([
    { $match: { statut: "ECHOUEE" } },
    { $group: { _id: "$cause",
                n: { $sum: 1 },
                morts: { $sum: "$pertesHumaines" },
                perdu: { $sum: { $cond: ["$materielPerdu", 1, 0] } } } },
    { $sort: { n: -1, _id: 1 } }
  ]).toArray().map(r => "    " + g(r._id, 12) + d(r.n, 3) + " echecs, "
      + d(r.morts, 3) + " morts, materiel perdu " + r.perdu + " fois"));

// --- C3 : les trois puits les plus productifs.
c.question("C3", "Les trois puits les plus productifs",
  base.collectes.aggregate([
    { $match: { statut: "REUSSIE" } },
    { $group: { _id: "$puits.code", total: { $sum: "$tonnes" }, n: { $sum: 1 } } },
    { $sort:  { total: -1 } },
    { $limit: 3 }
  ]).toArray().map(r => "    " + g(r._id, 8) + d(deci(r.total, 2), 10) + " t en "
      + r.n + " collectes reussies"));

// --- C4 : les vers qui ont fait echouer une collecte.
c.question("C4", "Les vers qui ont fait echouer une collecte",
  base.collectes.aggregate([
    { $match: { statut: "ECHOUEE", cause: "VER" } },
    { $group: { _id: "$ver.nom", n: { $sum: 1 }, morts: { $sum: "$pertesHumaines" } } },
    { $sort: { n: -1, _id: 1 } }
  ]).toArray().map(r => "    " + g(r._id, 22) + d(r.n, 2) + " collectes detruites, "
      + r.morts + " morts"));

// --- C5 : les contremaitres.  Stilgar n'a jamais rien sorti et doit
// quand meme apparaitre : c'est le LEFT JOIN du SQL. Partir des
// collectes le ferait disparaitre — on part donc du referentiel, et on
// paie un $lookup. La copie ne dispense pas de garder la collection.
c.question("C5", "Contremaitres : ce qu ils ont sorti, ce qu ils ont perdu",
  base.contremaitres.aggregate([
    { $lookup: { from: "collectes", localField: "_id",
                 foreignField: "contremaitre.nom", as: "siennes" } },
    { $project: { maison: 1,
                  total: { $sum: "$siennes.tonnes" },
                  echecs: { $size: { $filter: { input: "$siennes",
                                                cond: { $eq: ["$$this.statut", "ECHOUEE"] } } } } } },
    { $sort: { total: -1 } }
  ]).toArray().map(r => "    " + g(r._id, 18) + g(r.maison, 11)
      + d(deci(r.total, 2), 10) + " t   " + r.echecs + " echecs"));

// --- C6 : les puits sous alerte.  releve_vibration.alerte_ver n'existe
// plus : l'alerte se recalcule depuis l'amplitude, comme en SQL.
c.question("C6", "Puits sous alerte : un releve d amplitude superieure a 5.00",
  base.releves.aggregate([
    { $match: { amplitude: { $gt: 5.00 } } },
    { $group: { _id: "$puits", n: { $sum: 1 }, pic: { $max: "$amplitude" } } },
    { $sort: { pic: -1 } }
  ]).toArray().map(r => "    " + g(r._id, 8) + d(r.n, 2) + " alertes, pic a "
      + deci(r.pic, 2)));

c.bilan();
