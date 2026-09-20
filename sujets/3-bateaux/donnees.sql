-- =====================================================================
--  DB 3 — Les bateaux : le jeu de donnees
--  Choisi pour que les requetes TRIENT : dans chaque classement il y a
--  des lignes qui sortent, des lignes qui ne sortent pas, et au moins
--  une a la frontiere. Noms de bateaux et d'armateurs inventes ; ports,
--  coordonnees et classes de navires plausibles.
-- =====================================================================

TRUNCATE cargaison, escale, affectation, capitaine, bateau_militaire,
         bateau_civil, bateau, marine, armateur, quai, port, pays
         RESTART IDENTITY CASCADE;

-- --------------------------------------------------------------- pays
INSERT INTO pays (id, nom) VALUES
 (1, 'France'),
 (2, 'Pays-Bas'),
 (3, 'Singapour'),
 (4, 'Chine'),
 (5, 'Etats-Unis'),
 (6, 'Djibouti'),
 (7, 'Panama');

-- -------------------------------------------------------------- ports
INSERT INTO port (id, nom, pays_id, tirant_eau_max_m) VALUES
 (1, 'Le Havre',  1, 16.0),
 (2, 'Rotterdam', 2, 24.0),
 (3, 'Singapour', 3, 20.0),
 (4, 'Shanghai',  4, 17.5),
 (5, 'Toulon',    1, 12.0),
 (6, 'Norfolk',   5, 14.0),
 (7, 'Djibouti',  6, 18.0),
 (8, 'Brest',     1, 11.0);

-- -------------------------------------------------------------- quais
INSERT INTO quai (id, port_id, numero) VALUES
 ( 1, 1, 'A1'),
 ( 2, 1, 'A2'),
 ( 3, 1, 'B1'),
 ( 4, 2, 'C1'),
 ( 5, 2, 'C2'),
 ( 6, 2, 'C3'),
 ( 7, 3, 'D1'),
 ( 8, 3, 'D2'),
 ( 9, 3, 'D3'),
 (10, 4, 'E1'),
 (11, 4, 'E2'),
 (12, 5, 'M1'),
 (13, 5, 'M2'),
 (14, 5, 'M3'),
 (15, 6, 'N1'),
 (16, 6, 'N2'),
 (17, 7, 'F1'),
 (18, 7, 'F2'),
 (19, 8, 'G1'),
 (20, 8, 'G2');

-- --------------------------------------------------- armateurs, marines
INSERT INTO armateur (id, nom) VALUES
 (1, 'Compagnie Havraise'),
 (2, 'Delta Maritime'),
 (3, 'Straits Lines'),
 (4, 'Yangtze Freight'),
 (5, 'Ocean Cablier');

INSERT INTO marine (id, nom) VALUES
 (1, 'Marine nationale'),
 (2, 'US Navy'),
 (3, 'Marine de la RPC'),
 (4, 'Koninklijke Marine');

-- ------------------------------------------------------------ bateaux
INSERT INTO bateau (id, nom, imo, categorie, pavillon_id, tirant_eau_m, port_attache_id) VALUES
 ( 1, 'Etoile de Brest',  'IMO9412345', 'CIVIL',     1, 13.5,    1),
 ( 2, 'Kerguelen Trader', 'IMO9455121', 'CIVIL',     1, 10.2,    1),
 ( 3, 'Delta Amstel',     'IMO9500233', 'CIVIL',     2, 15.2,    2),
 ( 4, 'Delta Maas',       'IMO9500234', 'CIVIL',     2, 16.0,    2),
 ( 5, 'Straits Pioneer',  'IMO9611002', 'CIVIL',     3, 14.5,    3),
 ( 6, 'Straits Meridian', 'IMO9611003', 'CIVIL',     3, 11.0,    3),
 ( 7, 'Yangtze Star',     'IMO9722441', 'CIVIL',     4, 16.5,    4),
 ( 8, 'Yangtze Ember',    'IMO9722442', 'CIVIL',     4, 12.8,    4),
 ( 9, 'Petrel du Nord',   'IMO9388771', 'CIVIL',     7, 14.0, NULL),
 (10, 'Cablier Aurore',   'IMO9199887', 'CIVIL',     1,  8.0,    8),
 (11, 'Ouragan',          'IMO4501001', 'MILITAIRE', 1,  6.5,    5),
 (12, 'Vigilante',        'IMO4501002', 'MILITAIRE', 1,  5.4,    5),
 (13, 'Sillage',          'IMO4501003', 'MILITAIRE', 1,  4.2,    8),
 (14, 'Endeavour Point',  'IMO4602001', 'MILITAIRE', 5, 12.0,    6),
 (15, 'Chesapeake',       'IMO4602002', 'MILITAIRE', 5,  6.8,    6),
 (16, 'Long March Tide',  'IMO4703001', 'MILITAIRE', 4,  6.0, NULL),
 (17, 'Zeeland',          'IMO4804001', 'MILITAIRE', 2,  5.6, NULL),
 (18, 'Lame de Fond',     'IMO4501004', 'MILITAIRE', 1,  9.5,    5);

