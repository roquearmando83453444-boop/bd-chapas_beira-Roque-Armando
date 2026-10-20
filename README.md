# bd-chapas_beira-Roque-Armando
**Nome:** [Roque Armando Mauricio]
**Curso / Disciplina:** Licenciatura em Informática, 2º ano, Tecnologias de Base de Dados
**Tema:** Sistema Web de Registo e Acompanhamento das Condições de Manutenção dos Transportes Semicolectivos (chapas) na Cidade da Beira
**SGBD:** MySQL
link de reportagem como fonte de Motivação: https://youtu.be/f_f-cJcEQ24?si=_qNbuAtyF6R_G7D7
---

## 1. Descrição do problema

Na cidade da Beira, os transportes semicolectivos de passageiros, conhecidos como chapas, são o meio de deslocação diário de milhares de pessoas. Muitas viaturas circulam com problemas visíveis: assentos danificados, portas que não fecham bem, falta de limpeza e outras avarias. Estes problemas são sentidos pelos passageiros, mas raramente ficam registados de forma organizada, e os proprietários e gestores têm dificuldade em saber que viaturas precisam de intervenção, o que já foi reparado e que viaturas têm problemas que se repetem.

Este projeto propõe uma base de dados para registar e acompanhar as condições de manutenção dos chapas. Cada viatura pertence a um proprietário e opera numa rota. Os passageiros registados podem submeter reportes sobre uma viatura, indicando o tipo de problema e uma descrição. Os gestores analisam os reportes e agendam manutenções, associando a viatura a uma oficina. Cada manutenção é composta por vários itens de intervenção (por exemplo, trocar um assento, reparar a porta), cada um com o seu custo e estado. Quando a manutenção é concluída, os reportes associados passam a resolvidos.

O sistema permitirá consultar o histórico de reportes e de manutenções de cada viatura, listar as manutenções agendadas e identificar as viaturas com problemas recorrentes, apoiando as decisões dos gestores e proprietários.

**Sistema web previsto (Programação Web):** aplicação em PHP, MySQL e Bootstrap com dois perfis de utilizador. O *passageiro* regista-se, inicia sessão e submete reportes através de um formulário, podendo consultar o estado dos seus reportes. O *gestor* inicia sessão, lista e pesquisa reportes e viaturas, altera o estado dos reportes, agenda e regista manutenções com os respetivos itens, elimina registos indevidos e consulta relatórios de viaturas com problemas recorrentes.

---

## 2. Regras de negócio

1. Cada viatura tem uma matrícula única e pertence a um só proprietário.
2. Um proprietário pode ter várias viaturas.
3. Cada viatura opera numa só rota; uma rota pode ter várias viaturas.
4. Só utilizadores registados podem submeter reportes.
5. Cada utilizador tem um único perfil: passageiro ou gestor.
6. O email de cada utilizador é único.
7. Cada reporte refere-se a uma só viatura e a um só tipo de problema.
8. Um reporte tem um estado: aberto, em análise ou resolvido.
9. Só utilizadores com perfil de gestor podem registar manutenções.
10. Cada manutenção é feita a uma só viatura, numa só oficina, e pode ser preventiva ou corretiva.
11. A data de realização de uma manutenção não pode ser anterior à data agendada.
12. Uma manutenção pode ter vários itens de intervenção, registados à medida que o trabalho é diagnosticado e executado (uma manutenção agendada ainda pode não ter itens); cada item é numerado dentro da sua manutenção (nr_item) e não existe sem ela.
13. Cada item de intervenção trata de um tipo de problema.
14. Um reporte pode ser associado a uma manutenção; uma manutenção pode resolver vários reportes. Manutenções preventivas podem não ter reportes associados.
15. Não é possível eliminar uma manutenção sem antes eliminar os seus itens de intervenção e desassociar os reportes.

---

## 3. Conteúdo do repositório

| Ficheiro | Descrição |
|---|---|
| `README.md` | Este documento |
| `diagrama_er.png` | Diagrama Entidade-Relacionamento |
| `modelo_relacional.md` | Modelo relacional (tabelas, chaves primárias e estrangeiras) |
| `01_criacao_e_insercao.sql` | Criação da base de dados, tabelas e inserção dos registos |
| `02_manipulacao.sql` | SELECT, JOIN, UPDATE, DELETE e teste de integridade |
