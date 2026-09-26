import csv
import random
from datetime import date, timedelta
from pathlib import Path


# O mesmo seed produz os mesmos CSVs em cada execução.
SEED = 20260630

DATA_INICIAL = date(2021, 1, 1)
DATA_CORTE = date(2026, 6, 30)

DIRETORIO_PROJETO = Path(__file__).resolve().parents[1]
DIRETORIO_DADOS = DIRETORIO_PROJETO / "data"

NOMES = [
    "Ana Martins",
    "Bruno Costa",
    "Carla Oliveira",
    "Diego Almeida",
    "Elisa Ferreira",
    "Felipe Santos",
    "Giovana Rocha",
    "Heitor Lima",
    "Isabela Nunes",
    "João Carvalho",
]

SENIORIDADES = {
    1: [
        (date(2021, 1, 1), "Júnior"),
        (date(2022, 7, 1), "Pleno"),
        (date(2025, 1, 1), "Sênior"),
    ],
    2: [
        (date(2021, 1, 1), "Júnior"),
        (date(2024, 1, 1), "Pleno"),
    ],
    3: [
        (date(2021, 1, 1), "Pleno"),
        (date(2023, 7, 1), "Sênior"),
    ],
    4: [
        (date(2021, 1, 1), "Júnior"),
    ],
    5: [
        (date(2021, 1, 1), "Pleno"),
        (date(2025, 1, 1), "Sênior"),
    ],
    6: [
        (date(2021, 1, 1), "Sênior"),
    ],
    7: [
        (date(2021, 1, 1), "Júnior"),
        (date(2023, 1, 1), "Pleno"),
    ],
    8: [
        (date(2021, 1, 1), "Pleno"),
    ],
    9: [
        (date(2021, 1, 1), "Júnior"),
        (date(2022, 7, 1), "Pleno"),
        (date(2026, 1, 1), "Sênior"),
    ],
    10: [
        (date(2021, 1, 1), "Sênior"),
    ],
}

TIPOS_PROJETO = [
    "Projeto de cliente",
    "Projeto interno",
    "Melhoria",
    "Integração",
]

COMPLEXIDADES = ["Baixa", "Média", "Alta"]

PAPEIS = [
    "Desenvolvedor",
    "Analista",
    "Líder Técnico",
    "Apoio Técnico",
]


def data_aleatoria(gerador, inicio, fim):
    """Retorna uma data aleatória entre inicio e fim, inclusive."""
    dias_disponiveis = (fim - inicio).days
    return inicio + timedelta(days=gerador.randint(0, dias_disponiveis))


def criar_profissionais():
    profissionais = []

    for profissional_id, nome in enumerate(NOMES, start=1):
        # Todos já faziam parte da equipe no início da análise.
        data_admissao = date(2019, 1, 1) + timedelta(
            days=(profissional_id - 1) * 35
        )

        profissionais.append(
            {
                "profissional_id": profissional_id,
                "nome": nome,
                "data_admissao": data_admissao,
                "status": "Ativo",
            }
        )

    return profissionais


def criar_historico_senioridade():
    historico = []

    for profissional_id, trajetoria in SENIORIDADES.items():
        for indice, (data_inicio, senioridade) in enumerate(trajetoria):
            proxima_data_inicio = (
                trajetoria[indice + 1][0]
                if indice + 1 < len(trajetoria)
                else None
            )

            # O fim é inclusivo: o próximo período começa no dia seguinte.
            data_fim = (
                proxima_data_inicio - timedelta(days=1)
                if proxima_data_inicio
                else None
            )

            historico.append(
                {
                    "historico_id": len(historico) + 1,
                    "profissional_id": profissional_id,
                    "senioridade": senioridade,
                    "data_inicio": data_inicio,
                    "data_fim": data_fim,
                }
            )

    return historico


def novo_projeto(gerador, projeto_id, data_inicio, data_conclusao, status):
    return {
        "projeto_id": projeto_id,
        "nome": f"Projeto {projeto_id:03d}",
        "data_inicio": data_inicio,
        "data_conclusao": data_conclusao,
        "complexidade": gerador.choice(COMPLEXIDADES),
        "tipo": gerador.choice(TIPOS_PROJETO),
        "status": status,
    }


