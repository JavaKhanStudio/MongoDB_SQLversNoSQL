# Sujet 3 — Les bateaux

> Douze tables, **47 colonnes**, et un héritage au milieu. Un bateau est **civil**
> ou **militaire** : l'un porte un armateur, un type et une capacité en EVP, l'autre
> une marine, une classe et un équipage. Aucun ne porte les colonnes de l'autre.
> SQL n'a que trois mauvaises réponses à ça. Le document en a une bonne.

## Référence

- Le schéma, tables et relations : `make bateaux-schema`
- Les chiffres à retrouver : `make bateaux-controle`
- La base, pour l'interroger : `make bateaux-sql`
- Le serveur d'arrivée : `make mongo`
- La correction, quand la vôtre sera faite : `git switch correction`,
  puis `make bateaux-verifier` — elle repose les six chiffres à MongoDB
- Le DDL : [`schema.sql`](schema.sql) · les données : [`donnees.sql`](donnees.sql)

---

## Le schéma SQL et ses relations

`A ◄─── B` se lit « B porte la clé étrangère vers A ».

```
  pays ◄─── port ◄─── quai ◄─── escale ◄─── cargaison   1:N BORNE — 3 par escale
       ◄─── bateau

  escale ───► bateau     1:N ILLIMITE — une escale par passage, cote bateau
         ───► quai       comme cote quai. depart NULLABLE : encore a quai.

  bateau ───► pays       le pavillon
         ───► port       port_attache_id, NULLABLE : deux bateaux n'en ont pas

  L'HERITAGE, en trois tables :

  bateau ◄─── bateau_civil       1:1   armateur, type_civil, capacite_evp,
         │                             port_en_lourd_t
         ◄─── bateau_militaire   1:1   marine, classe, equipage,
                                       propulsion_nucleaire

         bateau.categorie dit laquelle des deux lire. RIEN NE L'IMPOSE.

  bateau ◄─── affectation ───► capitaine    M:N AVEC dates — fin NULL = en cours
```

| table | ce qu'elle porte | colonnes | lignes |
|---|---|---|---|
| `pays` | le pavillon, et le pays du port | 2 | 7 |
| `port` | le port et son tirant d'eau maximal | 4 | 8 |
| `quai` | le quai — 1:N **borné** sur le port | 3 | 20 |
| `armateur` | qui arme les civils | 2 | 5 |
| `marine` | qui arme les militaires | 2 | 4 |
| `bateau` | ce que les deux ont en commun | 7 | 18 |
| `bateau_civil` | armateur, type, EVP, port en lourd | 5 | 10 |
| `bateau_militaire` | marine, classe, équipage, propulsion | 5 | 8 |
| `capitaine` | nom, brevet | 3 | 8 |
| `affectation` | M:N **avec dates** — `fin` NULL = en cours | 4 | 16 |
| `escale` | le log : 1:N **non borné** côté bateau et côté quai | 6 | 37 |
| `cargaison` | ce qui a été manipulé — 1:N borné sur l'escale | 4 | 29 |
| | | **47** | |

`armateur` et `marine` ne portent plus qu'un nom : deux tables **rigoureusement
identiques**, qui n'existent séparément que parce qu'une clé étrangère doit
pointer sur une table et une seule. C'est plus visible qu'avant.

---

## Ce que ce schéma a dans le ventre

**1 — L'héritage, en trois tables.** `bateau` porte le commun, `bateau_civil` et
`bateau_militaire` portent le reste. Trois conséquences que le SQL ne peut pas
éviter :

- il faut deux requêtes pour lister la flotte (`make bateaux-controle` C1 et C2 sont
  **la même question posée deux fois**) ;
- `bateau.categorie` dit quelle table fille aller lire, mais **aucune contrainte ne
  l'impose** : rien n'empêche un bateau `CIVIL` d'avoir une ligne dans
  `bateau_militaire`, ou de n'en avoir aucune ;
