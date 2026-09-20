# SQL vers NoSQL

> Trois bases SQL complètes, chargées et interrogeables, dont on demande le modèle
> document qui leur correspond. Accompagne la slide « SQL vers NoSQL » du deck
> MongoDB, section « Exercices récapitulatif ». Les trois sujets se présentent et
> se testent depuis ce seul projet.

---

## Récupérer le projet

```bash
git clone https://github.com/JavaKhanStudio/MongoDB_SQLversNoSQL.git
cd MongoDB_SQLversNoSQL
```

La correction n'est pas sur cette branche. Elle vit sur la branche `correction`,
qu'il faut aller chercher à la main — c'est voulu :

```bash
git switch correction    # ajoute les corrections et `make <sujet>-verifier`
git switch main          # les retire de nouveau
```

---

## Démarrage

```bash
make demarrer    # PostgreSQL 16 sur 55432, MongoDB 8.0 sur 27041
make sujets      # les trois sujets, en une page
make dune        # charge la premiere base ; puis tortues, puis bateaux
```

Sous Podman rootless (Fedora) :
`export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` avant `make`.

`make aide` liste tout.

---

## Les trois sujets

| sujet | domaine | tables | colonnes | ce qu'on y apprend |
|---|---|---|---|---|
| [`1-dune`](sujets/1-dune/SUJET.md) | l'épice sur Arrakis : régions, vers, puits, plateformes, contremaîtres, logs de collecte | 9 | 42 | **le document polymorphe** — une collecte réussie et une collecte échouée ne portent pas les mêmes informations, et SQL les range dans la même table |
| [`2-tortues`](sujets/2-tortues/SUJET.md) | le projet fil rouge, normalisé jusqu'au bout | 13 | 46 | **le chemin inverse** — ce que le document recopiait est ici une table ; il faut décider quoi recopier à nouveau |
| [`3-bateaux`](sujets/3-bateaux/SUJET.md) | civils et militaires, ports, quais, escales | 12 | 47 | **l'héritage** — un bateau est civil ou militaire, et SQL n'a que de mauvaises réponses |

Les trois sont indépendants : n'importe quel ordre, et on peut s'arrêter après un seul.

Chaque base tient dans un **budget de colonnes** : 40 visées, 50 au maximum, toutes
tables confondues. Ce qui reste porte une décision de modélisation ; le décor est
parti. Chaque `SUJET.md` a une section « Dégraissé » qui dit ce qui est tombé et
pourquoi.

---

## Ce qu'on fait sur un sujet

`<sujet>` vaut `dune`, `tortues` ou `bateaux`.

| commande | ce qu'elle donne |
|---|---|
| `make <sujet>` | jette la base et la refait, schéma et données. Rejouable autant qu'on veut. |
| `make <sujet>-schema` | les tables avec leurs colonnes, toutes les relations, et **le pourcentage de NULL de chaque colonne** — lu dans le catalogue PostgreSQL, pas écrit à la main |
| `make <sujet>-controle` | six séries de chiffres. Vrais sur le SQL, ils doivent rester vrais sur les documents : **c'est le test du sujet** |
| `make <sujet>-sql` | un `psql` sur la base |
| `make mongo` | un `mongosh` sur le serveur d'arrivée |
| `make <sujet>-verifier` | **la correction**, sur la branche `correction` — `git switch correction` d'abord. Elle charge le modèle document de référence dans `<sujet>_correction` et repose les six questions à MongoDB. Six `OK`, ou un `KO` avec la ligne du SQL en face de celle du document. `CASSE=1` abîme volontairement un document, pour voir le vérificateur mordre |

L'énoncé de chaque sujet est son `SUJET.md` : le schéma commenté, ce qui a été
ajouté ou retiré pour rendre la transformation intéressante, et les exercices.

### Comment on teste une transformation

Le modèle document est un choix, pas une réponse unique — on ne peut donc pas
comparer deux collections. Ce qui se compare, ce sont les **réponses** : les six
questions de `make <sujet>-controle` ne dépendent d'aucun modèle. Elles sont vraies
sur les tables ; si elles ne sont plus vraies sur les documents, quelque chose a été
perdu en route.

