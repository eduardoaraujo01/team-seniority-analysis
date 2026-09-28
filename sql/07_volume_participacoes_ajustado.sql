-- Calcula o volume de participações ajustado pelo tamanho da categoria.
-- Execute depois das validações e da consulta de volume por senioridade histórica.
--
-- A unidade temporal do denominador é a média mensal de profissionais por
-- senioridade. Para cada mês, considera-se a senioridade vigente no último dia
-- daquele mês; depois, calcula-se a média desses retratos mensais no ano.
-- Em 2026, a média considera somente janeiro a junho (seis meses).
--
-- Fórmula: participações concluídas no período / média mensal de profissionais
-- na senioridade. O resultado representa volume ajustado pelo tamanho da categoria;
-- não comprova produtividade individual. 2026 é parcial e deve ser identificado
-- como tal ao apresentar os resultados.

WITH meses AS (
    SELECT
        gs.mes_inicio::DATE AS mes_inicio,
        (gs.mes_inicio + INTERVAL '1 month' - INTERVAL '1 day')::DATE AS fim_mes
    FROM GENERATE_SERIES(
        TIMESTAMP '2021-01-01 00:00:00',
        TIMESTAMP '2026-06-01 00:00:00',
        INTERVAL '1 month'
    ) AS gs(mes_inicio)
),
senioridades AS (
    SELECT DISTINCT senioridade
    FROM raw.historico_senioridade
),
tamanho_mensal_categoria AS (
    SELECT
        m.mes_inicio,
        EXTRACT(YEAR FROM m.mes_inicio)::INTEGER AS ano,
        s.senioridade,
        COUNT(DISTINCT h.profissional_id) AS profissionais_no_fim_do_mes
    FROM meses m
    CROSS JOIN senioridades s
    LEFT JOIN raw.historico_senioridade h
        ON h.senioridade = s.senioridade
       AND h.data_inicio <= m.fim_mes
       AND (h.data_fim IS NULL OR h.data_fim >= m.fim_mes)
    GROUP BY m.mes_inicio, m.fim_mes, s.senioridade
),
media_mensal_categoria AS (
    SELECT
        ano,
        senioridade,
        COUNT(*) AS meses_observados,
        AVG(profissionais_no_fim_do_mes)::NUMERIC AS media_profissionais_mensal
    FROM tamanho_mensal_categoria
    GROUP BY ano, senioridade
),
participacoes_por_ano AS (
    SELECT
        EXTRACT(YEAR FROM pr.data_conclusao)::INTEGER AS ano,
        h.senioridade,
        COUNT(DISTINCT pa.participacao_id) AS total_participacoes
    FROM raw.projetos pr
    JOIN raw.participacoes pa
        ON pa.projeto_id = pr.projeto_id
    JOIN raw.historico_senioridade h
        ON h.profissional_id = pa.profissional_id
       AND h.data_inicio <= pr.data_conclusao
       AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
    WHERE pr.status = 'Concluído'
      AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30'
    GROUP BY EXTRACT(YEAR FROM pr.data_conclusao)::INTEGER, h.senioridade
),
anos AS (
    SELECT GENERATE_SERIES(2021, 2026) AS ano
),
combinacoes AS (
    SELECT a.ano, s.senioridade
    FROM anos a
    CROSS JOIN senioridades s
)
SELECT
    c.ano,
    CASE WHEN c.ano = 2026 THEN 'Parcial: jan-jun' ELSE 'Ano completo' END AS periodo_status,
    c.senioridade,
    COALESCE(p.total_participacoes, 0) AS total_participacoes,
    m.meses_observados,
    ROUND(m.media_profissionais_mensal, 2) AS media_mensal_profissionais_categoria,
    ROUND(
        COALESCE(p.total_participacoes, 0)::NUMERIC
        / NULLIF(m.media_profissionais_mensal, 0),
        2
    ) AS volume_ajustado_pela_media_mensal
FROM combinacoes c
LEFT JOIN media_mensal_categoria m
    ON m.ano = c.ano
   AND m.senioridade = c.senioridade
LEFT JOIN participacoes_por_ano p
    ON p.ano = c.ano
   AND p.senioridade = c.senioridade
ORDER BY c.ano, c.senioridade;
