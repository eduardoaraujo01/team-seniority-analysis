-- Cria a camada validada de staging sem modificar as tabelas raw.
-- Execute uma vez. Se algum objeto já existir, a transação falha e é desfeita.
BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.profissionais (
    profissional_id INTEGER PRIMARY KEY,
    nome TEXT NOT NULL CHECK (btrim(nome) <> ''),
    data_admissao DATE NOT NULL,
    status TEXT NOT NULL CHECK (btrim(status) <> '')
);

CREATE TABLE staging.historico_senioridade (
    historico_id INTEGER PRIMARY KEY,
    profissional_id INTEGER NOT NULL,
    senioridade TEXT NOT NULL
        CHECK (senioridade IN ('Júnior', 'Pleno', 'Sênior')),
    data_inicio DATE NOT NULL,
    data_fim DATE,
    CONSTRAINT fk_staging_historico_profissional
        FOREIGN KEY (profissional_id)
        REFERENCES staging.profissionais (profissional_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_staging_historico_datas
        CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

CREATE TABLE staging.projetos (
    projeto_id INTEGER PRIMARY KEY,
    nome TEXT NOT NULL CHECK (btrim(nome) <> ''),
    data_inicio DATE NOT NULL,
    data_conclusao DATE,
    complexidade TEXT NOT NULL CHECK (btrim(complexidade) <> ''),
    tipo TEXT NOT NULL CHECK (btrim(tipo) <> ''),
    status TEXT NOT NULL CHECK (btrim(status) <> ''),
    CONSTRAINT ck_staging_projeto_datas
        CHECK (data_conclusao IS NULL OR data_conclusao >= data_inicio),
    CONSTRAINT ck_staging_projeto_concluido
        CHECK (status <> 'Concluído' OR data_conclusao IS NOT NULL),
    CONSTRAINT ck_staging_projeto_em_andamento
        CHECK (status <> 'Em andamento' OR data_conclusao IS NULL)
);

CREATE TABLE staging.participacoes (
    participacao_id INTEGER PRIMARY KEY,
    projeto_id INTEGER NOT NULL,
    profissional_id INTEGER NOT NULL,
    papel TEXT NOT NULL CHECK (btrim(papel) <> ''),
    horas NUMERIC(8, 2) NOT NULL CHECK (horas > 0),
    CONSTRAINT fk_staging_participacao_projeto
        FOREIGN KEY (projeto_id)
        REFERENCES staging.projetos (projeto_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_staging_participacao_profissional
        FOREIGN KEY (profissional_id)
        REFERENCES staging.profissionais (profissional_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_staging_participacao_projeto_profissional
        UNIQUE (projeto_id, profissional_id)
);

-- A PK de participação já cria índice com projeto_id como primeira coluna.
-- Este índice adicional atende consultas e joins por profissional.
CREATE INDEX ix_staging_participacoes_profissional
    ON staging.participacoes (profissional_id);

-- A FK de histórico não cria índice automaticamente.
CREATE INDEX ix_staging_historico_profissional
    ON staging.historico_senioridade (profissional_id);

COMMIT;
