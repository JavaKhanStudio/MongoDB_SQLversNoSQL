-- =====================================================================
--  DB 2 — Les tortues : le projet fil rouge, remis au propre en SQL
-- =====================================================================
--  Le meme domaine que MongoDB_Tortues et Spring_MongoDB_VsSQL, mais
--  normalise : ce qui etait recopie dans le document est ici une table,
--  et ce qui etait une chaine libre est ici une cle etrangere.
--
--  Joue par  : make tortues
--  Relations : voir SUJET.md, section « Le schema et ses relations »
--
--  Treize tables, 46 colonnes. La normalisation multiplie les tables ;
--  on a donc coupe dans les colonnes, jusqu'a ce que chacune porte une
--  decision de modelisation et rien d'autre.
-- =====================================================================

SET client_min_messages = warning;   -- le DROP d'une table absente n'est pas une nouvelle

DROP TABLE IF EXISTS inscription CASCADE;
DROP TABLE IF EXISTS protocole CASCADE;
DROP TABLE IF EXISTS programme CASCADE;
DROP TABLE IF EXISTS observation CASCADE;
DROP TABLE IF EXISTS tortue_tag CASCADE;
DROP TABLE IF EXISTS tag CASCADE;
DROP TABLE IF EXISTS tortue CASCADE;
DROP TABLE IF EXISTS observateur CASCADE;
DROP TABLE IF EXISTS site CASCADE;
DROP TABLE IF EXISTS habitat CASCADE;
DROP TABLE IF EXISTS organisation CASCADE;
DROP TABLE IF EXISTS espece CASCADE;
DROP TABLE IF EXISTS pays CASCADE;

-- ---------------------------------------------------------------------
-- Les referentiels : ce qui etait une chaine recopiee partout
-- ---------------------------------------------------------------------

CREATE TABLE pays (
    id   SERIAL PRIMARY KEY,
    nom  TEXT NOT NULL UNIQUE
);

CREATE TABLE espece (
    id                SERIAL PRIMARY KEY,
    nom_scientifique  TEXT NOT NULL UNIQUE,
    nom_commun        TEXT NOT NULL,
    statut_uicn       TEXT NOT NULL CHECK (statut_uicn IN ('CR', 'EN', 'VU', 'NT', 'LC', 'DD'))
);

CREATE TABLE organisation (
    id       SERIAL PRIMARY KEY,
    nom      TEXT    NOT NULL UNIQUE,
    pays_id  INTEGER NOT NULL REFERENCES pays(id)
);

-- ---------------------------------------------------------------------
-- Le territoire
-- ---------------------------------------------------------------------

CREATE TABLE habitat (
    id             SERIAL PRIMARY KEY,
    nom            TEXT    NOT NULL UNIQUE,
    aire_protegee  BOOLEAN NOT NULL
);

-- Un site d'observation appartient a un habitat. Deux sites d'un meme
-- habitat portent deux noms differents : c'est le grain fin du terrain.
CREATE TABLE site (
    id          SERIAL PRIMARY KEY,
    nom         TEXT    NOT NULL UNIQUE,
    habitat_id  INTEGER NOT NULL REFERENCES habitat(id)
);

CREATE TABLE observateur (
    id   SERIAL PRIMARY KEY,
    nom  TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- Les tortues
-- ---------------------------------------------------------------------
-- Les mensurations sont a plat dans la ligne : en SQL, une table 1:1 qui
-- ne porte que deux mesures est du bruit. Cote document, la question se
-- repose autrement.

CREATE TABLE tortue (
    id                    SERIAL PRIMARY KEY,
    nom                   TEXT    NOT NULL,
    espece_id             INTEGER NOT NULL REFERENCES espece(id),
    habitat_id            INTEGER REFERENCES habitat(id),   -- NULL : habitat inconnu
    longueur_dossiere_cm  NUMERIC(5,1) NOT NULL,
    poids_kg              NUMERIC(6,1) NOT NULL
);

CREATE TABLE tag (
    id       SERIAL PRIMARY KEY,
    libelle  TEXT NOT NULL UNIQUE
);

-- Liaison PURE : deux cles, rien d'autre.
CREATE TABLE tortue_tag (
    tortue_id  INTEGER NOT NULL REFERENCES tortue(id),
    tag_id     INTEGER NOT NULL REFERENCES tag(id),
    PRIMARY KEY (tortue_id, tag_id)
);

-- Une tortue est vue trois fois, ou dix, ou jamais. La table grossit a
-- chaque campagne : c'est le cote non borne du schema.
CREATE TABLE observation (
    id              SERIAL PRIMARY KEY,
    tortue_id       INTEGER NOT NULL REFERENCES tortue(id),
    site_id         INTEGER NOT NULL REFERENCES site(id),
    observateur_id  INTEGER NOT NULL REFERENCES observateur(id),
    date_obs        DATE    NOT NULL,
    score_sante     INTEGER NOT NULL CHECK (score_sante BETWEEN 0 AND 10)
);

-- ---------------------------------------------------------------------
-- Les programmes de suivi
-- ---------------------------------------------------------------------

CREATE TABLE programme (
    id               SERIAL PRIMARY KEY,
    nom              TEXT    NOT NULL UNIQUE,
    acronyme         TEXT    NOT NULL UNIQUE,
    organisation_id  INTEGER NOT NULL REFERENCES organisation(id),
    annee_fin        INTEGER,                               -- NULL : sans terme
    statut           TEXT    NOT NULL CHECK (statut IN ('ACTIF', 'SUSPENDU', 'TERMINE')),
    espece_cible_id  INTEGER REFERENCES espece(id)          -- NULL : toutes especes
);

-- 1:1 avec programme : le protocole n'existe jamais seul, et ne se lit
-- jamais sans son programme. En SQL c'est une table de plus ; ailleurs ?
CREATE TABLE protocole (
    programme_id      INTEGER PRIMARY KEY REFERENCES programme(id),
    intervalle_jours  INTEGER NOT NULL,
    methode_marquage  TEXT    NOT NULL
);

-- Liaison M:N AVEC attribut : la date d'entree dans le programme. Ce
-- n'est plus un simple tableau d'identifiants.
CREATE TABLE inscription (
    tortue_id          INTEGER NOT NULL REFERENCES tortue(id),
    programme_id       INTEGER NOT NULL REFERENCES programme(id),
    date_inscription   DATE    NOT NULL,
    PRIMARY KEY (tortue_id, programme_id)
);

CREATE INDEX idx_observation_tortue ON observation(tortue_id);
CREATE INDEX idx_observation_site   ON observation(site_id);
CREATE INDEX idx_tortue_espece      ON tortue(espece_id);
CREATE INDEX idx_tortue_habitat     ON tortue(habitat_id);
