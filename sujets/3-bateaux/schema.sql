-- =====================================================================
--  DB 3 — Les bateaux : civils et militaires, les ports, les escales
-- =====================================================================
--  Le schema est bati autour d'un heritage : un bateau est CIVIL ou
--  MILITAIRE, et les deux ne portent pas les memes attributs. SQL le
--  modelise en trois tables (class-table inheritance) : la table mere
--  et une table par cas. Aucune requete ne lit un bateau sans savoir
--  d'avance dans quelle table fille aller chercher la suite.
--
--  Joue par  : make bateaux
--  Relations : voir SUJET.md, section « Le schema et ses relations »
--
--  Douze tables, 47 colonnes. Les referentiels sont reduits a l'os :
--  ce qui reste est ce sur quoi une decision de modelisation porte.
-- =====================================================================

SET client_min_messages = warning;   -- le DROP d'une table absente n'est pas une nouvelle

DROP TABLE IF EXISTS cargaison CASCADE;
DROP TABLE IF EXISTS escale CASCADE;
DROP TABLE IF EXISTS affectation CASCADE;
DROP TABLE IF EXISTS capitaine CASCADE;
DROP TABLE IF EXISTS bateau_militaire CASCADE;
DROP TABLE IF EXISTS bateau_civil CASCADE;
DROP TABLE IF EXISTS bateau CASCADE;
DROP TABLE IF EXISTS marine CASCADE;
DROP TABLE IF EXISTS armateur CASCADE;
DROP TABLE IF EXISTS quai CASCADE;
DROP TABLE IF EXISTS port CASCADE;
DROP TABLE IF EXISTS pays CASCADE;

-- ---------------------------------------------------------------------
-- Les pays et les ports
-- ---------------------------------------------------------------------

CREATE TABLE pays (
    id   SERIAL PRIMARY KEY,
    nom  TEXT NOT NULL UNIQUE
);

CREATE TABLE port (
    id                SERIAL PRIMARY KEY,
    nom               TEXT    NOT NULL UNIQUE,
    pays_id           INTEGER NOT NULL REFERENCES pays(id),
    tirant_eau_max_m  NUMERIC(4,1) NOT NULL
);

-- Un port a cinq quais et n'en aura pas cinquante : relation 1:N BORNEE.
CREATE TABLE quai (
    id       SERIAL PRIMARY KEY,
    port_id  INTEGER NOT NULL REFERENCES port(id),
    numero   TEXT    NOT NULL,
    UNIQUE (port_id, numero)
);

-- ---------------------------------------------------------------------
-- Qui arme le bateau : deux tables de meme forme, pour deux mondes
-- ---------------------------------------------------------------------
-- Elles ne portent qu'un nom, et c'est tout le probleme : deux tables
-- identiques qui existent uniquement parce qu'une cle etrangere doit
-- pointer sur une table et une seule.

CREATE TABLE armateur (
    id   SERIAL PRIMARY KEY,
    nom  TEXT NOT NULL UNIQUE
);

CREATE TABLE marine (
    id   SERIAL PRIMARY KEY,
    nom  TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- L'heritage : une table mere, deux tables filles
-- ---------------------------------------------------------------------
-- bateau.categorie dit laquelle des deux filles porte la suite. La base
-- ne sait PAS l'imposer : rien n'empeche un bateau CIVIL d'avoir une
-- ligne dans bateau_militaire, ni un bateau de n'en avoir aucune.
-- C'est la faiblesse exacte que le modele document fait disparaitre.

CREATE TABLE bateau (
    id               SERIAL PRIMARY KEY,
    nom              TEXT    NOT NULL,
    imo              TEXT    NOT NULL UNIQUE,   -- ne change jamais, lui
    categorie        TEXT    NOT NULL CHECK (categorie IN ('CIVIL', 'MILITAIRE')),
    pavillon_id      INTEGER NOT NULL REFERENCES pays(id),
    tirant_eau_m     NUMERIC(4,1) NOT NULL,
    port_attache_id  INTEGER REFERENCES port(id)      -- NULL : sans port d'attache
);

CREATE TABLE bateau_civil (
    bateau_id        INTEGER PRIMARY KEY REFERENCES bateau(id),
    armateur_id      INTEGER NOT NULL REFERENCES armateur(id),
    type_civil       TEXT    NOT NULL CHECK (type_civil IN ('PORTE-CONTENEURS', 'VRAQUIER',
                                                            'PETROLIER', 'FERRY', 'CABLIER')),
    capacite_evp     INTEGER,                      -- NULL hors porte-conteneurs
    port_en_lourd_t  INTEGER NOT NULL
);

CREATE TABLE bateau_militaire (
    bateau_id             INTEGER PRIMARY KEY REFERENCES bateau(id),
    marine_id             INTEGER NOT NULL REFERENCES marine(id),
    classe                TEXT    NOT NULL,
    equipage              INTEGER NOT NULL,
    propulsion_nucleaire  BOOLEAN NOT NULL
);

-- ---------------------------------------------------------------------
-- Les hommes
-- ---------------------------------------------------------------------

CREATE TABLE capitaine (
    id      SERIAL PRIMARY KEY,
    nom     TEXT NOT NULL,
    brevet  TEXT NOT NULL CHECK (brevet IN ('CAPITAINE 3000', 'CAPITAINE ILLIMITE',
                                            'OFFICIER DE MARINE'))
);

-- M:N historicisee : un capitaine a commande plusieurs bateaux, un bateau
-- a eu plusieurs capitaines, et chaque paire porte ses dates.
-- fin NULL = affectation en cours.
CREATE TABLE affectation (
    capitaine_id  INTEGER NOT NULL REFERENCES capitaine(id),
    bateau_id     INTEGER NOT NULL REFERENCES bateau(id),
    debut         DATE    NOT NULL,
    fin           DATE,
    PRIMARY KEY (capitaine_id, bateau_id, debut),
    CHECK (fin IS NULL OR fin > debut)
);

-- ---------------------------------------------------------------------
-- Le journal des escales
-- ---------------------------------------------------------------------
-- Une escale par passage, pour toujours : 1:N NON BORNE cote bateau
-- comme cote quai. Une escale de ravitaillement militaire ne porte
-- aucune cargaison ; une escale de commerce en porte trois ou quatre.

CREATE TABLE escale (
    id         SERIAL PRIMARY KEY,
    bateau_id  INTEGER   NOT NULL REFERENCES bateau(id),
    quai_id    INTEGER   NOT NULL REFERENCES quai(id),
    arrivee    TIMESTAMP NOT NULL,
    depart     TIMESTAMP,                     -- NULL : le bateau est encore a quai
    motif      TEXT      NOT NULL CHECK (motif IN ('COMMERCE', 'RAVITAILLEMENT',
                                                   'REPARATION', 'DIPLOMATIQUE')),
    CHECK (depart IS NULL OR depart > arrivee)
);

CREATE TABLE cargaison (
    id           SERIAL PRIMARY KEY,
    escale_id    INTEGER NOT NULL REFERENCES escale(id),
    marchandise  TEXT    NOT NULL,
    tonnes       NUMERIC(8,1) NOT NULL
);

CREATE INDEX idx_escale_bateau ON escale(bateau_id, arrivee);
CREATE INDEX idx_escale_quai   ON escale(quai_id);
CREATE INDEX idx_cargaison_esc ON cargaison(escale_id);
CREATE INDEX idx_quai_port     ON quai(port_id);
