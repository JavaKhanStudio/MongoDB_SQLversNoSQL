-- =====================================================================
--  DB 3 — Les bateaux : les chiffres de reference
--  Six questions posees a la base SQL. Le modele document devra rendre
--  exactement les memes lignes — c'est le test du sujet.
--  Remarquer C1 et C2 : la meme question, deux fois, parce que le
--  schema relationnel ne sait pas la poser une seule fois.
-- =====================================================================

\pset border 0
\pset footer off
\pset tuples_only on

\echo ''
\echo 'C1  La flotte civile'
\echo ''
SELECT '    ' || rpad(b.nom, 18) || rpad(bc.type_civil, 18) || rpad(a.nom, 20)
       || lpad(bc.port_en_lourd_t::text, 7) || ' tpl'
       || COALESCE('   ' || bc.capacite_evp || ' EVP', '')
FROM bateau b JOIN bateau_civil bc ON bc.bateau_id = b.id
JOIN armateur a ON a.id = bc.armateur_id
ORDER BY bc.port_en_lourd_t DESC;

\echo ''
\echo 'C2  La flotte militaire'
\echo ''
SELECT '    ' || rpad(b.nom, 18) || rpad(bm.classe, 18) || rpad(m.nom, 20)
       || lpad(bm.equipage::text, 5) || ' hommes'
       || CASE WHEN bm.propulsion_nucleaire THEN '   nucleaire' ELSE '' END
FROM bateau b JOIN bateau_militaire bm ON bm.bateau_id = b.id
JOIN marine m ON m.id = bm.marine_id
ORDER BY bm.equipage DESC;

\echo ''
\echo 'C3  Tonnage manipule par port'
\echo ''
SELECT '    ' || rpad(p.nom, 12) || lpad(to_char(SUM(c.tonnes), 'FM9999990'), 9) || ' t en '
       || lpad(COUNT(DISTINCT e.id)::text, 3) || ' escales de commerce'
FROM cargaison c JOIN escale e ON e.id = c.escale_id
JOIN quai q ON q.id = e.quai_id JOIN port p ON p.id = q.port_id
GROUP BY p.nom ORDER BY SUM(c.tonnes) DESC;

\echo ''
\echo 'C4  Encore a quai (depart non renseigne)'
\echo ''
SELECT '    ' || rpad(b.nom, 18) || rpad(b.categorie, 11) || rpad(p.nom, 12)
       || 'quai ' || rpad(q.numero, 4) || 'depuis le ' || to_char(e.arrivee, 'DD/MM/YYYY')
FROM escale e JOIN bateau b ON b.id = e.bateau_id
JOIN quai q ON q.id = e.quai_id JOIN port p ON p.id = q.port_id
WHERE e.depart IS NULL ORDER BY e.arrivee;

\echo ''
\echo 'C5  Les capitaines et leurs commandements'
\echo ''
SELECT '    ' || rpad(c.nom, 18) || rpad(c.brevet, 20)
       || COUNT(*) || ' bateaux, en cours : '
       || COALESCE(MAX(b.nom) FILTER (WHERE a.fin IS NULL), 'aucun')
FROM capitaine c JOIN affectation a ON a.capitaine_id = c.id
JOIN bateau b ON b.id = a.bateau_id
GROUP BY c.nom, c.brevet ORDER BY COUNT(*) DESC, c.nom;

\echo ''
\echo 'C6  Escales impossibles : le bateau tire plus que le port n autorise'
\echo '    (aucune contrainte SQL ne l interdit : la regle croise deux tables)'
\echo ''
SELECT '    escale ' || lpad(e.id::text, 3) || '   ' || rpad(b.nom, 18)
       || to_char(b.tirant_eau_m, 'FM90.0') || ' m  >  ' || rpad(p.nom, 12)
       || to_char(p.tirant_eau_max_m, 'FM90.0') || ' m'
FROM escale e JOIN bateau b ON b.id = e.bateau_id
JOIN quai q ON q.id = e.quai_id JOIN port p ON p.id = q.port_id
WHERE b.tirant_eau_m > p.tirant_eau_max_m ORDER BY e.id;

\echo ''
