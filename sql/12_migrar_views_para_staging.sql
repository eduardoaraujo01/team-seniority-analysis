-- Migra as views analíticas existentes de raw para staging.
-- Execute somente depois de 09, 10 e 11 terminarem sem divergências.
-- Mantém nomes, colunas, filtros e granularidade para não quebrar consumidores.
-- Para reverter a origem das views para raw, reexecute 08_criar_views_analiticas.sql.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

DO $validacao$
BEGIN
    IF (SELECT count(*) FROM raw.profissionais)
       <> (SELECT count(*) FROM staging.profissionais)
       OR (SELECT count(*) FROM raw.historico_senioridade)
       <> (SELECT count(*) FROM staging.historico_senioridade)
       OR (SELECT count(*) FROM raw.projetos)
       <> (SELECT count(*) FROM staging.projetos)
       OR (SELECT count(*) FROM raw.participacoes)
       <> (SELECT count(*) FROM staging.participacoes) THEN
        RAISE EXCEPTION 'raw e staging têm contagens diferentes; views não foram alteradas.';
    END IF;

    IF EXISTS (
        (SELECT * FROM raw.profissionais
         EXCEPT ALL SELECT * FROM staging.profissionais)
        UNION ALL
        (SELECT * FROM staging.profissionais
         EXCEPT ALL SELECT * FROM raw.profissionais)
    ) OR EXISTS (
        (SELECT * FROM raw.historico_senioridade
         EXCEPT ALL SELECT * FROM staging.historico_senioridade)
        UNION ALL
        (SELECT * FROM staging.historico_senioridade
         EXCEPT ALL SELECT * FROM raw.historico_senioridade)
    ) OR EXISTS (
        (SELECT * FROM raw.projetos
         EXCEPT ALL SELECT * FROM staging.projetos)
        UNION ALL
        (SELECT * FROM staging.projetos
         EXCEPT ALL SELECT * FROM raw.projetos)
    ) OR EXISTS (
        (SELECT * FROM raw.participacoes
         EXCEPT ALL SELECT * FROM staging.participacoes)
        UNION ALL
        (SELECT * FROM staging.participacoes
         EXCEPT ALL SELECT * FROM raw.participacoes)
    ) THEN
        RAISE EXCEPTION 'raw e staging têm diferenças de conteúdo; views não foram alteradas.';
    END IF;
END
$validacao$;

CREATE OR REPLACE VIEW analytics.vw_participacoes_senioridade_historica AS
SELECT
    pr.projeto_id,
    pr.nome AS nome_projeto,
    pr.data_conclusao,
    pa.participacao_id,
    pa.profissional_id,
    pa.papel,
    pa.horas,
    h.senioridade AS senioridade_na_conclusao
FROM staging.projetos pr
JOIN staging.participacoes pa
    ON pa.projeto_id = pr.projeto_id
JOIN staging.historico_senioridade h
    ON h.profissional_id = pa.profissional_id
   AND h.data_inicio <= pr.data_conclusao
   AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
WHERE pr.status = 'Concluído'
  AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30';

CREATE OR REPLACE VIEW analytics.vw_participacoes_senioridade_data_corte AS
SELECT
    pr.projeto_id,
    pr.nome AS nome_projeto,
    pr.data_conclusao,
    pa.participacao_id,
    pa.profissional_id,
    pa.papel,
    pa.horas,
    h.senioridade AS senioridade_em_2026_06_30
FROM staging.projetos pr
JOIN staging.participacoes pa
    ON pa.projeto_id = pr.projeto_id
JOIN staging.historico_senioridade h
    ON h.profissional_id = pa.profissional_id
   AND h.data_inicio <= DATE '2026-06-30'
   AND (h.data_fim IS NULL OR h.data_fim >= DATE '2026-06-30')
WHERE pr.status = 'Concluído'
  AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30';

SELECT 'historica' AS view, count(*) AS registros
FROM analytics.vw_participacoes_senioridade_historica
UNION ALL
SELECT 'data_corte', count(*)
FROM analytics.vw_participacoes_senioridade_data_corte
ORDER BY view;

COMMIT;
