-- =====================================================================
-- Sistema Web de Registo e Acompanhamento das Condições de Manutenção
-- dos Transportes Semicolectivos (chapas) na Cidade da Beira
-- Ficheiro: 02_manipulacao.sql
-- Pré-requisito: ter executado antes o 01_criacao_e_insercao.sql
-- Para repor os dados originais, volte a executar o 01_criacao_e_insercao.sql
--
-- Em cada comando: o RESULTADO ESPERADO está em comentário.
-- No vídeo: ler o esperado, executar e comparar com o obtido.
-- =====================================================================

USE chapas_beira;

-- =====================================================================
-- A) SELECT SIMPLES (3) - com filtro WHERE e ordenação ORDER BY
-- =====================================================================

-- A1) Reportes ainda abertos, do mais recente para o mais antigo.
-- Útil para o gestor ver o que ainda não foi tratado.
-- ESPERADO: 3 linhas, reportes 20 (2026-10-13), 19 (2026-10-11) e 18 (2026-10-09).
SELECT id_reporte, data_reporte, descricao, estado
FROM reporte
WHERE estado = 'aberto'
ORDER BY data_reporte DESC;

-- A2) Tipos de problema de gravidade alta, por ordem alfabética.
-- ESPERADO: 7 linhas: Cinto de segurança avariado, Luzes avariadas,
-- Piso deteriorado, Pneus gastos, Porta defeituosa, Suspensão avariada
-- e Travões fracos.
SELECT id_tipo, nome, gravidade
FROM tipo_problema
WHERE gravidade = 'alta'
ORDER BY nome ASC;

-- A3) Manutenções concluídas com custo total superior a 8000 MZN,
-- da mais cara para a mais barata.
-- ESPERADO: 3 linhas: manutenção 4 (15800.00), 8 (10400.00) e 5 (9200.00).
-- A manutenção 9 (8000.00) NÃO aparece porque o filtro é "maior que" (>).
SELECT id_manutencao, tipo, data_realizada, custo_total
FROM manutencao
WHERE estado = 'concluida' AND custo_total > 8000
ORDER BY custo_total DESC;

-- =====================================================================
-- B) SELECT COM JOIN (2)
-- =====================================================================

-- B1) Detalhe completo da manutenção 3: viatura, oficina e cada item
-- de intervenção (entidade fraca) com o tipo de problema tratado.
-- Junta 5 tabelas: manutencao, viatura, oficina, item_intervencao e
-- tipo_problema.
-- ESPERADO: 2 linhas (itens 1 e 2), ambas da viatura AFC-323-SF e da
-- oficina "Oficina Macuti Motors":
--   item 1: Substituição do assento do motorista (Assento danificado, 3500.00)
--   item 2: Colagem e reforço dos assentos traseiros (Assento danificado, 2000.00)
SELECT m.id_manutencao,
       v.matricula,
       o.nome AS oficina,
       m.data_realizada,
       i.nr_item,
       i.descricao AS item,
       t.nome AS tipo_problema,
       i.custo
FROM manutencao m
JOIN viatura v          ON v.id_viatura = m.id_viatura
JOIN oficina o          ON o.id_oficina = m.id_oficina
JOIN item_intervencao i ON i.id_manutencao = m.id_manutencao
JOIN tipo_problema t    ON t.id_tipo = i.id_tipo
WHERE m.id_manutencao = 3
ORDER BY i.nr_item;

-- B2) Relatório de viaturas com problemas recorrentes (2 ou mais reportes),
-- com o nome do proprietário.
-- Junta viatura, reporte e proprietario, agrupa por viatura e filtra
-- com HAVING.
-- ESPERADO: 3 linhas:
--   AFC-323-SF | Celeste Isabel Mutemba | 5 reportes
--   AFA-101-SF | Armando Júlio Macamo   | 2 reportes
--   AFE-545-SF | Amélia Rita Sitoe      | 2 reportes
SELECT v.matricula,
       p.nome AS proprietario,
       COUNT(r.id_reporte) AS total_reportes
