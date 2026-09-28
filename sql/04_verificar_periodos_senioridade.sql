-- Valida a continuidade do histórico de senioridade por profissional.
-- Execute depois de importar os CSVs e conferir as chaves e referências.
--
-- Esta consulta procura:
--   1. profissionais sem nenhum registro de histórico;
--   2. históricos cujo primeiro período não começa em 2021-01-01;
--   3. datas de início ausentes ou períodos com data final anterior à inicial;
--   4. lacunas ou sobreposições entre períodos consecutivos;
--   5. períodos finais fechados, embora o histórico deva continuar aberto.
--
-- Resultado esperado: nenhuma linha. Isso indica que não foram encontradas
-- ocorrências nos critérios acima; não valida outras regras, como senioridade
-- na data de conclusão de cada projeto.

WITH periodos_ordenados AS (
    SELECT
        h.historico_id,
        h.profissional_id,
        h.data_inicio,
        h.data_fim,
        ROW_NUMBER() OVER (
            PARTITION BY h.profissional_id
            ORDER BY h.data_inicio, h.historico_id
        ) AS ordem,
        COUNT(*) OVER (
            PARTITION BY h.profissional_id
        ) AS total_periodos,
        LAG(h.data_fim) OVER (
            PARTITION BY h.profissional_id
            ORDER BY h.data_inicio, h.historico_id
        ) AS fim_anterior,
        LEAD(h.data_inicio) OVER (
            PARTITION BY h.profissional_id
            ORDER BY h.data_inicio, h.historico_id
        ) AS proximo_inicio
    FROM raw.historico_senioridade h
),
problemas AS (
    SELECT
        'Profissional sem histórico de senioridade' AS verificacao,
        p.profissional_id::TEXT AS registro
    FROM raw.profissionais p
    LEFT JOIN raw.historico_senioridade h
        ON h.profissional_id = p.profissional_id
    WHERE h.historico_id IS NULL

    UNION ALL

    SELECT
        'Primeiro período não começa em 2021-01-01',
        profissional_id::TEXT
    FROM periodos_ordenados
    WHERE ordem = 1
      AND data_inicio IS DISTINCT FROM DATE '2021-01-01'

    UNION ALL

    SELECT
        'Período inválido, com lacuna ou sobreposição',
        profissional_id::TEXT || ' / histórico ' || historico_id::TEXT
    FROM periodos_ordenados
    WHERE data_inicio IS NULL
       OR (
            data_fim IS NOT NULL
            AND data_fim < data_inicio
       )
       OR (
            ordem > 1
            AND fim_anterior IS DISTINCT FROM data_inicio - 1
       )
       OR (
            ordem < total_periodos
            AND data_fim IS DISTINCT FROM proximo_inicio - 1
       )
       OR (
            ordem = total_periodos
            AND data_fim IS NOT NULL
       )
)
SELECT verificacao, registro
FROM problemas
ORDER BY verificacao, registro;