def criar_projetos(gerador):
    projetos = []
    projeto_id = 1

    # 36 projetos concluídos em cada ano completo: 2021 a 2025.
    for ano in range(2021, 2026):
        inicio_do_ano = date(ano, 1, 1)
        primeiro_dia_de_conclusao = date(ano, 1, 16)
        fim_do_ano = date(ano, 12, 31)

        for _ in range(36):
            data_conclusao = data_aleatoria(
                gerador,
                primeiro_dia_de_conclusao,
                fim_do_ano,
            )

            duracao_maxima = min(
                120,
                (data_conclusao - inicio_do_ano).days,
            )
            duracao = gerador.randint(15, duracao_maxima)
            data_inicio = data_conclusao - timedelta(days=duracao)

            projetos.append(
                novo_projeto(
                    gerador,
                    projeto_id,
                    data_inicio,
                    data_conclusao,
                    "Concluído",
                )
            )
            projeto_id += 1

    # 30 projetos concluídos no primeiro semestre de 2026.
    for _ in range(30):
        data_inicio = data_aleatoria(
            gerador,
            date(2026, 1, 1),
            date(2026, 5, 31),
        )

        primeira_conclusao_possivel = data_inicio + timedelta(days=15)
        data_conclusao = data_aleatoria(
            gerador,
            primeira_conclusao_possivel,
            DATA_CORTE,
        )

        projetos.append(
            novo_projeto(
                gerador,
                projeto_id,
                data_inicio,
                data_conclusao,
                "Concluído",
            )
        )
        projeto_id += 1

    # 10 projetos em andamento na data de corte.
    for _ in range(10):
        data_inicio = data_aleatoria(
            gerador,
            date(2026, 1, 1),
            DATA_CORTE,
        )

        projetos.append(
            novo_projeto(
                gerador,
                projeto_id,
                data_inicio,
                None,
                "Em andamento",
            )
        )
        projeto_id += 1

    return projetos


def criar_participacoes(gerador, projetos):
    participacoes = []

    for projeto in projetos:
        quantidade_profissionais = gerador.randint(2, 4)
        profissionais_escolhidos = gerador.sample(
            range(1, len(NOMES) + 1),
            quantidade_profissionais,
        )

        for profissional_id in sorted(profissionais_escolhidos):
            participacoes.append(
                {
                    "participacao_id": len(participacoes) + 1,
                    "projeto_id": projeto["projeto_id"],
                    "profissional_id": profissional_id,
                    "papel": gerador.choice(PAPEIS),
                    "horas": round(gerador.uniform(24, 240), 2),
                }
            )

    return participacoes


def senioridade_na_data(historico, profissional_id, data_referencia):
    return [
        linha
        for linha in historico
        if linha["profissional_id"] == profissional_id
        and linha["data_inicio"] <= data_referencia
        and (
            linha["data_fim"] is None
            or data_referencia <= linha["data_fim"]
        )
    ]


