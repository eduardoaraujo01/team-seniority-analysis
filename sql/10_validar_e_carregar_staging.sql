-- Valida e carrega os dados de raw em staging em uma única transação.
-- Execute 09_criar_staging.sql antes. Em erro, o PostgreSQL desfaz toda a carga.
-- Este script nunca apaga nem substitui dados existentes em raw ou staging.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE
    staging.profissionais,
    staging.historico_senioridade,
    staging.projetos,
    staging.participacoes
IN EXCLUSIVE MODE;

DO $validacao$
BEGIN
    IF EXISTS (SELECT 1 FROM staging.profissionais)
       OR EXISTS (SELECT 1 FROM staging.historico_senioridade)
       OR EXISTS (SELECT 1 FROM staging.projetos)
       OR EXISTS (SELECT 1 FROM staging.participacoes) THEN
        RAISE EXCEPTION
            'staging já tem dados. Carga repetida ou parcial interrompida sem apagar registros.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM raw.profissionais
        WHERE profissional_id IS NULL
           OR nome IS NULL OR btrim(nome) = ''
           OR data_admissao IS NULL
           OR status IS NULL OR btrim(status) = ''
    ) OR EXISTS (
        SELECT profissional_id FROM raw.profissionais
        GROUP BY profissional_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Profissionais: ID ausente/duplicado ou campo obrigatório inválido.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM raw.projetos
        WHERE projeto_id IS NULL
           OR nome IS NULL OR btrim(nome) = ''
           OR data_inicio IS NULL
           OR complexidade IS NULL OR btrim(complexidade) = ''
           OR tipo IS NULL OR btrim(tipo) = ''
           OR status IS NULL OR btrim(status) = ''
           OR (data_conclusao IS NOT NULL AND data_conclusao < data_inicio)
           OR (status = 'Concluído' AND data_conclusao IS NULL)
           OR (status = 'Em andamento' AND data_conclusao IS NOT NULL)
    ) OR EXISTS (
        SELECT projeto_id FROM raw.projetos
        GROUP BY projeto_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Projetos: ID, campos obrigatórios, status ou datas inválidos.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM raw.historico_senioridade
        WHERE historico_id IS NULL
           OR profissional_id IS NULL
           OR senioridade IS NULL
           OR senioridade NOT IN ('Júnior', 'Pleno', 'Sênior')
           OR data_inicio IS NULL
           OR (data_fim IS NOT NULL AND data_fim < data_inicio)
    ) OR EXISTS (
        SELECT historico_id FROM raw.historico_senioridade
        GROUP BY historico_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Histórico: IDs, senioridade ou datas inválidas.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM raw.participacoes
        WHERE participacao_id IS NULL
           OR projeto_id IS NULL
           OR profissional_id IS NULL
           OR papel IS NULL OR btrim(papel) = ''
           OR horas IS NULL OR horas <= 0
    ) OR EXISTS (
        SELECT participacao_id FROM raw.participacoes
        GROUP BY participacao_id HAVING count(*) > 1
    ) OR EXISTS (
        SELECT projeto_id, profissional_id
        FROM raw.participacoes
        GROUP BY projeto_id, profissional_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Participações: ID, referência, papel, horas ou combinação duplicada inválidos.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM raw.historico_senioridade h
        LEFT JOIN raw.profissionais p USING (profissional_id)
        WHERE p.profissional_id IS NULL
    ) OR EXISTS (
        SELECT 1 FROM raw.participacoes pa
        LEFT JOIN raw.profissionais p USING (profissional_id)
        LEFT JOIN raw.projetos pr USING (projeto_id)
        WHERE p.profissional_id IS NULL OR pr.projeto_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Há histórico ou participação que referencia uma entidade inexistente.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM raw.profissionais p
        LEFT JOIN raw.historico_senioridade h USING (profissional_id)
        WHERE h.historico_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Há profissional sem histórico de senioridade.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM raw.historico_senioridade h
        JOIN raw.profissionais p USING (profissional_id)
        WHERE h.data_inicio < p.data_admissao
    ) THEN
        RAISE EXCEPTION 'Há histórico de senioridade anterior à admissão do profissional.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM raw.participacoes pa
        JOIN raw.projetos pr USING (projeto_id)
        JOIN raw.profissionais p USING (profissional_id)
        WHERE pr.data_inicio < p.data_admissao
           OR (pr.data_conclusao IS NOT NULL
               AND pr.data_conclusao < p.data_admissao)
    ) THEN
        RAISE EXCEPTION 'Há projeto relacionado a uma participação anterior à admissão.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT profissional_id, data_inicio, data_fim,
                   lead(data_inicio) OVER (
                       PARTITION BY profissional_id
                       ORDER BY data_inicio, historico_id
                   ) AS proxima_data_inicio
            FROM raw.historico_senioridade
        ) periodos
        WHERE proxima_data_inicio IS NOT NULL
          AND (data_fim IS NULL OR data_fim <> proxima_data_inicio - 1)
    ) THEN
        RAISE EXCEPTION 'O histórico tem períodos sobrepostos ou lacunas entre registros.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM raw.participacoes pa
        JOIN raw.projetos pr USING (projeto_id)
        LEFT JOIN raw.historico_senioridade h
          ON h.profissional_id = pa.profissional_id
         AND h.data_inicio <= pr.data_conclusao
         AND (h.data_fim IS NULL OR h.data_fim >= pr.data_conclusao)
        WHERE pr.status = 'Concluído'
        GROUP BY pa.participacao_id
        HAVING count(h.historico_id) <> 1
    ) THEN
        RAISE EXCEPTION 'Participação concluída sem exatamente uma senioridade na data de conclusão.';
    END IF;
END
$validacao$;

INSERT INTO staging.profissionais
    (profissional_id, nome, data_admissao, status)
SELECT profissional_id, nome, data_admissao, status
FROM raw.profissionais
ORDER BY profissional_id;

INSERT INTO staging.projetos
    (projeto_id, nome, data_inicio, data_conclusao, complexidade, tipo, status)
SELECT projeto_id, nome, data_inicio, data_conclusao, complexidade, tipo, status
FROM raw.projetos
ORDER BY projeto_id;

INSERT INTO staging.historico_senioridade
    (historico_id, profissional_id, senioridade, data_inicio, data_fim)
SELECT historico_id, profissional_id, senioridade, data_inicio, data_fim
FROM raw.historico_senioridade
ORDER BY historico_id;

INSERT INTO staging.participacoes
    (participacao_id, projeto_id, profissional_id, papel, horas)
SELECT participacao_id, projeto_id, profissional_id, papel, horas
FROM raw.participacoes
ORDER BY participacao_id;

ANALYZE staging.profissionais;
ANALYZE staging.historico_senioridade;
ANALYZE staging.projetos;
ANALYZE staging.participacoes;

SELECT 'profissionais' AS tabela, count(*) AS registros FROM staging.profissionais
UNION ALL SELECT 'historico_senioridade', count(*) FROM staging.historico_senioridade
UNION ALL SELECT 'projetos', count(*) FROM staging.projetos
UNION ALL SELECT 'participacoes', count(*) FROM staging.participacoes
ORDER BY tabela;

COMMIT;