INSERT INTO bateau_civil (bateau_id, armateur_id, type_civil, capacite_evp, port_en_lourd_t) VALUES
 ( 1, 1, 'PORTE-CONTENEURS',  5100,  78000),
 ( 2, 1, 'VRAQUIER',          NULL,  52000),
 ( 3, 2, 'PORTE-CONTENEURS', 13800, 142000),
 ( 4, 2, 'PORTE-CONTENEURS', 21400, 199000),
 ( 5, 3, 'PORTE-CONTENEURS',  9600, 111000),
 ( 6, 3, 'FERRY',             NULL,  12000),
 ( 7, 4, 'PORTE-CONTENEURS', 23000, 224000),
 ( 8, 4, 'VRAQUIER',          NULL,  88000),
 ( 9, 2, 'PETROLIER',         NULL, 164000),
 (10, 5, 'CABLIER',           NULL,   9000);

INSERT INTO bateau_militaire (bateau_id, marine_id, classe, equipage, propulsion_nucleaire) VALUES
 (11, 1, 'Classe Mistral',   180, FALSE),
 (12, 1, 'Classe Floreal',    95, FALSE),
 (13, 1, 'Classe Adroit',     32, FALSE),
 (14, 2, 'Nimitz class',    3200, TRUE),
 (15, 2, 'Freedom class',     75, FALSE),
 (16, 3, 'Type 054A',        165, FALSE),
 (17, 4, 'Classe De Zeven',  202, FALSE),
 (18, 1, 'Classe Suffren',    65, TRUE);

-- --------------------------------------------------------- capitaines
INSERT INTO capitaine (id, nom, brevet) VALUES
 (1, 'Helene Mercier',  'CAPITAINE ILLIMITE'),
 (2, 'Jan Verhoeven',   'CAPITAINE ILLIMITE'),
 (3, 'Wei Chen',        'CAPITAINE ILLIMITE'),
 (4, 'Aisha Farah',     'CAPITAINE 3000'),
 (5, 'Marc Ollivier',   'OFFICIER DE MARINE'),
 (6, 'Sarah Whitfield', 'OFFICIER DE MARINE'),
 (7, 'Lim Boon Hock',   'CAPITAINE 3000'),
 (8, 'Pieter Bakker',   'OFFICIER DE MARINE');

-- fin NULL = affectation en cours
INSERT INTO affectation (capitaine_id, bateau_id, debut, fin) VALUES
 (1,  1, DATE '2014-06-01', DATE '2019-03-31'),
 (1,  3, DATE '2019-05-01', NULL),
 (2,  4, DATE '2021-09-15', NULL),
 (2,  9, DATE '2016-01-10', DATE '2021-08-31'),
 (3,  7, DATE '2020-04-20', NULL),
 (3,  8, DATE '2015-02-01', DATE '2020-04-19'),
 (4,  2, DATE '2018-07-01', NULL),
 (7,  5, DATE '2017-03-12', NULL),
 (7,  6, DATE '2012-11-05', DATE '2017-03-11'),
 (5, 11, DATE '2021-01-15', NULL),
 (5, 12, DATE '2019-06-01', DATE '2020-12-31'),
 (6, 14, DATE '2018-08-01', DATE '2023-07-31'),
 (6, 15, DATE '2023-09-01', NULL),
 (8, 17, DATE '2011-04-01', DATE '2016-10-15'),
 (1, 10, DATE '2005-02-01', DATE '2014-05-31'),
 (5, 18, DATE '2016-03-01', DATE '2018-12-20');

