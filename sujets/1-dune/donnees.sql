-- =====================================================================
--  DB 1 — « Dune » : le jeu de donnees
--  Petit, mais choisi pour que les requetes TRIENT : dans chaque table il
--  y a des lignes qui sortent, des lignes qui ne sortent pas, et au moins
--  une a la frontiere.
-- =====================================================================

TRUNCATE compatibilite, releve_vibration, collecte, contremaitre,
         plateforme_transport, plateforme_minage, puits, ver, region
         RESTART IDENTITY CASCADE;

-- ------------------------------------------------------------ regions
INSERT INTO region (id, nom, hemisphere, indice_tempete) VALUES
 (1, 'Bassin de Tuono',    'NORD', 3.5),
 (2, 'Erg Habbanya',       'SUD',  8.2),
 (3, 'Plaine Funeste',     'NORD', 6.0),
 (4, 'Depression de Tabr', 'SUD',  2.0),
 (5, 'Muraille-Bouclier',  'NORD', 9.4);

-- --------------------------------------------------------------- vers
INSERT INTO ver (id, nom, region_id, statut) VALUES
 (1, 'Shai-Hulud le Vieux', 2, 'ACTIF'),
 (2, 'Gueule de Coriolis',  2, 'ACTIF'),
 (3, 'Le Silencieux',       5, 'DORMANT'),
 (4, 'Briseur de Dunes',    3, 'ACTIF'),
 (5, 'Fils du Sable',       3, 'DORMANT'),
 (6, 'Le Boiteux',          1, 'ABATTU'),
 (7, 'Ombre de Tabr',       4, 'DORMANT');

-- -------------------------------------------------------------- puits
INSERT INTO puits (id, code, region_id, epuise) VALUES
 ( 1, 'TUO-01', 1, FALSE),
 ( 2, 'TUO-02', 1, FALSE),
 ( 3, 'HAB-01', 2, FALSE),
 ( 4, 'HAB-02', 2, FALSE),
 ( 5, 'HAB-03', 2, TRUE),
 ( 6, 'FUN-01', 3, FALSE),
 ( 7, 'FUN-02', 3, FALSE),
 ( 8, 'TAB-01', 4, TRUE),
 ( 9, 'MUR-01', 5, FALSE),
 (10, 'MUR-02', 5, FALSE);

-- ------------------------------------------------------- plateformes
INSERT INTO plateforme_minage (id, matricule, modele) VALUES
 (1, 'PM-1140', 'Moissonneuse Harkonnen Mk IV'),
 (2, 'PM-1207', 'Moissonneuse Harkonnen Mk IV'),
 (3, 'PM-0885', 'Moissonneuse Atreides Delta'),
 (4, 'PM-0902', 'Moissonneuse Atreides Delta'),
 (5, 'PM-0417', 'Foreuse legere Guilde'),
 (6, 'PM-1533', 'Moissonneuse Harkonnen Mk V');

INSERT INTO plateforme_transport (id, matricule, modele) VALUES
 (1, 'PT-2001', 'Porteuse lourde Orni-9'),
 (2, 'PT-2014', 'Porteuse lourde Orni-9'),
 (3, 'PT-1802', 'Porteuse Orni-6'),
 (4, 'PT-1811', 'Porteuse Orni-6'),
 (5, 'PT-0930', 'Aile de secours Guilde');

-- Compatibilites : un porteur ne souleve que ce qu'il peut porter.
INSERT INTO compatibilite (plateforme_minage_id, plateforme_transport_id) VALUES
 (1, 1), (1, 2),
 (2, 1), (2, 2),
 (3, 3), (3, 4),
 (4, 4), (4, 3),
 (5, 5),
 (6, 2), (6, 1);

-- ------------------------------------------------------ contremaitres
INSERT INTO contremaitre (id, nom, maison, anciennete_annees) VALUES
 (1, 'Gurney Halleck',   'Atreides',  22),
 (2, 'Rabban Harkonnen', 'Harkonnen', 15),
 (3, 'Stilgar',          'Fremen',    30),
 (4, 'Duncan Idaho',     'Atreides',   9),
 (5, 'Piter de Vries',   'Harkonnen',  6),
 (6, 'Chani',            'Fremen',     4);