```bash
make dune-controle        # les six reponses, cote SQL
make mongo                # puis les reposer, cote document
```

Et la correction fait exactement ça, sans personne pour comparer à l'œil :

```bash
git switch correction       # la correction vit sur cette branche
make dune-verifier          # six OK, ou un KO qui montre les deux lignes
make dune-verifier CASSE=1  # un document abime : le verificateur doit mordre
git switch main             # revenir au sujet seul
```

Elle travaille dans une base à elle — `dune_correction`, `tortues_correction`,
`bateaux_correction` — et ne touche jamais à celle où l'étudiant écrit. Elle ne
recopie aucun chiffre : à chaque passage, `controle.sql` est rejoué sur le SQL et
c'est **sa sortie** qui sert d'attendu. Un chiffre qui bougerait côté SQL bougerait
des deux côtés à la fois.

---

## Où est la correction

Sur une branche à elle, `correction`, qu'on va chercher à la main :

```bash
git switch correction    # les trois correction.js et le verificateur apparaissent
make dune-verifier       # la correction du premier sujet se joue
git switch main          # ils disparaissent ; le sujet reste
```

Cinq fichiers font la différence entre les deux branches — `sujets/verifier.js`,
`sujets/vers-json.sql` et les trois `sujets/<n>-<sujet>/correction.js`. Tout le
reste, `Makefile` compris, est identique : le projet ne se corrige qu'une fois.

Sur `main`, `make <sujet>-verifier` existe toujours, et dit où aller.

---

## Arborescence

```
docker/docker-compose.yml   postgres:16 (55432) + mongo:8.0 (27041), depot monte en /projet
Makefile                    make aide
sujets/SUJETS.txt           la page que `make sujets` affiche
sujets/relations.sql        le rapport de schema, le meme pour les trois bases
sujets/vers-json.sql        la base SQL -> un objet JSON (branche correction)
sujets/verifier.js          les outils de la correction : mise en forme et verdict
                            (branche correction)
sujets/<n>-<sujet>/
    SUJET.md                l'enonce : schema commente, suggestions, exercices
    schema.sql              le DDL
    donnees.sql             le jeu de donnees
    controle.sql            les six chiffres de reference
    correction.js           LA CORRECTION : le modele document, et les six
                            questions reposees a MongoDB (branche correction)
sujets/2-tortues/generer.py fabrique donnees.sql depuis ~/Documents/GitHub/MongoDB_Tortues
```

`make arreter` conserve les données, `make purger` efface les volumes.

---

## Ce que l'exécution a appris

| constat | où |
|---|---|
| `mongo:8.0` refuse de démarrer sur un noyau Linux ≥ 6.19 (SERVER-121912). Le contournement est `GLIBC_TUNABLES: glibc.pthread.rseq=1` dans l'environnement du service — le même que `MongoDB_ACID`. | `docker/docker-compose.yml` |
| `psql --quiet` ne tait pas les `NOTICE` d'un `DROP … IF EXISTS`. Il faut `PGOPTIONS=-c client_min_messages=warning`, ou le `SET` en tête du fichier. | `Makefile`, `sujets/*/schema.sql` |
| `pg_stat_user_tables.n_live_tup` est une estimation. Pour un compte exact et générique, `query_to_xml` sur un `count(*)` formaté. | `Makefile`, `sujets/relations.sql` |
| `mongosh` n'a pas de `cat()` comme l'ancien shell : pour lire un fichier depuis un script, c'est `require("fs").readFileSync`. Une variable declaree par `--eval 'const X = 1'` est bien visible du `--file` qui suit. | `sujets/verifier.js`, `Makefile` |
| `docker exec` **sans `-i`** ne transmet pas son entrée standard : le `cat > fichier` du bout de tuyau reçoit du vide, sans erreur. | `Makefile` |
| Les données du sujet 2 ne sont pas inventées : `generer.py` les lit dans `MongoDB_Tortues`, donc les étudiants retrouvent les tortues qu'ils ont déjà chargées pour la section « Indexing ». Les trous du jeu réel (une tortue sans habitat, deux jamais observées) sont conservés exprès. | `sujets/2-tortues/generer.py` |
