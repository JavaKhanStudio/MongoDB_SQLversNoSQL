-- =====================================================================
--  Le schema de la base courante, lu dans le catalogue : les tables avec
--  leurs colonnes, puis toutes les relations. Le meme fichier sert aux
--  trois sujets — make dune-schema, make tortues-schema, make bateaux-schema.
-- =====================================================================

\pset border 0
\pset footer off
\pset tuples_only on

\echo ''
\echo '=== LES TABLES ======================================================'
\echo '  table                   colonne                   type                        reference'
\echo ''

SELECT '  ' || rpad(c.relname, 24)
    || rpad(a.attname, 26)
    || rpad(replace(format_type(a.atttypid, a.atttypmod), ' without time zone', ''), 16)
    || CASE WHEN a.attnotnull THEN 'NOT NULL ' ELSE '         ' END
    || CASE
         WHEN EXISTS (SELECT 1 FROM pg_constraint k
                      WHERE k.conrelid = c.oid AND k.contype = 'p'
                        AND a.attnum = ANY (k.conkey)) THEN 'PK '
         ELSE '   ' END
    || COALESCE((SELECT '-> ' || fc.relname
                 FROM pg_constraint k
                 JOIN pg_class fc ON fc.oid = k.confrelid
                 WHERE k.conrelid = c.oid AND k.contype = 'f'
                   AND a.attnum = ANY (k.conkey)
                 LIMIT 1), '')
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
WHERE n.nspname = 'public' AND c.relkind = 'r'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;

\echo ''
\echo '=== LES RELATIONS ==================================================='
\echo '  depuis                     vers                     (colonne porteuse)'
\echo ''

SELECT '  ' || rpad(src.relname, 24) || ' -> ' || rpad(tgt.relname, 24)
    || '(' || (SELECT string_agg(att.attname, ', ' ORDER BY att.attnum)
               FROM unnest(k.conkey) AS col(num)
               JOIN pg_attribute att ON att.attrelid = src.oid AND att.attnum = col.num)
    || ')'
FROM pg_constraint k
JOIN pg_class src ON src.oid = k.conrelid
JOIN pg_class tgt ON tgt.oid = k.confrelid
JOIN pg_namespace n ON n.oid = src.relnamespace
WHERE k.contype = 'f' AND n.nspname = 'public'
ORDER BY src.relname, tgt.relname;

\echo ''
\echo '=== LE POIDS DES NULL ==============================================='
\echo '  Une colonne souvent NULL est une colonne qui ne concerne pas'
\echo '  toutes les lignes : c est la que le document a quelque chose a dire.'
\echo ''
SELECT '  ' || rpad(c.relname, 24) || rpad(a.attname, 26)
    || lpad(x.nuls::text, 6) || ' NULL sur ' || lpad(x.total::text, 5)
    || '   ' || lpad(round(100.0 * x.nuls / NULLIF(x.total, 0))::text, 3) || ' %'
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
CROSS JOIN LATERAL (
    SELECT (xpath('/row/t/text()', q))[1]::text::bigint AS total,
           (xpath('/row/v/text()', q))[1]::text::bigint AS nuls
    FROM query_to_xml(
        format('select count(*) as t, count(*) - count(%I) as v from %I.%I',
               a.attname, n.nspname, c.relname), false, true, '') AS q
) x
WHERE n.nspname = 'public' AND c.relkind = 'r'
  AND a.attnum > 0 AND NOT a.attisdropped AND NOT a.attnotnull
  AND x.nuls > 0
ORDER BY 100.0 * x.nuls / NULLIF(x.total, 0) DESC, c.relname, a.attname;

\echo ''
