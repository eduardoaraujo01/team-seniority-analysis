-- Conta projetos concluídos e participações por senioridade histórica.
-- A senioridade é a vigente para cada profissional na data de conclusão do projeto.
-- Execute depois que as validações de qualidade dos dados retornarem sem problemas.
--
-- O resultado reúne três granularidades: mês, trimestre e ano.
-- projetos_distintos conta cada projeto uma vez por senioridade. Se um projeto
-- tiver participantes de mais de uma senioridade, ele aparecerá em cada categoria
-- correspondente. participacoes conta as relações profissional-projeto.
--
-- Os resultados de 2026 cobrem somente janeiro a junho, até 30/06/2026, e estão
-- marcados como parciais. Compare-os com os anos completos com essa diferença em mente.

WITH participacoes_concluidas AS (
    SELECT
        pr.projeto_id,
        pr.data_conclusao,
        EXTRACT(YEAR FROM pr.data_conclusao)::INTEGER AS ano,
        pa.participacao_id,
        h.senioridade
    FROM raw.projetos pr
    JOIN raw.participacoes pa
        ON pa.projeto_id = pr.projeto_id
    JOIN raw.historico_senioridade h
        ON h.profissional_id = pa.profissional_id
       AND h.data_inicio <= pr.data_conclusao
       AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
    WHERE pr.status = 'Concluído'
      AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30'
)
SELECT
    1 AS ordem_granularidade,
    'Mês' AS granularidade,
    DATE_TRUNC('month', data_conclusao)::DATE AS periodo_inicio,
    ano,
    CASE WHEN ano = 2026 THEN 'Parcial: jan-jun' ELSE 'Ano completo' END AS periodo_status,
    senioridade,
    COUNT(DISTINCT projeto_id) AS projetos_distintos,
    COUNT(DISTINCT participacao_id) AS participacoes
FROM participacoes_concluidas
GROUP BY DATE_TRUNC('month', data_conclusao)::DATE, ano, senioridade

UNION ALL

SELECT
    2 AS ordem_granularidade,
    'Trimestre' AS granularidade,
    DATE_TRUNC('quarter', data_conclusao)::DATE AS periodo_inicio,
    ano,
    CASE WHEN ano = 2026 THEN 'Parcial: jan-jun' ELSE 'Ano completo' END AS periodo_status,
    senioridade,
    COUNT(DISTINCT projeto_id) AS projetos_distintos,
    COUNT(DISTINCT participacao_id) AS participacoes
FROM participacoes_concluidas
GROUP BY DATE_TRUNC('quarter', data_conclusao)::DATE, ano, senioridade

UNION ALL

SELECT
    3 AS ordem_granularidade,
    'Ano' AS granularidade,
    DATE_TRUNC('year', data_conclusao)::DATE AS periodo_inicio,
    ano,
    CASE WHEN ano = 2026 THEN 'Parcial: jan-jun' ELSE 'Ano completo' END AS periodo_status,
    senioridade,
    COUNT(DISTINCT projeto_id) AS projetos_distintos,
    COUNT(DISTINCT participacao_id) AS participacoes
FROM participacoes_concluidas
GROUP BY DATE_TRUNC('year', data_conclusao)::DATE, ano, senioridade

ORDER BY ordem_granularidade, periodo_inicio, senioridade;
