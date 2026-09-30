# SQL do projeto

Scripts disponíveis e ordem de execução. Os arquivos 09–13 podem ser executados inteiros no IntelliJ/DataGrip conectado ao banco seniority-analysis ou com psql -v ON_ERROR_STOP=1. Rode um arquivo por vez e pare ao primeiro erro.

## Base original

1. 01_create_tables.sql — cria as tabelas de origem em raw.
2. 02_import_raw.psql — importa e valida os CSVs; interrompe se as tabelas raw já contiverem registros.
3. 03_verificar_qualidade_raw.sql, 04_verificar_periodos_senioridade.sql e 05_verificar_projetos_e_participacoes.sql — consultas de auditoria. Antes de preparar staging, confira os resultados de problema; devem ser vazios.
4. 06_analise_projetos_por_periodo_e_senioridade.sql e 07_volume_participacoes_ajustado.sql — análises com senioridade histórica e denominador mensal.
5. 08_criar_views_analiticas.sql — cria as views atuais sobre raw.

## Nova camada staging

Os arquivos 09 a 13 preparam uma migração aditiva: preservam raw, criam cópias validadas e, somente depois da comparação, apontam as duas views existentes para staging.

| Ordem | Arquivo | Ação |
|---:|---|---|
| 9 | 09_criar_staging.sql | Cria tabelas, chaves, regras locais e índices em staging. Não altera raw. Execute uma vez. |
| 10 | 10_validar_e_carregar_staging.sql | Valida os dados de raw e os copia na mesma transação. Se houver erro ou se a carga já tiver começado, interrompe sem apagar registros. |
| 11 | 11_verificar_staging.sql | Compara conteúdo, contagens, relacionamentos, períodos e views. É somente leitura. Corrija a origem do problema antes de prosseguir. |
| 12 | 12_migrar_views_para_staging.sql | Confere equivalência integral de raw e staging e substitui a origem das views sem mudar nomes ou colunas. Rode só após a etapa 11 sem divergências. |
| 13 | 13_verificar_migracao_staging.sql | Confirma que as views sobre staging continuam iguais ao cálculo feito diretamente de raw. É somente leitura. |

### Regras modeladas em staging

- IDs originais como chaves primárias; nenhuma numeração nova é gerada.
- Histórico ligado a profissionais; participação ligada a profissional e projeto.
- Uma participação por combinação de profissional e projeto.
- Campos textuais obrigatórios não podem ficar vazios; horas devem ser positivas.
- Datas de vigência e de projeto devem ser coerentes.
- As consultas de carga e auditoria verificam relações, lacunas e sobreposições temporais entre linhas.

As tabelas raw continuam sem essas restrições para preservar a origem e permitir análises de qualidade. As views existentes mantêm os mesmos nomes e contratos. A origem delas só muda em 12_migrar_views_para_staging.sql; reexecutar 08_criar_views_analiticas.sql volta a apontá-las para raw.

## Cuidados

- Faça e verifique um backup antes da migração.
- Rode os arquivos 09–13 em ordem, um por vez, e pare em qualquer erro.
- 10_validar_e_carregar_staging.sql é uma carga inicial única. Para refletir futuras mudanças em raw, decida uma rotina de atualização antes de executá-lo de novo; ele recusa duplicar ou substituir staging preenchido.
- Nenhum dos arquivos 09–13 apaga tabelas, linhas ou schemas existentes. O arquivo 12 troca apenas a origem das views analytics.
- Em bancos grandes ou compartilhados, avalie estratégia de backfill, bloqueios e índices antes da aplicação. Este conjunto foi elaborado para o banco local do projeto.
