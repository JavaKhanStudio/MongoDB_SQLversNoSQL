# =====================================================================
#  SQL vers NoSQL — les trois sujets, presentes et testables d'ici.
#  make aide
# =====================================================================
# Sous Podman rootless (Fedora), avant tout :
#   export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock

COMPOSE = docker compose -f docker/docker-compose.yml
PSQL    = docker exec -i  sqlnosql-postgres psql -U postgres -v ON_ERROR_STOP=1 --quiet
PSQLI   = docker exec -it sqlnosql-postgres psql -U postgres
MONGOSH = docker exec -it sqlnosql-mongo mongosh --quiet
MONGO   = docker exec    sqlnosql-mongo
MONGOI  = docker exec -i sqlnosql-mongo

# make <sujet>-verifier CASSE=1 : casse volontairement un document, pour
# voir le verificateur mordre.
CASSE  ?= 0

.PHONY: aide demarrer arreter purger etat sujets tout mongo \
        dune dune-sql dune-schema dune-controle dune-verifier \
        tortues tortues-sql tortues-schema tortues-controle tortues-verifier \
        bateaux bateaux-sql bateaux-schema bateaux-controle bateaux-verifier

aide:
	@echo ""
	@echo "  Mise en route"
	@echo "    make demarrer          - lance PostgreSQL (55432) et MongoDB (27041)"
	@echo "    make sujets            - les trois sujets, en une page"
	@echo "    make tout              - charge les trois bases SQL"
	@echo ""
	@echo "  Un sujet   (<s> = dune | tortues | bateaux)"
	@echo "    make <s>               - (re)cree la base SQL et la remplit"
	@echo "    make <s>-schema        - les tables, leurs colonnes, leurs relations"
	@echo "    make <s>-controle      - les chiffres de reference a retrouver en Mongo"
	@echo "    make <s>-sql           - un psql sur la base"
	@echo ""
	@echo "  Cote MongoDB"
	@echo "    make mongo             - un mongosh sur le serveur d'arrivee"
	@echo ""
	@echo "  La correction vit sur une branche a elle, « correction »,"
	@echo "  et on va l'y chercher a la main."
	@echo "    git switch correction  - puis make <s>-verifier : charge le modele"
	@echo "                             document de reference dans <s>_correction,"
	@echo "                             repose les six questions, et dit OK ou KO"
	@echo "                             ligne par ligne (CASSE=1 abime un document,"
	@echo "                             pour voir le KO)"
	@echo "    git switch main        - revenir au sujet seul"
	@echo ""
	@echo "    make etat              - les deux serveurs repondent-ils"
	@echo "    make arreter           - arrete, conserve les donnees"
	@echo "    make purger            - arrete et EFFACE les volumes"
	@echo ""
	@echo "  L'enonce de chaque sujet : sujets/1-dune/SUJET.md, 2-tortues, 3-bateaux"
	@echo ""

demarrer:
	$(COMPOSE) up -d
	@echo "  attente des serveurs..."
	@for i in $$(seq 1 60); do \
	  docker exec sqlnosql-postgres pg_isready -U postgres > /dev/null 2>&1 && break; sleep 1; done
	@for i in $$(seq 1 60); do \
	  docker exec sqlnosql-mongo mongosh --quiet --eval 'db.runCommand({ping:1})' > /dev/null 2>&1 && break; sleep 1; done
	@$(MAKE) --no-print-directory etat

etat:
	@docker exec sqlnosql-postgres psql -U postgres --quiet -tAc \
	  "select '  PostgreSQL  ' || version()" 2>/dev/null || echo "  PostgreSQL  ARRETE"
	@docker exec sqlnosql-mongo mongosh --quiet --eval \
	  'print("  MongoDB     " + db.version())' 2>/dev/null || echo "  MongoDB     ARRETE"

sujets:
	@cat sujets/SUJETS.txt

tout: dune tortues bateaux

mongo:
	$(MONGOSH)

# --------------------------------------------------------------------
# Un sujet se charge toujours de la meme facon : on jette la base et on
# la refait. Recommencer autant de fois qu'on veut, dans n'importe quel
# ordre, sans rien casser chez le voisin.
# --------------------------------------------------------------------

