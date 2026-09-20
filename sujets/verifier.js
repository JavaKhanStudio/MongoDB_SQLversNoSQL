// =====================================================================
//  Les outils des trois corrections. Charge par load() en tete de
//  chaque sujets/<n>-<sujet>/correction.js.
// =====================================================================
//  Le contrat est toujours le meme : make <sujet>-verifier a depose
//  dans le conteneur mongo
//     /tmp/<base>-tables.json    la base SQL telle quelle (vers-json.sql)
//     /tmp/<base>-attendu.txt    ce que controle.sql vient de repondre
//  La correction lit la premiere, en fabrique des documents, repose les
//  six questions a MongoDB, et compare ses lignes a la seconde. Rien
//  n'est recopie a la main : si le SQL bouge, l'attendu bouge avec lui.
// =====================================================================

const fs = require("fs");

function titre(t) { print("\n=== " + t + " " + "=".repeat(Math.max(0, 66 - t.length))); }
function dire(t)  { print("  " + t); }

// Les deux fichiers viennent de make : joue a la main, mongosh dirait
// seulement ENOENT. On dit plutot quoi lancer.
function lire(chemin, base, quoi) {
  if (!fs.existsSync(chemin)) {
    print("\n  " + quoi + " manque : " + chemin);
    print("  C'est make " + base + "-verifier qui le depose. Le lancer plutot que ce fichier.\n");
    quit(2);
  }
  const t = fs.readFileSync(chemin, "utf8");
  if (t.trim() === "") {
    print("\n  " + quoi + " est vide : " + chemin);
    print("  La base SQL " + base + " est-elle chargee ?  make " + base + "\n");
    quit(2);
  }
  return t;
}

// Les tables SQL, en JSON, telles que vers-json.sql les a rendues.
function tables(base) {
  return JSON.parse(lire("/tmp/" + base + "-tables.json", base, "la base SQL en JSON"));
}

// Mise en forme : les memes largeurs que controle.sql.
function g(v, n) { return String(v).padEnd(n); }    // rpad
function d(v, n) { return String(v).padStart(n); }  // lpad

// to_char(x, 'FM990.00') arrondit la moitie VERS LE HAUT. toFixed part
// d'un double et ne le garantit pas : on arrondit donc sur des entiers.
// deci(1845.35, 2) -> "1845.35"   deci(692100.0, 0) -> "692100"
function deci(x, dec) {
  const f = Math.pow(10, dec);
  const e = Math.floor(Math.abs(x) * f + 0.5);
  const s = dec === 0 ? String(e) : Math.floor(e / f) + "." + String(e % f).padStart(dec, "0");
  return (x < 0 ? "-" : "") + s;
}

// La meme chose pour une moyenne : AVG puis to_char. somme et n sont
// entiers, l'arrondi est donc exact.
function moyenne(somme, n, dec) {
  const f = Math.pow(10, dec);
  const e = Math.floor((somme * f * 2 + n) / (2 * n));
  return Math.floor(e / f) + "." + String(e % f).padStart(dec, "0");
}

// Les horodatages de PostgreSQL arrivent sans fuseau ("2026-04-20T08:00:00").
// JS les lirait en heure locale : on les ancre en UTC, et on les relit en UTC.
function quand(s) {
  if (s === null || s === undefined) return null;
  return new Date(s.length === 10 ? s + "T00:00:00Z" : s + "Z");
}
function jjmmaaaa(dt) {
  return String(dt.getUTCDate()).padStart(2, "0") + "/"
       + String(dt.getUTCMonth() + 1).padStart(2, "0") + "/"
       + dt.getUTCFullYear();
}

// ---------------------------------------------------------------------
// Le verdict. Une question = un bloc de lignes ; on les compare a celles
// que psql vient d'imprimer, dans l'ordre, au caractere pres.
// ---------------------------------------------------------------------

function controle(base) {
  const brut = lire("/tmp/" + base + "-attendu.txt", base, "la sortie de controle.sql").split("\n");
  const att = {};
  let cle = null, commence = false;
  for (const l of brut) {
    const m = l.match(/^(C[1-6])\s/);
    if (m) { cle = m[1]; att[cle] = []; commence = false; continue; }
    if (cle === null) continue;
    if (l.trim() === "") {
      if (att[cle].length) cle = null;   // le bloc est fini
      else commence = true;              // la question pouvait tenir sur deux lignes
      continue;
    }
    if (commence) att[cle].push(l.replace(/\s+$/, ""));
  }

  let ko = 0, posees = 0;
  return {
    // lignes : ce que le modele document repond, deja mis en forme.
    question: function (num, intitule, lignes) {
      posees++;
      const a = att[num] || [];
      const o = lignes.map(l => String(l).replace(/\s+$/, ""));
      const bon = a.length === o.length && a.every((l, i) => l === o[i]);
      if (!bon) ko++;
      print((bon ? "  OK  " : "  KO  ") + num + "  " + intitule);
      if (!bon) {
        for (let i = 0; i < Math.max(a.length, o.length); i++) {
          if (a[i] === o[i]) continue;
          print("          SQL   |" + (a[i] === undefined ? "  (pas de ligne)" : a[i]));
          print("          Mongo |" + (o[i] === undefined ? "  (pas de ligne)" : o[i]));
        }
      }
      return bon;
    },
    bilan: function () {
      print("");
      if (ko === 0) dire(posees + " questions sur " + posees + " : le modele document rend les memes lignes que le SQL.");
      else          dire(ko + " question(s) sur " + posees + " ne retrouvent pas le chiffre du SQL.");
      print("");
      quit(ko === 0 ? 0 : 1);
    }
  };
}
