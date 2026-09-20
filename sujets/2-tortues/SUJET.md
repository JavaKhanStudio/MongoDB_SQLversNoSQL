# Sujet 2 — Les tortues

> Le projet fil rouge du cours, pris à l'envers. Les 139 tortues, les 12 récifs
> et les 8 programmes que vous avez déjà chargés en MongoDB pour la section
> « Indexing » — mais cette fois **le point de départ est le SQL**, remis au
> propre et normalisé jusqu'au bout. Treize tables, **46 colonnes**. Il faut
> revenir au document.

## Référence

- Le schéma, tables et relations : `make tortues-schema`
- Les chiffres à retrouver : `make tortues-controle`
- La base, pour l'interroger : `make tortues-sql`
- Le serveur d'arrivée : `make mongo`
- La correction, quand la vôtre sera faite : `git switch correction`,
  puis `make tortues-verifier` — elle repose les six chiffres à MongoDB
- Le DDL : [`schema.sql`](schema.sql) · les données : [`donnees.sql`](donnees.sql),
  fabriquées par [`generer.py`](generer.py) depuis `~/Documents/GitHub/MongoDB_Tortues`
- Le même domaine en Spring, JPA d'un côté et Spring Data Mongo de l'autre :
  `~/Documents/GitHub/Spring_MongoDB_VsSQL`

---

## Le schéma SQL et ses relations

`A ◄─── B` se lit « B porte la clé étrangère vers A ».

```
  pays  ◄─── organisation ◄─── programme ◄─── protocole    1:1 — jamais l'un sans l'autre
                                    │
                                    └───► espece          NULL = « toutes especes »

  habitat ◄─── site
      ▲
      └──── tortue ───► espece
               ▲        habitat_id est NULLABLE : une tortue n'en a pas
               │
               ├─── tortue_tag  ───► tag         M:N PUR — aucun attribut
               └─── inscription ───► programme   M:N AVEC attribut — date_inscription

  observation ───► tortue
              ───► site           habitat > site > observation : trois etages
              ───► observateur    1:N ILLIMITE — 727 lignes pour 139 tortues
```

| table | ce qu'elle porte | colonnes | lignes |
|---|---|---|---|
| `pays` | France, Australie, Mexique, Thaïlande, Équateur | 2 | 5 |
| `espece` | nom scientifique, nom commun, statut UICN | 4 | 6 |
| `organisation` | CNRS, AIMS, IUCN… et leur pays | 3 | 7 |
| `habitat` | le récif, et s'il est en aire protégée | 3 | 12 |
| `site` | le lieu précis où l'on observe, dans un habitat | 3 | 28 |
| `observateur` | qui relève sur le terrain | 2 | 14 |
| `tortue` | la tortue, ses mensurations à plat dans la ligne | 6 | 139 |
| `tag` | adulte, pondeuse, balise-argos… | 2 | 13 |
| `tortue_tag` | liaison M:N **pure** | 2 | 285 |
| `observation` | une rencontre : date, site, observateur, score de santé | 6 | 727 |
| `programme` | le programme de suivi, son organisme, son espèce cible | 7 | 8 |
| `protocole` | le protocole du programme — **1:1** | 3 | 8 |
| `inscription` | liaison M:N **avec attribut** : la date d'entrée | 3 | 212 |
| | | **46** | |

Treize tables pour 46 colonnes : trois colonnes et demie par table. C'est la
signature d'un schéma normalisé — et c'est exactement ce qu'on vient défaire.

---

## Ce que le nettoyage a changé

Le projet tortue tel qu'il existe en Mongo (`MongoDB_Tortues`) porte les traces
d'un modèle document. Les remettre à plat, c'est ce qui donne un vrai point de
départ SQL — et ce qui rend le chemin du retour instructif.

### Retiré

| retrait | pourquoi |
|---|---|
| `turtle.habitatName` | Le document recopie le nom de l'habitat **à côté** de sa référence. Les 138 copies sont exactes aujourd'hui — c'est justement pour ça que c'est un piège : rien ne signale qu'elles peuvent diverger. En SQL il n'y a qu'un chemin, `habitat_id`. |
| `turtle.programs[].name` et `.organisation` | Même geste : chaque tortue recopie le nom et l'organisme de ses programmes. La liaison ne garde que ce qui lui appartient — la date d'inscription. |
| `program.protocol` (sous-document) | Sorti en table `protocole`, 1:1 avec le programme. C'est la forme normale ; c'est aussi la question la plus intéressante du retour. |
| `program.coordinationCountry` | Redondant une fois `organisation.pays_id` posé : les deux programmes du CNRS coordonnent depuis la France, forcément. |
| `observations[].site` et `.observer` en texte libre | 727 chaînes recopiées, 28 sites et 14 observateurs réels. Devenus des tables. |
| `turtle.species` en texte libre | Devenu `espece_id`. Six espèces, écrites une fois. |

### Ajouté