- pour éviter la jointure, on serait tenté de tout mettre dans `bateau` — huit
  colonnes de plus, dont **quatre NULL sur chacune des dix-huit lignes**. C'est
  l'autre mauvaise réponse.

**2 — Deux tables de même forme pour un même rôle.** `armateur` et `marine` sont
toutes les deux « qui arme ce bateau ». Elles sont séparées parce que la clé
étrangère doit pointer sur une table et une seule.

**3 — Un côté borné, un côté non borné.** Un port a vingt quais et n'en aura pas
deux mille ; un quai reçoit une escale par jour, pour toujours. Une escale porte
trois cargaisons ; un bateau en accumule des milliers.

**4 — Une règle qui croise deux tables.** Un bateau ne peut pas entrer dans un port
dont le tirant d'eau maximal est inférieur au sien. Cette règle-là, `CHECK` ne sait
pas l'écrire : elle compare `bateau.tirant_eau_m` à `port.tirant_eau_max_m`, deux
tables que l'escale ne rapproche qu'au moment du `SELECT`. La C6 trouve **deux**
escales qui la violent, et le `Delta Maas`, qui tire exactement les 16,0 m du Havre,
passe. Personne n'avait rien pour les arrêter.

---

## Ce qui a été ajouté, ce qui a été retiré

### Ajouté

| ajout | pourquoi |
|---|---|
| `escale` et `cargaison` | Sans journal, le schéma n'a que des référentiels : tout s'embarque et il n'y a rien à décider. L'escale donne le 1:N non borné, la cargaison le 1:N borné — les deux réponses opposées, dans le même sujet. |
| `affectation` avec `debut`/`fin` | Un simple `bateau.capitaine_id` aurait perdu l'histoire. Avec les dates, la liaison M:N porte quelque chose et ne peut plus devenir un simple tableau d'identifiants. |
| `port.tirant_eau_max_m` et `bateau.tirant_eau_m` | Pour poser une règle que SQL ne sait pas garder. La question « qu'est-ce que le document change à ça ? » a une réponse honnête : rien — et c'est une leçon. |
| `quai`, entre `port` et `escale` | Sans lui l'escale pointe sur le port et la chaîne de jointures est trop courte pour qu'on voie le problème. |
| `bateau.port_attache_id`, **nullable** | Deux bateaux n'en ont pas. Une référence optionnelle, qui deviendra un champ absent. |
| `escale.depart`, **nullable** | Trois escales sont ouvertes. `NULL` veut dire « toujours à quai », pas « inconnu » : deux sens pour un même marqueur. |

### Retiré

| retrait | pourquoi |
|---|---|
| `bateau.armateur_id` sur la table mère | Aurait aplati l'héritage avant que la question soit posée : un bateau militaire n'a pas d'armateur. |
| une table `type_marchandise` | `cargaison.marchandise` reste du texte. Un référentiel de plus n'apprendrait rien de neuf : le schéma en a déjà un, `pays`. |
| `escale.port_id` | Redondant : le port se déduit du quai. Laissé en place, il donnait la réponse « copier le port dans l'escale ». |
| une table `equipage` nominative | L'équipage reste un entier. Trois mille marins sur l'`Endeavour Point` feraient une table qui écrase tout le reste du sujet. |

### Dégraissé

Le schéma tient dans un **budget de 47 colonnes**. Dix-neuf colonnes de décor sont
tombées : c'était le sujet le plus chargé des trois, et l'héritage lui coûte déjà
trois tables.