-- ----------------------------------------------------------- collectes
-- 18 reussies, 12 echouees. Noter, dans chaque ligne, le nombre de NULL.
INSERT INTO collecte (id, puits_id, plateforme_minage_id, plateforme_transport_id,
                      contremaitre_id, debut, statut,
                      tonnes_epice, purete_pct, duree_minutes,
                      cause, ver_id, materiel_perdu, pertes_humaines) VALUES
 (1,  3, 1, 1, 2, TIMESTAMP '2026-06-02 05:10', 'REUSSIE', 298.40, 93.5, 210, NULL, NULL, NULL, NULL),
 (2,  3, 2, 1, 6, TIMESTAMP '2026-06-04 04:55', 'REUSSIE', 312.00, 94.8, 195, NULL, NULL, NULL, NULL),
 (3,  4, 1, 2, 2, TIMESTAMP '2026-06-07 06:20', 'ECHOUEE', NULL, NULL, NULL, 'VER', 1, TRUE,  3),
 (4,  4, 2, 1, 6, TIMESTAMP '2026-06-09 05:05', 'REUSSIE', 320.00, 97.1, 240, NULL, NULL, NULL, NULL),
 (5,  1, 3, 3, 1, TIMESTAMP '2026-06-11 07:40', 'REUSSIE', 164.25, 61.0, 150, NULL, NULL, NULL, NULL),
 (6,  1, 3, 3, 1, TIMESTAMP '2026-06-15 07:30', 'ECHOUEE', NULL, NULL, NULL, 'PANNE', NULL, FALSE, 0),
 (7,  2, 3, 3, 1, TIMESTAMP '2026-06-18 08:00', 'REUSSIE', 178.00, 72.4, 165, NULL, NULL, NULL, NULL),
 (8,  6, 4, 4, 4, TIMESTAMP '2026-06-21 06:45', 'REUSSIE', 171.50, 69.8, 180, NULL, NULL, NULL, NULL),
 (9,  6, 4, 4, 4, TIMESTAMP '2026-06-24 06:50', 'ECHOUEE', NULL, NULL, NULL, 'TEMPETE', NULL, TRUE, 1),
 (10, 7, 4, 3, 4, TIMESTAMP '2026-06-27 07:15', 'REUSSIE', 155.00, 57.2, 200, NULL, NULL, NULL, NULL),
 (11, 9, 6, 2, 5, TIMESTAMP '2026-07-01 05:30', 'REUSSIE', 402.60, 84.0, 260, NULL, NULL, NULL, NULL),
 (12, 9, 6, 2, 5, TIMESTAMP '2026-07-05 05:25', 'ECHOUEE', NULL, NULL, NULL, 'TEMPETE', NULL, FALSE, 0),
 (13,10, 6, 1, 5, TIMESTAMP '2026-07-08 05:40', 'REUSSIE', 410.00, 91.6, 275, NULL, NULL, NULL, NULL),
 (14, 3, 1, 1, 2, TIMESTAMP '2026-07-12 04:45', 'ECHOUEE', NULL, NULL, NULL, 'VER', 2, TRUE,  5),
 (15, 3, 2, 2, 6, TIMESTAMP '2026-07-14 04:50', 'REUSSIE', 305.75, 92.0, 205, NULL, NULL, NULL, NULL),
 (16, 4, 1, 1, 2, TIMESTAMP '2026-07-17 06:00', 'REUSSIE', 319.90, 96.9, 230, NULL, NULL, NULL, NULL),
 (17, 4, 2, 2, 6, TIMESTAMP '2026-07-20 05:55', 'ECHOUEE', NULL, NULL, NULL, 'EMBUSCADE', NULL, TRUE, 8),
 (18, 1, 3, 4, 1, TIMESTAMP '2026-07-23 08:10', 'REUSSIE', 160.00, 60.5, 145, NULL, NULL, NULL, NULL),
 (19, 2, 3, 3, 1, TIMESTAMP '2026-07-26 07:50', 'REUSSIE', 180.00, 71.9, 170, NULL, NULL, NULL, NULL),
 (20, 6, 4, 4, 4, TIMESTAMP '2026-07-29 06:35', 'ECHOUEE', NULL, NULL, NULL, 'VER', 4, FALSE, 2),
 (21, 7, 4, 4, 4, TIMESTAMP '2026-08-02 07:05', 'REUSSIE', 149.00, 55.0, 190, NULL, NULL, NULL, NULL),
 (22, 9, 6, 2, 5, TIMESTAMP '2026-08-05 05:20', 'REUSSIE', 398.10, 82.7, 255, NULL, NULL, NULL, NULL),
 (23,10, 6, 2, 5, TIMESTAMP '2026-08-09 05:15', 'ECHOUEE', NULL, NULL, NULL, 'PANNE', NULL, TRUE, 0),
 (24, 3, 1, 1, 6, TIMESTAMP '2026-08-12 04:40', 'REUSSIE', 289.30, 91.2, 215, NULL, NULL, NULL, NULL),
 (25, 4, 2, 1, 2, TIMESTAMP '2026-08-15 06:10', 'ECHOUEE', NULL, NULL, NULL, 'VER', 1, TRUE, 11),
 (26, 1, 3, 3, 1, TIMESTAMP '2026-08-18 08:20', 'REUSSIE', 158.80, 59.4, 155, NULL, NULL, NULL, NULL),
 (27, 6, 4, 3, 4, TIMESTAMP '2026-08-21 06:55', 'REUSSIE', 174.60, 70.1, 175, NULL, NULL, NULL, NULL),
 (28, 7, 4, 4, 4, TIMESTAMP '2026-08-25 07:25', 'ECHOUEE', NULL, NULL, NULL, 'TEMPETE', NULL, FALSE, 0),
 (29,10, 6, 1, 5, TIMESTAMP '2026-08-28 05:35', 'REUSSIE', 415.20, 90.4, 280, NULL, NULL, NULL, NULL),
 (30, 2, 3, 4, 1, TIMESTAMP '2026-08-31 07:45', 'ECHOUEE', NULL, NULL, NULL, 'EMBUSCADE', NULL, FALSE, 2);

