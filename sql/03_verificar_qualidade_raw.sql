-- Verificações de qualidade das tabelas do schema raw.
-- Executar após importar os CSVs.
-- Resultados vazios significam que não foram encontradas ocorrências
-- nos critérios consultados. Isso não substitui as demais validações do projeto.

-- 1. IDs nulos ou repetidos e participações repetidas
--    para a mesma combinação de projeto e profissional.
WITH problemas AS (
    SELECT
        'ID duplicado ou nulo: profissionais' AS verificacao,
        COALESCE(profissional_id::TEXT, '(NULL)') AS registro,
        COUNT(*) AS ocorrencias
    FROM raw.profissionais
    GROUP BY profissional_id
    HAVING profissional_id IS NULL OR COUNT(*) > 1

    UNION ALL

    SELECT
        'ID duplicado ou nulo: historico_senioridade',
        COALESCE(historico_id::TEXT, '(NULL)'),
        COUNT(*)
    FROM raw.historico_senioridade
    GROUP BY historico_id
    HAVING historico_id IS NULL OR COUNT(*) > 1

    UNION ALL

    SELECT
        'ID duplicado ou nulo: projetos',
        COALESCE(projeto_id::TEXT, '(NULL)'),
        COUNT(*)
    FROM raw.projetos
    GROUP BY projeto_id
    HAVING projeto_id IS NULL OR COUNT(*) > 1

    UNION ALL

    SELECT
        'ID duplicado ou nulo: participacoes',
        COALESCE(participacao_id::TEXT, '(NULL)'),
        COUNT(*)
    FROM raw.participacoes
    GROUP BY participacao_id
    HAVING participacao_id IS NULL OR COUNT(*) > 1

    UNION ALL

    SELECT
        'Participação repetida por projeto/profissional',
        projeto_id::TEXT || '/' || profissional_id::TEXT,
        COUNT(*)
    FROM raw.participacoes
    GROUP BY projeto_id, profissional_id
    HAVING COUNT(*) > 1
)
SELECT verificacao, registro, ocorrencias
FROM problemas
ORDER BY verificacao, registro;

-- 2. Históricos ou participações que apontam para profissionais
--    ou projetos inexistentes.
SELECT
    'Histórico sem profissional correspondente' AS verificacao,
    h.historico_id::TEXT AS registro
FROM raw.historico_senioridade h
LEFT JOIN raw.profissionais p
    ON p.profissional_id = h.profissional_id
WHERE p.profissional_id IS NULL

UNION ALL

SELECT
    'Participação sem profissional correspondente',
    pa.participacao_id::TEXT
FROM raw.participacoes pa
LEFT JOIN raw.profissionais p
    ON p.profissional_id = pa.profissional_id
WHERE p.profissional_id IS NULL

UNION ALL

SELECT
    'Participação sem projeto correspondente',
    pa.participacao_id::TEXT
FROM raw.participacoes pa
LEFT JOIN raw.projetos pr
    ON pr.projeto_id = pa.projeto_id
WHERE pr.projeto_id IS NULL

ORDER BY verificacao, registro;