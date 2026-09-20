-- =====================================================================
--  DB 1 — « Dune » : les chiffres de reference
--  Six questions. Leurs reponses ne dependent PAS du modele : elles sont
--  vraies sur la base SQL, elles doivent rester vraies sur les documents.
--  C'est le test du sujet : reposer ces six questions a MongoDB, sur le
--  modele qu'on a concu, et retrouver exactement ces lignes.
-- =====================================================================

\pset border 0
\pset footer off
\pset tuples_only on

\echo ''
\echo 'C1  Tonnage d epice collecte par region (collectes reussies)'
\echo ''
SELECT '    ' || rpad(r.nom, 22) || lpad(to_char(SUM(c.tonnes_epice), 'FM99990.00'), 10) || ' t'
FROM collecte c
JOIN puits p  ON p.id = c.puits_id
JOIN region r ON r.id = p.region_id
WHERE c.statut = 'REUSSIE'
GROUP BY r.nom ORDER BY SUM(c.tonnes_epice) DESC;

\echo ''
\echo 'C2  Echecs par cause'
\echo ''
SELECT '    ' || rpad(cause, 12) || lpad(COUNT(*)::text, 3) || ' echecs, '
       || lpad(SUM(pertes_humaines)::text, 3) || ' morts, materiel perdu '
       || COUNT(*) FILTER (WHERE materiel_perdu) || ' fois'
FROM collecte WHERE statut = 'ECHOUEE'
GROUP BY cause ORDER BY COUNT(*) DESC, cause;

\echo ''
\echo 'C3  Les trois puits les plus productifs'
\echo ''
SELECT '    ' || rpad(p.code, 8) || lpad(to_char(SUM(c.tonnes_epice), 'FM99990.00'), 10) || ' t en '
       || COUNT(*) || ' collectes reussies'
FROM collecte c JOIN puits p ON p.id = c.puits_id
WHERE c.statut = 'REUSSIE'
GROUP BY p.code ORDER BY SUM(c.tonnes_epice) DESC LIMIT 3;

\echo ''
\echo 'C4  Les vers qui ont fait echouer une collecte'
\echo ''
SELECT '    ' || rpad(v.nom, 22) || lpad(COUNT(*)::text, 2) || ' collectes detruites, '
       || SUM(c.pertes_humaines) || ' morts'
FROM collecte c JOIN ver v ON v.id = c.ver_id
WHERE c.statut = 'ECHOUEE' AND c.cause = 'VER'
GROUP BY v.nom ORDER BY COUNT(*) DESC, v.nom;

\echo ''
\echo 'C5  Contremaitres : ce qu ils ont sorti, ce qu ils ont perdu'
\echo ''
SELECT '    ' || rpad(cm.nom, 18) || rpad(cm.maison, 11)
       || lpad(to_char(COALESCE(SUM(c.tonnes_epice), 0), 'FM99990.00'), 10) || ' t   '
       || COUNT(*) FILTER (WHERE c.statut = 'ECHOUEE') || ' echecs'
FROM contremaitre cm LEFT JOIN collecte c ON c.contremaitre_id = cm.id
GROUP BY cm.nom, cm.maison ORDER BY COALESCE(SUM(c.tonnes_epice), 0) DESC;

\echo ''
\echo 'C6  Puits sous alerte : un releve d amplitude superieure a 5.00'
\echo ''
SELECT '    ' || rpad(p.code, 8) || lpad(COUNT(*)::text, 2) || ' alertes, pic a '
       || to_char(MAX(rv.amplitude), 'FM90.00')
FROM releve_vibration rv JOIN puits p ON p.id = rv.puits_id
WHERE rv.amplitude > 5.00
GROUP BY p.code ORDER BY MAX(rv.amplitude) DESC;

\echo ''
