-- Auditoria somente de leitura da camada staging.
-- Resultado esperado: contagens iguais a raw e zero ocorrências de qualidade.
\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT 'profissionais' AS tabela,
       (SELECT count(*) FROM raw.profissionais) AS raw,
       (SELECT count(*) FROM staging.profissionais) AS staging
UNION ALL SELECT 'historico_senioridade',
       (SELECT count(*) FROM raw.historico_senioridade),
       (SELECT count(*) FROM staging.historico_senioridade)
UNION ALL SELECT 'projetos',
       (SELECT count(*) FROM raw.projetos),
       (SELECT count(*) FROM staging.projetos)
UNION ALL SELECT 'participacoes',
       (SELECT count(*) FROM raw.participacoes),
       (SELECT count(*) FROM staging.participacoes)
ORDER BY tabela;

SELECT 'registros diferentes ou ausentes em staging' AS verificacao,
       'profissionais' AS tabela, count(*) AS ocorrencias
FROM (
    (SELECT * FROM raw.profissionais
     EXCEPT ALL SELECT * FROM staging.profissionais)
    UNION ALL
    (SELECT * FROM staging.profissionais
     EXCEPT ALL SELECT * FROM raw.profissionais)
) d
UNION ALL
SELECT 'registros diferentes ou ausentes em staging', 'historico_senioridade', count(*)
FROM (
    (SELECT * FROM raw.historico_senioridade
     EXCEPT ALL SELECT * FROM staging.historico_senioridade)
    UNION ALL
    (SELECT * FROM staging.historico_senioridade
     EXCEPT ALL SELECT * FROM raw.historico_senioridade)
) d
UNION ALL
SELECT 'registros diferentes ou ausentes em staging', 'projetos', count(*)
FROM (
    (SELECT * FROM raw.projetos
     EXCEPT ALL SELECT * FROM staging.projetos)
    UNION ALL
    (SELECT * FROM staging.projetos
     EXCEPT ALL SELECT * FROM raw.projetos)
) d
UNION ALL
SELECT 'registros diferentes ou ausentes em staging', 'participacoes', count(*)
FROM (
    (SELECT * FROM raw.participacoes
     EXCEPT ALL SELECT * FROM staging.participacoes)
    UNION ALL
    (SELECT * FROM staging.participacoes
     EXCEPT ALL SELECT * FROM raw.participacoes)
) d
ORDER BY tabela;

SELECT 'referencia sem pai' AS verificacao, 'historico_senioridade' AS tabela,
       count(*) AS ocorrencias
FROM staging.historico_senioridade h
LEFT JOIN staging.profissionais p USING (profissional_id)
WHERE p.profissional_id IS NULL
UNION ALL
SELECT 'referencia sem pai', 'participacoes.profissional', count(*)
FROM staging.participacoes pa
LEFT JOIN staging.profissionais p USING (profissional_id)
WHERE p.profissional_id IS NULL
UNION ALL
SELECT 'referencia sem pai', 'participacoes.projeto', count(*)
FROM staging.participacoes pa
LEFT JOIN staging.projetos pr USING (projeto_id)
WHERE pr.projeto_id IS NULL
UNION ALL
SELECT 'horas invalidas', 'participacoes', count(*)
FROM staging.participacoes WHERE horas <= 0
UNION ALL
SELECT 'datas invalidas', 'historico_senioridade', count(*)
FROM staging.historico_senioridade
WHERE data_fim IS NOT NULL AND data_fim < data_inicio
UNION ALL
SELECT 'projeto concluido sem data', 'projetos', count(*)
FROM staging.projetos
WHERE status = 'Concluído' AND data_conclusao IS NULL
UNION ALL
SELECT 'participacao duplicada por projeto/profissional', 'participacoes', count(*)
FROM (
    SELECT projeto_id, profissional_id
    FROM staging.participacoes
    GROUP BY projeto_id, profissional_id
    HAVING count(*) > 1
) duplicados
ORDER BY tabela, verificacao;

SELECT 'profissional sem histórico' AS verificacao,
       'historico_senioridade' AS tabela, count(*) AS ocorrencias
FROM staging.profissionais p
LEFT JOIN staging.historico_senioridade h USING (profissional_id)
WHERE h.historico_id IS NULL
UNION ALL
SELECT 'histórico anterior à admissão', 'historico_senioridade', count(*)
FROM staging.historico_senioridade h
JOIN staging.profissionais p USING (profissional_id)
WHERE h.data_inicio < p.data_admissao
UNION ALL
SELECT 'projeto anterior à admissão', 'participacoes', count(*)
FROM staging.participacoes pa
JOIN staging.projetos pr USING (projeto_id)
JOIN staging.profissionais p USING (profissional_id)
WHERE pr.data_inicio < p.data_admissao
   OR (pr.data_conclusao IS NOT NULL
       AND pr.data_conclusao < p.data_admissao);

WITH periodos AS (
    SELECT profissional_id, historico_id, data_inicio, data_fim,
           lead(data_inicio) OVER (
               PARTITION BY profissional_id
               ORDER BY data_inicio, historico_id
           ) AS proxima_data_inicio
    FROM staging.historico_senioridade
)
SELECT 'lacuna ou sobreposicao entre periodos' AS verificacao,
       profissional_id, historico_id, data_fim, proxima_data_inicio
FROM periodos
WHERE proxima_data_inicio IS NOT NULL
  AND (data_fim IS NULL OR data_fim <> proxima_data_inicio - 1)
ORDER BY profissional_id, data_inicio;

SELECT 'views atuais antes da troca' AS etapa,
       'historica' AS view, count(*) AS linhas,
       count(DISTINCT participacao_id) AS participacoes
FROM analytics.vw_participacoes_senioridade_historica
UNION ALL
SELECT 'views atuais antes da troca', 'data_corte', count(*),
       count(DISTINCT participacao_id)
FROM analytics.vw_participacoes_senioridade_data_corte
ORDER BY view;

COMMIT;
