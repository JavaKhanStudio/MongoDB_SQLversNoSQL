-- =====================================================================
--  La base SQL, telle quelle, en UN objet JSON
--  Une cle par table, un tableau de lignes par valeur. Le meme fichier
--  pour les trois sujets : il lit le catalogue, il n'ecrit aucun nom de
--  table a la main.
-- =====================================================================
--  Joue par  : make <sujet>-verifier, qui pose le resultat dans le
--              conteneur mongo, la ou correction.js le relit.
--  Ce n'est PAS le modele document : c'est la matiere premiere. Le
--  passage aux documents est dans sujets/<n>-<sujet>/correction.js.
-- =====================================================================

\pset format unaligned
\pset tuples_only on
\pset footer off

-- On fabrique la requete, puis \gexec l'execute : json_build_object ne
-- sait pas prendre une liste de tables en parametre.
SELECT 'SELECT json_build_object(' ||
       string_agg(format('%L, (SELECT coalesce(json_agg(t ORDER BY t), ''[]''::json) FROM %I t)',
                         c.relname, c.relname),
                  ', ' ORDER BY c.relname) || ')'
FROM   pg_class c
JOIN   pg_namespace n ON n.oid = c.relnamespace
WHERE  n.nspname = 'public' AND c.relkind = 'r'
\gexec