| colonnes tombées | pourquoi |
|---|---|
| `pays.code_iso` | Un second identifiant sur une table de sept lignes. |
| `port.latitude`, `.longitude`, `.militaire` | Des coordonnées qu'aucune question n'interroge. `tirant_eau_max_m` reste : c'est la moitié de la règle que `CHECK` ne sait pas écrire. |
| `quai.longueur_m`, `.type` | Le quai est là pour allonger la chaîne `port → quai → escale` et pour être **borné**. Il n'a besoin que d'un numéro pour ça. |
| `armateur.pays_id`, `.flotte_totale`, `marine.pays_id`, `.devise` | Vidées exprès : deux tables qui ne portent plus qu'un nom, et qui restent pourtant deux. La question « pourquoi deux tables ? » n'a plus de décor derrière quoi se cacher. |
| `bateau.longueur_m`, `.annee_lancement` | Deux mesures de fiche. `tirant_eau_m` reste, lui : il est la seconde moitié de la règle. |
| `bateau_civil.assureur` | Une chaîne de plus du côté civil. Le déséquilibre civil/militaire se voit aussi bien avec quatre colonnes de chaque côté — et il se voit mieux : **huit colonnes, quatre NULL par ligne**, si on aplatit tout dans `bateau`. |
| `bateau_militaire.indicatif`, `.armement_principal` | Idem côté militaire. |
| `capitaine.nationalite_id` | Un cinquième chemin vers `pays`, qui ne décidait rien. |
| `affectation.id` | La clé primaire est la paire et sa date de début : `(capitaine_id, bateau_id, debut)`. Une liaison M:N n'a pas besoin d'un identifiant à elle. |
| `cargaison.sens`, `.dangereuse` | La C3 somme des tonnes. Le sens du mouvement ne change aucune décision d'embarquement. |

Rien de ce qui portait une tension n'a bougé : l'héritage en trois tables,
`armateur`/`marine`, `quai` borné contre `escale` non bornée, `affectation`
avec ses dates, `port_attache_id` et `escale.depart` nullables, et la règle du
tirant d'eau qui croise deux tables. Les six chiffres de `make bateaux-controle`
sont **inchangés**.

---

## Exercices

Charger la base : `make bateaux`. La base MongoDB s'appelle `bateaux`.
Chaque exercice part de la base SQL telle quelle : aucun ne lit ce qu'un autre a écrit.

### Exercice 1

1. Lancer `make bateaux-controle` et lire C1 et C2. Écrire la requête SQL qui
   répondrait aux deux **en une seule fois**, et compter les colonnes vides
   qu'elle produit.
2. Écrire, à la main, le document du `Yangtze Star` et celui de l'`Endeavour Point`
   dans une collection `bateaux` unique.
3. Lister les champs que l'un a et l'autre pas.
4. Écrire la requête qui sort toute la flotte, civils et militaires mélangés,
   triée par tirant d'eau décroissant.
5. Écrire la requête qui sort les seuls militaires à propulsion nucléaire.

### Exercice 2

Les ports et leurs quais.

1. Écrire la collection `ports`, quais compris.
2. Retrouver la C3 de `make bateaux-controle` — le tonnage manipulé par port.
3. Retrouver la C4 — les bateaux encore à quai, avec le nom du port et le numéro
   du quai.
4. Dire pourquoi les quais sont dans le port et les escales ne le sont pas.
5. Donner le nombre d'escales qu'il faudrait pour que la réponse change.

### Exercice 3

Le journal des escales.

1. Écrire la collection `escales`, cargaisons comprises, avec une copie du bateau
   (nom, IMO, catégorie) et du port (nom, quai).
2. Retrouver la C3 sans aucun `$lookup`.
3. Le `Delta Maas` est revendu et rebaptisé `Zuiderkruis`.
4. Compter les escales qui portent encore l'ancien nom.
5. Dire ce que cela aurait coûté si la copie avait porté, en plus, l'armateur du
   bateau et son port d'attache — et vérifier le chiffre.

### Exercice 4  (Exploration)

La C6 trouve deux escales impossibles : un bateau qui tire plus d'eau que son port
n'en autorise.

1. Retrouver ces deux escales sur le modèle document.
2. Faire en sorte que le serveur, et non le code, refuse la prochaine escale d'un
   bateau trop profond pour son quai — sans recopier le tirant d'eau du port dans
   chaque escale.
3. Vérifier en tentant d'insérer l'escale du `Straits Pioneer` à Brest.
4. Dire ce qui, dans la solution trouvée, n'existe pas en SQL — et ce qui n'existe
   toujours pas en MongoDB.
