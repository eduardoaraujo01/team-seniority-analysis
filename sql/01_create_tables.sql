CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.profissionais (
                                                 profissional_id INTEGER,
                                                 nome TEXT,
                                                 data_admissao DATE,
                                                 status TEXT
);

CREATE TABLE IF NOT EXISTS raw.historico_senioridade (
                                                         historico_id INTEGER,
                                                         profissional_id INTEGER,
                                                         senioridade TEXT,
                                                         data_inicio DATE,
                                                         data_fim DATE
);

CREATE TABLE IF NOT EXISTS raw.projetos (
                                            projeto_id INTEGER,
                                            nome TEXT,
                                            data_inicio DATE,
                                            data_conclusao DATE,
                                            complexidade TEXT,
                                            tipo TEXT,
                                            status TEXT
);

CREATE TABLE IF NOT EXISTS raw.participacoes (
                                                 participacao_id INTEGER,
                                                 projeto_id INTEGER,
                                                 profissional_id INTEGER,
                                                 papel TEXT,
                                                 horas NUMERIC(8, 2)
    );