| ajout | pourquoi |
|---|---|
| `espece.nom_commun` et `.statut_uicn` | Une espèce n'était qu'une chaîne. Deux attributs suffisent pour que « on copie l'espèce dans la tortue ou on la référence ? » ait une réponse qui se discute. Statuts UICN réels. |
| `site`, entre `habitat` et `observation` | Le document n'avait que le nom du site. La hiérarchie `habitat → site → observation` fabrique une chaîne de trois jointures : c'est elle qu'on veut voir disparaître côté document. |
| `inscription.date_inscription` | Sans attribut, une liaison M:N est un simple tableau d'identifiants et il n'y a rien à décider. Avec, il faut choisir de quel côté la porter. |
| `pays` et `organisation` | Un référentiel minuscule, lu partout, jamais modifié : le cas d'école de la copie assumée. |

### Nettoyé

- Le tag `jamais revue` (avec une espace) suivait mal la convention des douze
  autres. Devenu `jamais-revue`.
- Les **trous sont restés** : une tortue sans habitat (Goliath), deux jamais
  observées (Flibuste, Mascaret), 22 dans aucun programme, 2 programmes sans
  espèce cible, 4 sans année de fin. `make tortues-controle` C6 les compte. Un jeu
  sans trou apprendrait à écrire des requêtes qui mentent.

### Dégraissé

Le schéma tient dans un **budget de 46 colonnes**. Quatorze colonnes et une table
sont tombées après coup : la normalisation fabrique déjà beaucoup de tables, alors
tout ce qui ne pesait sur aucune décision est parti.

| ce qui est tombé | pourquoi |
|---|---|
| la table `ocean` et `habitat.ocean_id` | Un deuxième référentiel à deux colonnes, qui posait exactement la question que `pays` pose déjà. La chaîne qui compte est `habitat → site → observation`, pas l'étage au-dessus. |
| `habitat.temp_eau_c` | Une mesure qu'aucune question n'interroge. `aire_protegee` reste : c'est elle que l'exercice 4 fait basculer. |
| `tortue.sexe`, `.annee_naissance` | Deux attributs de fiche. Les mensurations suffisent à poser « à plat dans la ligne, ou dans un sous-document ? ». |
| `programme.responsable`, `.courriel`, `.site_web`, `.description`, `.budget_euros`, `.annee_debut` | Six colonnes de fiche signalétique sur la table la plus large du schéma. Ce qui décide, c'est `organisation_id` (référence ou copie), `espece_cible_id` (nullable) et `annee_fin` (nullable) — ils restent. |
| `protocole.longueur_min_cm`, `.suivi_satellite` | Le 1:1 reste un 1:1 avec deux attributs. Cinq n'en faisaient pas une meilleure question. |

Rien de ce qui portait une tension n'a bougé : `tortue_tag` (M:N pur),
`inscription.date_inscription` (M:N avec attribut), `protocole` (1:1),
`observation` (1:N non borné), `tortue.habitat_id` (référence nullable).
Les six chiffres de `make tortues-controle` sont **inchangés**.

---

## Exercices

Charger la base : `make tortues`. La base MongoDB s'appelle `tortues`.
Chaque exercice part de la base SQL telle quelle : aucun ne lit ce qu'un autre a écrit.

### Exercice 1

1. Lire le schéma (`make tortues-schema`) et compter les jointures qu'il faut pour
   répondre à la C3 de `make tortues-controle`.
2. Classer les treize tables en trois piles : celles qui deviendront une
   collection, celles qui deviendront un champ d'un autre document, celles qui
   disparaîtront.
3. Justifier chaque table de la pile « disparaît » en une ligne.
4. Écrire à la main le document d'une tortue — prendre `Crush` — avec son espèce,
   son habitat, ses tags et ses mensurations.
5. Compter les jointures qu'il reste pour répondre à la C3 sur ce document.

### Exercice 2

Peupler `tortues` depuis le SQL.

1. Écrire la collection `tortues` avec les 139 tortues et leurs observations.
2. Retrouver la C1 de `make tortues-controle` — les tortues par espèce, avec leur
   statut UICN — en une seule agrégation.
3. Retrouver la C2 — les cinq sites les plus fréquentés, avec le nom de leur habitat.
4. Retrouver la C6 — les trous : sans habitat, jamais observée, dans aucun programme.
5. Dire ce qui, dans le document, rend la C2 plus facile ou plus difficile qu'en SQL.

### Exercice 3

Le protocole et le programme.

1. Écrire la collection `programmes`, protocole compris.
2. Retrouver la C4 — les programmes et le nombre de tortues inscrites.
3. Le programme `KEL` reprend : passer son statut à `ACTIF`.
4. Inscrire la tortue `Crush` au programme `KEL`, avec sa date d'inscription.
5. Dire de quel côté la date d'inscription a été écrite, et lister les deux
   questions que ce choix rend coûteuses.

### Exercice 4  (Exploration)

L'aire protégée de la Grande Barrière de corail est déclassée : `aire_protegee`
passe à faux.

1. Faire passer ce changement dans le modèle document, partout où il se voit.
2. Sortir la liste des tortues qui vivent désormais hors aire protégée.
3. Sortir la même liste, mais **sans jamais écrire le nom d'un habitat** dans la
   requête, et en une seule requête.
4. Dire combien de documents auraient été réécrits si l'habitat avait été copié
   dans chaque observation plutôt que dans chaque tortue — et vérifier le chiffre.
