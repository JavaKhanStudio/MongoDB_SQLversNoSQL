-- =====================================================================
--  DB 2 — Les tortues : les chiffres de reference
--  Six questions posees a la base SQL. Le modele document devra rendre
--  exactement les memes lignes — c'est le test du sujet.
-- =====================================================================

\pset border 0
\pset footer off
\pset tuples_only on

\echo ''
\echo 'C1  Les tortues par espece'
\echo ''
SELECT '    ' || rpad(e.nom_scientifique, 24) || rpad(e.nom_commun, 20) || e.statut_uicn
       || lpad(COUNT(t.id)::text, 5) || ' tortues'
FROM espece e LEFT JOIN tortue t ON t.espece_id = e.id
GROUP BY e.nom_scientifique, e.nom_commun, e.statut_uicn
ORDER BY COUNT(t.id) DESC, e.nom_scientifique;

\echo ''
\echo 'C2  Les cinq sites les plus frequentes'
\echo ''
SELECT '    ' || rpad(s.nom, 18) || rpad(h.nom, 28) || lpad(COUNT(*)::text, 4) || ' observations'
FROM observation o JOIN site s ON s.id = o.site_id JOIN habitat h ON h.id = s.habitat_id
GROUP BY s.nom, h.nom ORDER BY COUNT(*) DESC, s.nom LIMIT 5;

\echo ''
\echo 'C3  Score de sante moyen par habitat (des tortues qui y vivent)'
\echo ''
SELECT '    ' || rpad(h.nom, 28) || to_char(AVG(o.score_sante), 'FM90.00')
       || '   sur ' || lpad(COUNT(*)::text, 4) || ' observations'
FROM tortue t JOIN habitat h ON h.id = t.habitat_id
JOIN observation o ON o.tortue_id = t.id
GROUP BY h.nom ORDER BY AVG(o.score_sante) DESC;

\echo ''
\echo 'C4  Les programmes et leurs inscrites'
\echo ''
SELECT '    ' || rpad(p.acronyme, 7) || rpad(p.statut, 10) || rpad(o.nom, 38)
       || lpad(COUNT(i.tortue_id)::text, 4) || ' tortues'
FROM programme p JOIN organisation o ON o.id = p.organisation_id
LEFT JOIN inscription i ON i.programme_id = p.id
GROUP BY p.acronyme, p.statut, o.nom ORDER BY COUNT(i.tortue_id) DESC, p.acronyme;

\echo ''
\echo 'C5  Les tags, du plus porte au moins porte'
\echo ''
SELECT '    ' || rpad(g.libelle, 22) || lpad(COUNT(*)::text, 4) || ' tortues'
FROM tortue_tag tt JOIN tag g ON g.id = tt.tag_id
GROUP BY g.libelle ORDER BY COUNT(*) DESC, g.libelle;

\echo ''
\echo 'C6  Les trous du jeu de donnees'
\echo ''
SELECT '    tortues sans habitat        ' || lpad(COUNT(*)::text, 4) FROM tortue WHERE habitat_id IS NULL
UNION ALL
SELECT '    tortues jamais observees    ' || lpad(COUNT(*)::text, 4) FROM tortue t
  WHERE NOT EXISTS (SELECT 1 FROM observation o WHERE o.tortue_id = t.id)
UNION ALL
SELECT '    tortues dans aucun programme' || lpad(COUNT(*)::text, 4) FROM tortue t
  WHERE NOT EXISTS (SELECT 1 FROM inscription i WHERE i.tortue_id = t.id)
UNION ALL
SELECT '    programmes toutes especes   ' || lpad(COUNT(*)::text, 4) FROM programme WHERE espece_cible_id IS NULL
UNION ALL
SELECT '    programmes sans terme       ' || lpad(COUNT(*)::text, 4) FROM programme WHERE annee_fin IS NULL;

\echo ''