FROM viatura v
JOIN reporte r       ON r.id_viatura = v.id_viatura
JOIN proprietario p  ON p.id_proprietario = v.id_proprietario
GROUP BY v.id_viatura, v.matricula, p.nome
HAVING COUNT(r.id_reporte) >= 2
ORDER BY total_reportes DESC, v.matricula;

-- =====================================================================
-- C) UPDATE (3, o mínimo da ficha é 2)
-- História: a manutenção 11 (viatura AFJ-989-SF, em curso) termina.
-- =====================================================================

-- C1) Concluir a manutenção 11: estado, data de realização e custo.
-- A data tem de ser >= data agendada (2026-09-22), senão o CHECK recusa.
-- ESPERADO: 1 linha alterada (Rows matched: 1  Changed: 1).
-- Na verificação: estado = concluida, data_realizada = 2026-10-14,
-- custo_total = 6200.00.
UPDATE manutencao
SET estado = 'concluida',
    data_realizada = '2026-10-14',
    custo_total = 6200.00
WHERE id_manutencao = 11;

SELECT id_manutencao, estado, data_agendada, data_realizada, custo_total
FROM manutencao
WHERE id_manutencao = 11;

-- C2) Marcar como resolvidos os reportes ligados à manutenção 11
-- (regra de negócio: ao concluir a manutenção, os reportes ficam resolvidos).
-- ESPERADO: 1 linha alterada (o reporte 12, "Fumo preto excessivo no escape",
-- passa de em_analise para resolvido).
UPDATE reporte
SET estado = 'resolvido'
WHERE id_manutencao = 11;

SELECT id_reporte, descricao, estado, id_manutencao
FROM reporte
WHERE id_manutencao = 11;

-- C3) A viatura volta a circular: passa de em_manutencao para ativa.
-- ESPERADO: 1 linha alterada (viatura 9, matrícula AFJ-989-SF).
UPDATE viatura
SET estado = 'ativa'
WHERE id_viatura = 9;

SELECT id_viatura, matricula, estado
FROM viatura
WHERE id_viatura = 9;

-- =====================================================================
-- D) DELETE (1) - respeitando as chaves estrangeiras
-- =====================================================================

-- D1) Cancelar a manutenção 20 (agendada para 2026-11-10, viatura 18).
-- Só pode ser eliminada porque nenhuma tabela depende dela: não tem itens
-- de intervenção (item_intervencao) nem reportes associados (reporte).
-- Se tivesse, as chaves estrangeiras (ON DELETE RESTRICT) impediriam o
-- DELETE, e seria preciso eliminar primeiro os itens e desassociar os reportes.
-- ESPERADO: 1 linha eliminada. A contagem passa de 20 para 19 manutenções.
SELECT COUNT(*) AS manutencoes_antes FROM manutencao;

DELETE FROM manutencao
WHERE id_manutencao = 20 AND estado = 'agendada';

SELECT COUNT(*) AS manutencoes_depois FROM manutencao;

-- =====================================================================
-- E) TESTE DE INTEGRIDADE (1)
-- Tentar inserir um reporte para uma viatura que NÃO existe (id 999).
-- Deixar este teste por último: o erro é esperado e interrompe o script.
-- =====================================================================

-- ESPERADO: ERRO 1452 (Cannot add or update a child row: a foreign key
-- constraint fails). O MySQL recusa o INSERT porque a coluna id_viatura
-- do reporte é chave estrangeira para viatura(id_viatura) e não existe
-- nenhuma viatura com id 999. Isto garante a integridade referencial:
-- não pode existir um reporte sobre uma viatura inexistente.
-- Nenhuma linha é inserida.
INSERT INTO reporte (data_reporte, descricao, estado, id_utilizador, id_viatura, id_tipo)
VALUES ('2026-10-14', 'Teste: reporte de viatura inexistente', 'aberto', 6, 999, 1);

-- (Opcional, para mostrar também o lado inverso) Tentar eliminar uma viatura
-- que já tem reportes e manutenções:
-- ESPERADO: ERRO 1451 (Cannot delete or update a parent row), porque a
-- viatura 1 é referenciada por reporte e manutencao.
-- DELETE FROM viatura WHERE id_viatura = 1;
