-- Valida datas, status, participações e horas nas tabelas raw.
-- Execute depois das verificações de chaves e do histórico de senioridade.
--
-- As três primeiras consultas devem retornar nenhuma linha:
--   1. projetos com status ou datas incompatíveis com as regras do projeto;
--   2. participações em projetos concluídos sem exatamente uma senioridade
--      válida na data de conclusão;
--   3. horas inválidas ou projetos com quantidade de participações fora de 2 a 4.
--
-- A última consulta é um resumo, portanto retorna linhas. Confira os valores
-- esperados nos comentários antes dela. O ano de 2026 é parcial até 30/06/2026.

-- 1. Datas e status dos projetos.
SELECT
    projeto_id,
    data_inicio,
    data_conclusao,
    status,
    'Status ou datas incompatíveis com o período analisado' AS problema
FROM raw.projetos
WHERE projeto_id IS NULL
   OR data_inicio IS NULL
   OR data_inicio < DATE '2021-01-01'
   OR data_inicio > DATE '2026-06-30'
   OR status IS NULL
   OR status NOT IN ('Concluído', 'Em andamento')
   OR (
        status = 'Concluído'
        AND (
            data_conclusao IS NULL
            OR data_conclusao < data_inicio
            OR data_conclusao > DATE '2026-06-30'
        )
   )
   OR (
        status = 'Em andamento'
        AND data_conclusao IS NOT NULL
   )
ORDER BY projeto_id;

-- 2. Cada participação de um projeto concluído deve encontrar exatamente
--    um período de senioridade válido na data de conclusão daquele projeto.
SELECT
    pa.participacao_id,
    pa.projeto_id,
    pa.profissional_id,
    pr.data_conclusao,
    COUNT(h.historico_id) AS periodos_de_senioridade_encontrados
FROM raw.participacoes pa
JOIN raw.projetos pr
    ON pr.projeto_id = pa.projeto_id
LEFT JOIN raw.historico_senioridade h
    ON h.profissional_id = pa.profissional_id
   AND h.data_inicio <= pr.data_conclusao
   AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
WHERE pr.status = 'Concluído'
GROUP BY
    pa.participacao_id,
    pa.projeto_id,
    pa.profissional_id,
    pr.data_conclusao
HAVING COUNT(h.historico_id) <> 1
ORDER BY pa.participacao_id;

-- 3. Horas devem ser positivas; cada projeto do conjunto gerado deve ter
--    entre 2 e 4 profissionais participantes.
SELECT
    'Horas nulas ou não positivas' AS verificacao,
    participacao_id::TEXT AS registro
FROM raw.participacoes
WHERE horas IS NULL OR horas <= 0

UNION ALL

SELECT
    'Quantidade de participações fora do intervalo 2–4',
    pr.projeto_id::TEXT || ' (' || COUNT(pa.participacao_id)::TEXT || ')'
FROM raw.projetos pr
LEFT JOIN raw.participacoes pa
    ON pa.projeto_id = pr.projeto_id
GROUP BY pr.projeto_id
HAVING COUNT(pa.participacao_id) NOT BETWEEN 2 AND 4
ORDER BY verificacao, registro;

-- 4. Resumo para conferência manual.
-- Esperado: 36 projetos concluídos em cada ano de 2021 a 2025,
-- 30 concluídos entre janeiro e junho de 2026 e 10 em andamento.
SELECT
    status,
    CASE
        WHEN status = 'Concluído'
            THEN EXTRACT(YEAR FROM data_conclusao)::INTEGER::TEXT
        ELSE 'sem data de conclusão'
    END AS periodo,
    COUNT(*) AS quantidade_projetos
FROM raw.projetos
GROUP BY
    status,
    CASE
        WHEN status = 'Concluído'
            THEN EXTRACT(YEAR FROM data_conclusao)::INTEGER::TEXT
        ELSE 'sem data de conclusão'
    END
ORDER BY status, periodo;
