-- =====================================================================
--  DB 1 — « Dune » : l'exploitation de l'epice sur Arrakis
--  Schema SQL de depart. C'est CE schema que l'on transforme en documents.
-- =====================================================================
--  Joue par  : make dune
--  Relations : voir SUJET.md, section « Le schema et ses relations »
--
--  Neuf tables, 42 colonnes. Tout ce qui n'etait que du decor a ete
--  retire : ce qui reste porte une decision de modelisation.
-- =====================================================================

SET client_min_messages = warning;   -- le DROP d'une table absente n'est pas une nouvelle

DROP TABLE IF EXISTS compatibilite CASCADE;
DROP TABLE IF EXISTS releve_vibration CASCADE;
DROP TABLE IF EXISTS collecte CASCADE;
DROP TABLE IF EXISTS contremaitre CASCADE;
DROP TABLE IF EXISTS plateforme_transport CASCADE;
DROP TABLE IF EXISTS plateforme_minage CASCADE;
DROP TABLE IF EXISTS puits CASCADE;
DROP TABLE IF EXISTS ver CASCADE;
DROP TABLE IF EXISTS region CASCADE;

-- ---------------------------------------------------------------------
-- Le territoire
-- ---------------------------------------------------------------------

CREATE TABLE region (
    id              SERIAL PRIMARY KEY,
    nom             TEXT    NOT NULL UNIQUE,
    hemisphere      TEXT    NOT NULL CHECK (hemisphere IN ('NORD', 'SUD')),
    indice_tempete  NUMERIC(3,1) NOT NULL   -- 0.0 (calme) a 10.0 (Coriolis permanent)
);

-- Un ver appartient a une region : c'est son territoire de chasse.
CREATE TABLE ver (
    id         SERIAL PRIMARY KEY,
    nom        TEXT    NOT NULL,
    region_id  INTEGER NOT NULL REFERENCES region(id),
    statut     TEXT    NOT NULL CHECK (statut IN ('ACTIF', 'DORMANT', 'ABATTU'))
);

-- Un puits d'epice est fore dans une region.
CREATE TABLE puits (
    id         SERIAL PRIMARY KEY,
    code       TEXT    NOT NULL UNIQUE,
    region_id  INTEGER NOT NULL REFERENCES region(id),
    epuise     BOOLEAN NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------------
-- Le materiel et les hommes
-- ---------------------------------------------------------------------
-- Les plateformes ne sont PAS rattachees a une region : elles se deplacent,
-- et c'est la collecte qui dit ou elles sont descendues ce jour-la.

CREATE TABLE plateforme_minage (
    id         SERIAL PRIMARY KEY,
    matricule  TEXT NOT NULL UNIQUE,
    modele     TEXT NOT NULL
);

CREATE TABLE plateforme_transport (
    id         SERIAL PRIMARY KEY,
    matricule  TEXT NOT NULL UNIQUE,
    modele     TEXT NOT NULL
);

-- Quel porteur peut soulever quelle plateforme de minage.
-- Table de liaison PURE : deux cles etrangeres, aucune colonne a elle.
CREATE TABLE compatibilite (
    plateforme_minage_id     INTEGER NOT NULL REFERENCES plateforme_minage(id),
    plateforme_transport_id  INTEGER NOT NULL REFERENCES plateforme_transport(id),
    PRIMARY KEY (plateforme_minage_id, plateforme_transport_id)
);

-- Un contremaitre n'a pas de region attitree : il est attache a la COLLECTE.
CREATE TABLE contremaitre (
    id                 SERIAL PRIMARY KEY,
    nom                TEXT    NOT NULL,
    maison             TEXT    NOT NULL,     -- Atreides, Harkonnen, Fremen, Guilde
    anciennete_annees  INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- Le journal des collectes
-- ---------------------------------------------------------------------
-- Une collecte REUSSIE et une collecte ECHOUEE ne portent PAS les memes
-- informations. En SQL elles partagent pourtant la meme table, donc les
-- memes colonnes : celles de l'autre cas restent NULL, ligne apres ligne.
-- Les deux CHECK ci-dessous sont la pour que ce soit visible — ils disent
-- noir sur blanc quelles colonnes n'ont de sens que d'un cote.
-- C'est la table la plus large du sujet, et c'est voulu : elle porte a
-- elle seule un tiers des colonnes de la base.

CREATE TABLE collecte (
    id                       SERIAL PRIMARY KEY,
    puits_id                 INTEGER   NOT NULL REFERENCES puits(id),
    plateforme_minage_id     INTEGER   NOT NULL REFERENCES plateforme_minage(id),
    plateforme_transport_id  INTEGER   NOT NULL REFERENCES plateforme_transport(id),
    contremaitre_id          INTEGER   NOT NULL REFERENCES contremaitre(id),
    debut                    TIMESTAMP NOT NULL,
    statut                   TEXT      NOT NULL CHECK (statut IN ('REUSSIE', 'ECHOUEE')),

    -- colonnes de la REUSSITE seule
    tonnes_epice             NUMERIC(6,2),
    purete_pct               NUMERIC(4,1),
    duree_minutes            INTEGER,

    -- colonnes de l'ECHEC seul
    cause                    TEXT CHECK (cause IN ('VER', 'PANNE', 'TEMPETE', 'EMBUSCADE')),
    ver_id                   INTEGER REFERENCES ver(id),
    materiel_perdu           BOOLEAN,
    pertes_humaines          INTEGER,

    CONSTRAINT reussie_complete CHECK (
        statut <> 'REUSSIE' OR (
            tonnes_epice IS NOT NULL AND purete_pct IS NOT NULL AND duree_minutes IS NOT NULL
            AND cause IS NULL AND ver_id IS NULL
            AND materiel_perdu IS NULL AND pertes_humaines IS NULL)),

    CONSTRAINT echouee_complete CHECK (
        statut <> 'ECHOUEE' OR (
            cause IS NOT NULL AND materiel_perdu IS NOT NULL AND pertes_humaines IS NOT NULL
            AND tonnes_epice IS NULL AND purete_pct IS NULL AND duree_minutes IS NULL)),

    -- ver_id n'a de sens que si la cause est le ver
    CONSTRAINT ver_si_cause_ver CHECK (cause = 'VER' OR ver_id IS NULL)
);

-- Les capteurs poses au bord de chaque puits. Une ligne toutes les heures,
-- pour toujours : cette table grossit sans limite.
CREATE TABLE releve_vibration (
    id          SERIAL PRIMARY KEY,
    puits_id    INTEGER   NOT NULL REFERENCES puits(id),
    mesure_le   TIMESTAMP NOT NULL,
    amplitude   NUMERIC(5,2) NOT NULL
);

CREATE INDEX idx_collecte_puits   ON collecte(puits_id);
CREATE INDEX idx_collecte_statut  ON collecte(statut);
CREATE INDEX idx_releve_puits     ON releve_vibration(puits_id, mesure_le);