define CHARGER
	@docker exec -e PGOPTIONS=-c\ client_min_messages=warning sqlnosql-postgres \
	  psql -U postgres --quiet -c "DROP DATABASE IF EXISTS $(1)" > /dev/null
	@docker exec sqlnosql-postgres psql -U postgres --quiet -c "CREATE DATABASE $(1)" > /dev/null
	@$(PSQL) -d $(1) -f /projet/sujets/$(2)/schema.sql  > /dev/null
	@$(PSQL) -d $(1) -f /projet/sujets/$(2)/donnees.sql > /dev/null
	@echo "  base $(1) rechargee :"
	@$(PSQL) -d $(1) -tAc "select '    ' || rpad(c.relname, 24) || lpad(x.n::text, 6) || ' lignes' \
	    from pg_class c join pg_namespace s on s.oid = c.relnamespace \
	    cross join lateral (select (xpath('/row/c/text()', q))[1]::text::bigint as n \
	      from query_to_xml(format('select count(*) as c from %I.%I', s.nspname, c.relname), \
	                        false, true, '') as q) x \
	    where s.nspname = 'public' and c.relkind = 'r' order by c.relname"
	@echo ""
	@echo "  l'enonce : sujets/$(2)/SUJET.md      les chiffres : make $(1)-controle"
endef

dune:          ; $(call CHARGER,dune,1-dune)
tortues:       ; $(call CHARGER,tortues,2-tortues)
bateaux:       ; $(call CHARGER,bateaux,3-bateaux)

dune-sql:      ; $(PSQLI) -d dune
tortues-sql:   ; $(PSQLI) -d tortues
bateaux-sql:   ; $(PSQLI) -d bateaux

dune-schema:    ; @$(PSQL) -d dune    -f /projet/sujets/relations.sql
tortues-schema: ; @$(PSQL) -d tortues -f /projet/sujets/relations.sql
bateaux-schema: ; @$(PSQL) -d bateaux -f /projet/sujets/relations.sql

dune-controle:    ; @$(PSQL) -d dune    -f /projet/sujets/1-dune/controle.sql
tortues-controle: ; @$(PSQL) -d tortues -f /projet/sujets/2-tortues/controle.sql
bateaux-controle: ; @$(PSQL) -d bateaux -f /projet/sujets/3-bateaux/controle.sql

# --------------------------------------------------------------------
# La correction. Elle ne vit que sur la branche « correction » : sur main,
# les cinq fichiers qu'elle demande n'existent pas et les cibles ci-dessous
# disent ou aller. Le Makefile, lui, est le meme sur les deux branches —
# il ne se corrige qu'une fois.
#
# On ne compare pas deux modeles — un modele document est
# un choix — on compare les REPONSES. Le verificateur prend donc la base
# SQL telle quelle, la donne a correction.js qui en fait des documents,
# et confronte ses six blocs a ce que controle.sql vient d'imprimer.
# Rien n'est recopie a la main : l'attendu est produit a chaque passage.
# --------------------------------------------------------------------

define VERIFIER
	@test -f sujets/$(2)/correction.js || { \
	  echo ""; \
	  echo "  La correction n'est pas sur cette branche."; \
	  echo "  Elle vit sur la branche « correction » :"; \
	  echo ""; \
	  echo "      git switch correction     puis   make $(1)-verifier"; \
	  echo "      git switch main           pour revenir au sujet seul"; \
	  echo ""; \
	  exit 1; }
	@$(PSQL) -d $(1) -f /projet/sujets/vers-json.sql \
	  | $(MONGOI) sh -c 'cat > /tmp/$(1)-tables.json'
	@$(PSQL) -d $(1) -f /projet/sujets/$(2)/controle.sql \
	  | $(MONGOI) sh -c 'cat > /tmp/$(1)-attendu.txt'
	@$(MONGO) mongosh --quiet --eval 'const CASSE = $(CASSE)' \
	  --file /projet/sujets/$(2)/correction.js
endef

dune-verifier:    ; $(call VERIFIER,dune,1-dune)
tortues-verifier: ; $(call VERIFIER,tortues,2-tortues)
bateaux-verifier: ; $(call VERIFIER,bateaux,3-bateaux)

arreter:
	$(COMPOSE) down

purger:
	$(COMPOSE) down -v