-- ----------------------------------------------------- releves de capteurs
-- Extrait : 3 jours sur les puits actifs. En production, une ligne par heure
-- et par puits, pour toujours.
INSERT INTO releve_vibration (puits_id, mesure_le, amplitude) VALUES
 ( 3, TIMESTAMP '2026-09-01 00:00', 1.20),
 ( 3, TIMESTAMP '2026-09-01 06:00', 2.85),
 ( 3, TIMESTAMP '2026-09-01 12:00', 7.40),
 ( 3, TIMESTAMP '2026-09-01 18:00', 3.10),
 ( 3, TIMESTAMP '2026-09-02 00:00', 1.05),
 ( 3, TIMESTAMP '2026-09-02 06:00', 6.90),
 ( 3, TIMESTAMP '2026-09-02 12:00', 2.20),
 ( 3, TIMESTAMP '2026-09-02 18:00', 1.80),
 ( 4, TIMESTAMP '2026-09-01 00:00', 0.90),
 ( 4, TIMESTAMP '2026-09-01 06:00', 1.40),
 ( 4, TIMESTAMP '2026-09-01 12:00', 8.75),
 ( 4, TIMESTAMP '2026-09-01 18:00', 4.60),
 ( 4, TIMESTAMP '2026-09-02 00:00', 1.10),
 ( 4, TIMESTAMP '2026-09-02 06:00', 2.05),
 ( 1, TIMESTAMP '2026-09-01 00:00', 0.40),
 ( 1, TIMESTAMP '2026-09-01 06:00', 0.85),
 ( 1, TIMESTAMP '2026-09-01 12:00', 1.15),
 ( 1, TIMESTAMP '2026-09-01 18:00', 0.60),
 ( 2, TIMESTAMP '2026-09-01 06:00', 1.90),
 ( 2, TIMESTAMP '2026-09-01 12:00', 2.40),
 ( 6, TIMESTAMP '2026-09-01 06:00', 3.30),
 ( 6, TIMESTAMP '2026-09-01 12:00', 5.55),
 ( 6, TIMESTAMP '2026-09-01 18:00', 2.10),
 ( 7, TIMESTAMP '2026-09-01 12:00', 1.70),
 ( 9, TIMESTAMP '2026-09-01 06:00', 4.20),
 ( 9, TIMESTAMP '2026-09-01 12:00', 9.10),
 ( 9, TIMESTAMP '2026-09-01 18:00', 5.05),
 (10, TIMESTAMP '2026-09-01 06:00', 2.60),
 (10, TIMESTAMP '2026-09-01 12:00', 3.95),
 (10, TIMESTAMP '2026-09-02 06:00', 6.15);

SELECT setval('region_id_seq',               (SELECT MAX(id) FROM region));
SELECT setval('ver_id_seq',                  (SELECT MAX(id) FROM ver));
SELECT setval('puits_id_seq',                (SELECT MAX(id) FROM puits));
SELECT setval('plateforme_minage_id_seq',    (SELECT MAX(id) FROM plateforme_minage));
SELECT setval('plateforme_transport_id_seq', (SELECT MAX(id) FROM plateforme_transport));
SELECT setval('contremaitre_id_seq',         (SELECT MAX(id) FROM contremaitre));
SELECT setval('collecte_id_seq',             (SELECT MAX(id) FROM collecte));
