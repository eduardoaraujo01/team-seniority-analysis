-- Verificação pós-migração. Não altera objetos nem dados.
-- Esperado: 638 linhas em cada view e zero diferenças em cada comparação.
\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT 'raw_profissionais_vs_staging' AS verificacao,
       (SELECT count(*) FROM raw.profissionais) AS raw,
       (SELECT count(*) FROM staging.profissionais) AS staging
UNION ALL SELECT 'raw_historico_vs_staging',
       (SELECT count(*) FROM raw.historico_senioridade),
       (SELECT count(*) FROM staging.historico_senioridade)
UNION ALL SELECT 'raw_projetos_vs_staging',
       (SELECT count(*) FROM raw.projetos),
       (SELECT count(*) FROM staging.projetos)
UNION ALL SELECT 'raw_participacoes_vs_staging',
       (SELECT count(*) FROM raw.participacoes),
       (SELECT count(*) FROM staging.participacoes)
ORDER BY verificacao;

WITH esperado AS (
    SELECT pr.projeto_id, pr.nome AS nome_projeto, pr.data_conclusao,
           pa.participacao_id, pa.profissional_id, pa.papel, pa.horas,
           h.senioridade AS senioridade_na_conclusao
    FROM raw.projetos pr
    JOIN raw.participacoes pa USING (projeto_id)
    JOIN raw.historico_senioridade h
      ON h.profissional_id = pa.profissional_id
     AND h.data_inicio <= pr.data_conclusao
     AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
    WHERE pr.status = 'Concluído'
      AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30'
), diferencas AS (
    (SELECT * FROM esperado
     EXCEPT ALL
     SELECT * FROM analytics.vw_participacoes_senioridade_historica)
    UNION ALL
    (SELECT * FROM analytics.vw_participacoes_senioridade_historica
     EXCEPT ALL
     SELECT * FROM esperado)
)
SELECT 'view_historica_vs_raw' AS verificacao,
       (SELECT count(*) FROM analytics.vw_participacoes_senioridade_historica) AS linhas_view,
       count(*) AS diferencas
FROM diferencas;

WITH esperado AS (
    SELECT pr.projeto_id, pr.nome AS nome_projeto, pr.data_conclusao,
           pa.participacao_id, pa.profissional_id, pa.papel, pa.horas,
           h.senioridade AS senioridade_em_2026_06_30
    FROM raw.projetos pr
    JOIN raw.participacoes pa USING (projeto_id)
    JOIN raw.historico_senioridade h
      ON h.profissional_id = pa.profissional_id
     AND h.data_inicio <= DATE '2026-06-30'
     AND (h.data_fim IS NULL OR h.data_fim >= DATE '2026-06-30')
    WHERE pr.status = 'Concluído'
      AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30'
), diferencas AS (
    (SELECT * FROM esperado
     EXCEPT ALL
     SELECT * FROM analytics.vw_participacoes_senioridade_data_corte)
    UNION ALL
    (SELECT * FROM analytics.vw_participacoes_senioridade_data_corte
     EXCEPT ALL
     SELECT * FROM esperado)
)
SELECT 'view_data_corte_vs_raw' AS verificacao,
       (SELECT count(*) FROM analytics.vw_participacoes_senioridade_data_corte) AS linhas_view,
       count(*) AS diferencas
FROM diferencas;

SELECT 'senioridades_diferentes_entre_as_views' AS verificacao,
       count(*) AS participacoes
FROM analytics.vw_participacoes_senioridade_historica h
JOIN analytics.vw_participacoes_senioridade_data_corte c
    USING (participacao_id)
WHERE h.senioridade_na_conclusao <> c.senioridade_em_2026_06_30;

SELECT n.nspname AS schema, c.relname AS tabela,
       co.conname AS constraint_name, co.contype AS tipo,
       pg_get_constraintdef(co.oid) AS definicao
FROM pg_constraint co
JOIN pg_class c ON c.oid = co.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'staging'
ORDER BY c.relname, co.contype, co.conname;

COMMIT;