-- ------------------------------------------------------------ escales
-- Les escales militaires ne portent AUCUNE cargaison. Trois escales sont
-- encore ouvertes (depart NULL).
INSERT INTO escale (id, bateau_id, quai_id, arrivee, depart, motif) VALUES
 (1,  1,  1, TIMESTAMP '2026-03-02 06:10', TIMESTAMP '2026-03-03 19:40', 'COMMERCE'),
 (2,  1,  7, TIMESTAMP '2026-03-21 11:00', TIMESTAMP '2026-03-23 05:20', 'COMMERCE'),
 (3,  1, 17, TIMESTAMP '2026-04-08 08:35', TIMESTAMP '2026-04-08 22:15', 'RAVITAILLEMENT'),
 (4,  3,  4, TIMESTAMP '2026-03-05 04:25', TIMESTAMP '2026-03-07 14:50', 'COMMERCE'),
 (5,  3, 10, TIMESTAMP '2026-03-28 21:05', TIMESTAMP '2026-03-31 09:30', 'COMMERCE'),
 (6,  3,  1, TIMESTAMP '2026-04-19 07:45', TIMESTAMP '2026-04-20 18:10', 'COMMERCE'),
 (7,  4,  4, TIMESTAMP '2026-03-11 05:55', TIMESTAMP '2026-03-14 03:40', 'COMMERCE'),
 (8,  4,  8, TIMESTAMP '2026-04-02 13:20', TIMESTAMP '2026-04-04 16:00', 'COMMERCE'),
 (9,  4, 10, TIMESTAMP '2026-04-25 02:10', NULL,                          'COMMERCE'),
 (10, 5,  7, TIMESTAMP '2026-03-04 09:15', TIMESTAMP '2026-03-05 23:55', 'COMMERCE'),
 (11, 5,  2, TIMESTAMP '2026-03-26 17:30', TIMESTAMP '2026-03-28 08:05', 'COMMERCE'),
 (12, 5, 20, TIMESTAMP '2026-04-14 10:00', TIMESTAMP '2026-04-22 12:00', 'REPARATION'),
 (13, 7, 10, TIMESTAMP '2026-03-09 03:40', TIMESTAMP '2026-03-12 07:25', 'COMMERCE'),
 (14, 7,  1, TIMESTAMP '2026-04-01 06:00', TIMESTAMP '2026-04-03 11:45', 'COMMERCE'),
 (15, 7,  4, TIMESTAMP '2026-04-18 15:10', TIMESTAMP '2026-04-21 02:35', 'COMMERCE'),
 (16, 2,  5, TIMESTAMP '2026-03-16 08:20', TIMESTAMP '2026-03-18 21:00', 'COMMERCE'),
 (17, 2,  9, TIMESTAMP '2026-04-06 12:45', TIMESTAMP '2026-04-08 06:30', 'COMMERCE'),
 (18, 8, 11, TIMESTAMP '2026-03-19 23:10', TIMESTAMP '2026-03-22 10:40', 'COMMERCE'),
 (19, 8,  5, TIMESTAMP '2026-04-11 05:05', TIMESTAMP '2026-04-13 18:20', 'COMMERCE'),
 (20, 9,  6, TIMESTAMP '2026-03-13 19:30', TIMESTAMP '2026-03-16 02:55', 'COMMERCE'),
 (21, 9,  3, TIMESTAMP '2026-04-05 04:15', TIMESTAMP '2026-04-07 13:05', 'COMMERCE'),
 (22, 6,  8, TIMESTAMP '2026-03-23 06:50', TIMESTAMP '2026-03-23 20:10', 'COMMERCE'),
 (23, 6, 17, TIMESTAMP '2026-04-16 09:25', TIMESTAMP '2026-04-16 23:40', 'COMMERCE'),
 (24, 10, 20, TIMESTAMP '2026-03-30 11:15', TIMESTAMP '2026-04-06 17:50', 'REPARATION'),
 (25, 10,  1, TIMESTAMP '2026-04-23 08:00', NULL,                          'COMMERCE'),
 (26, 11, 12, TIMESTAMP '2026-03-07 07:00', TIMESTAMP '2026-03-10 16:30', 'RAVITAILLEMENT'),
 (27, 11, 18, TIMESTAMP '2026-03-29 14:20', TIMESTAMP '2026-04-01 09:10', 'DIPLOMATIQUE'),
 (28, 12, 13, TIMESTAMP '2026-03-12 10:40', TIMESTAMP '2026-03-14 08:00', 'RAVITAILLEMENT'),
 (29, 12, 14, TIMESTAMP '2026-04-09 08:15', TIMESTAMP '2026-04-17 15:45', 'REPARATION'),
 (30, 13, 19, TIMESTAMP '2026-03-18 06:30', TIMESTAMP '2026-03-19 17:20', 'RAVITAILLEMENT'),
 (31, 14, 15, TIMESTAMP '2026-03-03 12:00', TIMESTAMP '2026-03-09 05:40', 'RAVITAILLEMENT'),
 (32, 14, 18, TIMESTAMP '2026-04-12 16:45', TIMESTAMP '2026-04-15 07:55', 'DIPLOMATIQUE'),
 (33, 15, 16, TIMESTAMP '2026-03-25 09:05', TIMESTAMP '2026-03-27 19:35', 'RAVITAILLEMENT'),
 (34, 16, 18, TIMESTAMP '2026-04-03 21:30', TIMESTAMP '2026-04-05 10:15', 'DIPLOMATIQUE'),
 (35, 17, 12, TIMESTAMP '2026-04-20 07:10', NULL,                          'DIPLOMATIQUE'),
 (36, 18, 13, TIMESTAMP '2026-03-27 05:45', TIMESTAMP '2026-03-30 22:25', 'RAVITAILLEMENT'),
 -- Delta Maas tire exactement les 16.0 m du Havre : a la frontiere, il passe.
 -- Yangtze Star en tire 16.5 et s'est quand meme amarre au meme quai (escale 14) :
 -- aucune contrainte SQL ne l'interdit, la regle croise deux tables.
 (37,  4,  1, TIMESTAMP '2026-04-27 06:30', TIMESTAMP '2026-04-29 12:10', 'COMMERCE');