def validar_dados(profissionais, historico, projetos, participacoes):
    if len(profissionais) != 10:
        raise ValueError("A base deve conter exatamente 10 profissionais.")

    if len(projetos) != 220:
        raise ValueError("A base deve conter exatamente 220 projetos.")

    ids_profissionais = {p["profissional_id"] for p in profissionais}
    ids_projetos = {p["projeto_id"] for p in projetos}

    if len(ids_profissionais) != len(profissionais):
        raise ValueError("Há IDs de profissionais duplicados.")

    if len(ids_projetos) != len(projetos):
        raise ValueError("Há IDs de projetos duplicados.")

    # Confere continuidade dos períodos de senioridade.
    for profissional_id in ids_profissionais:
        periodos = sorted(
            [
                linha
                for linha in historico
                if linha["profissional_id"] == profissional_id
            ],
            key=lambda linha: linha["data_inicio"],
        )

        if not periodos or periodos[0]["data_inicio"] != DATA_INICIAL:
            raise ValueError(
                f"Histórico incompleto para o profissional {profissional_id}."
            )

        for indice, periodo in enumerate(periodos):
            proximo_periodo = (
                periodos[indice + 1]
                if indice + 1 < len(periodos)
                else None
            )

            if proximo_periodo:
                fim_esperado = (
                    proximo_periodo["data_inicio"] - timedelta(days=1)
                )
                if periodo["data_fim"] != fim_esperado:
                    raise ValueError(
                        "Há lacuna ou sobreposição no histórico do "
                        f"profissional {profissional_id}."
                    )
            elif periodo["data_fim"] is not None:
                raise ValueError(
                    "O último período de senioridade deve ter data_fim vazia."
                )

        senioridade_atual = senioridade_na_data(
            historico,
            profissional_id,
            DATA_CORTE,
        )
        if len(senioridade_atual) != 1:
            raise ValueError(
                "Deve haver exatamente uma senioridade na data de corte "
                f"para o profissional {profissional_id}."
            )

    projetos_por_id = {p["projeto_id"]: p for p in projetos}
    combinacoes = set()

    for projeto in projetos:
        if projeto["status"] == "Concluído":
            if projeto["data_conclusao"] is None:
                raise ValueError(
                    f"O projeto {projeto['projeto_id']} está concluído "
                    "sem data de conclusão."
                )

            if not (
                projeto["data_inicio"]
                <= projeto["data_conclusao"]
                <= DATA_CORTE
            ):
                raise ValueError(
                    f"Datas inválidas no projeto {projeto['projeto_id']}."
                )
        elif projeto["status"] == "Em andamento":
            if projeto["data_conclusao"] is not None:
                raise ValueError(
                    f"O projeto em andamento {projeto['projeto_id']} "
                    "não deve ter data de conclusão."
                )
        else:
            raise ValueError(
                f"Status inválido no projeto {projeto['projeto_id']}."
            )

    for participacao in participacoes:
        projeto_id = participacao["projeto_id"]
        profissional_id = participacao["profissional_id"]
        combinacao = (projeto_id, profissional_id)

        if projeto_id not in ids_projetos:
            raise ValueError(f"Projeto inexistente: {projeto_id}.")

        if profissional_id not in ids_profissionais:
            raise ValueError(f"Profissional inexistente: {profissional_id}.")

        if combinacao in combinacoes:
            raise ValueError(
                "Participação duplicada para o mesmo projeto e profissional."
            )
        combinacoes.add(combinacao)

        if participacao["horas"] <= 0:
            raise ValueError("As horas devem ser maiores que zero.")

        projeto = projetos_por_id[projeto_id]

        # Só projetos concluídos têm data de referência para senioridade.
        if projeto["status"] == "Concluído":
            senioridade_valida = senioridade_na_data(
                historico,
                profissional_id,
                projeto["data_conclusao"],
            )
            if len(senioridade_valida) != 1:
                raise ValueError(
                    "Não foi encontrada exatamente uma senioridade para "
                    f"a participação {participacao['participacao_id']}."
                )


def valor_csv(valor):
    if valor is None:
        return ""

    if isinstance(valor, date):
        return valor.isoformat()

    if isinstance(valor, float):
        return f"{valor:.2f}"

    return str(valor)


def salvar_csv(nome_arquivo, colunas, linhas):
    caminho = DIRETORIO_DADOS / nome_arquivo

    with caminho.open("w", newline="", encoding="utf-8") as arquivo:
        escritor = csv.DictWriter(
            arquivo,
            fieldnames=colunas,
            lineterminator="\n",
        )
        escritor.writeheader()

        for linha in linhas:
            escritor.writerow(
                {
                    coluna: valor_csv(linha[coluna])
                    for coluna in colunas
                }
            )

    print(f"Gerado: {caminho.relative_to(DIRETORIO_PROJETO)} "
          f"({len(linhas)} linhas)")


def main():
    gerador = random.Random(SEED)

    profissionais = criar_profissionais()
    historico = criar_historico_senioridade()
    projetos = criar_projetos(gerador)
    participacoes = criar_participacoes(gerador, projetos)

    validar_dados(
        profissionais,
        historico,
        projetos,
        participacoes,
    )

    DIRETORIO_DADOS.mkdir(parents=True, exist_ok=True)

    salvar_csv(
        "profissionais.csv",
        ["profissional_id", "nome", "data_admissao", "status"],
        profissionais,
    )

    salvar_csv(
        "historico_senioridade.csv",
        [
            "historico_id",
            "profissional_id",
            "senioridade",
            "data_inicio",
            "data_fim",
        ],
        historico,
    )

    salvar_csv(
        "projetos.csv",
        [
            "projeto_id",
            "nome",
            "data_inicio",
            "data_conclusao",
            "complexidade",
            "tipo",
            "status",
        ],
        projetos,
    )

    salvar_csv(
        "participacoes.csv",
        [
            "participacao_id",
            "projeto_id",
            "profissional_id",
            "papel",
            "horas",
        ],
        participacoes,
    )

    print("\nValidação do gerador concluída.")
    print(f"Data de corte: {DATA_CORTE.isoformat()}")
    print(f"Participações geradas: {len(participacoes)}")


if __name__ == "__main__":
    main()