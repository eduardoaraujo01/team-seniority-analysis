-- Cria views analíticas separadas das tabelas de origem no schema raw.
-- Execute somente depois de concluir as validações dos dados.
--
-- As views apresentam duas classificações distintas:
--   1. senioridade histórica: vigente para o profissional na conclusão do projeto;
--   2. senioridade na data de corte: vigente em 30/06/2026.
--
-- A segunda view reclassifica as participações concluídas pela senioridade que
-- cada profissional tinha na data de corte. Ela serve para uma comparação
-- descritiva e não altera a classificação histórica da primeira view.
-- As tabelas raw não são modificadas por este arquivo.

CREATE SCHEMA IF NOT EXISTS analytics;

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
FROM raw.projetos pr
JOIN raw.participacoes pa
    ON pa.projeto_id = pr.projeto_id
JOIN raw.historico_senioridade h
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
FROM raw.projetos pr
JOIN raw.participacoes pa
    ON pa.projeto_id = pr.projeto_id
JOIN raw.historico_senioridade h
    ON h.profissional_id = pa.profissional_id
   AND h.data_inicio <= DATE '2026-06-30'
   AND (h.data_fim IS NULL OR h.data_fim >= DATE '2026-06-30')
WHERE pr.status = 'Concluído'
  AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30';

-- Após criar as views, compare as contagens: as três devem ser iguais.
-- A quantidade exata depende dos profissionais associados a projetos concluídos.
SELECT
    'participacoes_em_projetos_concluidos' AS view_analitica,
    COUNT(DISTINCT pa.participacao_id) AS registros
FROM raw.projetos pr
JOIN raw.participacoes pa
    ON pa.projeto_id = pr.projeto_id
WHERE pr.status = 'Concluído'
  AND pr.data_conclusao BETWEEN DATE '2021-01-01' AND DATE '2026-06-30'

UNION ALL

SELECT 'senioridade_historica', COUNT(*)
FROM analytics.vw_participacoes_senioridade_historica

UNION ALL

SELECT 'senioridade_data_corte', COUNT(*)
FROM analytics.vw_participacoes_senioridade_data_corte;