-- --------------------------------------------------------- cargaisons
INSERT INTO cargaison (id, escale_id, marchandise, tonnes) VALUES
 ( 1,  1, 'Conteneurs secs',        41200.0),
 ( 2,  1, 'Conteneurs refrigeres',   8600.0),
 ( 3,  2, 'Conteneurs secs',        37800.0),
 ( 4,  2, 'Produits chimiques',      2400.0),
 ( 5,  4, 'Conteneurs secs',        96500.0),
 ( 6,  4, 'Machines-outils',        11200.0),
 ( 7,  5, 'Conteneurs secs',       104300.0),
 ( 8,  6, 'Conteneurs refrigeres',  14900.0),
 ( 9,  7, 'Conteneurs secs',       151000.0),
 (10,  7, 'Batteries lithium',       3100.0),
 (11,  8, 'Conteneurs secs',       128400.0),
 (12,  9, 'Conteneurs secs',       143700.0),
 (13, 10, 'Conteneurs secs',        82000.0),
 (14, 11, 'Conteneurs secs',        79500.0),
 (15, 11, 'Peintures et solvants',   1800.0),
 (16, 13, 'Conteneurs secs',       168000.0),
 (17, 14, 'Conteneurs secs',       159200.0),
 (18, 14, 'Engrais',                 9400.0),
 (19, 15, 'Conteneurs secs',       171500.0),
 (20, 16, 'Minerai de fer',         48000.0),
 (21, 17, 'Cereales',               31500.0),
 (22, 18, 'Charbon',                74000.0),
 (23, 19, 'Bauxite',                62800.0),
 (24, 20, 'Brut leger',            148000.0),
 (25, 21, 'Brut leger',            155000.0),
 (26, 22, 'Vehicules',               4100.0),
 (27, 23, 'Vehicules',               3900.0),
 (28, 25, 'Cable sous-marin',        2600.0),
 (29, 37, 'Conteneurs secs',       137900.0);

SELECT setval('pays_id_seq',        (SELECT MAX(id) FROM pays));
SELECT setval('port_id_seq',        (SELECT MAX(id) FROM port));
SELECT setval('quai_id_seq',        (SELECT MAX(id) FROM quai));
SELECT setval('armateur_id_seq',    (SELECT MAX(id) FROM armateur));
SELECT setval('marine_id_seq',      (SELECT MAX(id) FROM marine));
SELECT setval('bateau_id_seq',      (SELECT MAX(id) FROM bateau));
SELECT setval('capitaine_id_seq',   (SELECT MAX(id) FROM capitaine));
SELECT setval('escale_id_seq',      (SELECT MAX(id) FROM escale));
SELECT setval('cargaison_id_seq',   (SELECT MAX(id) FROM cargaison));
