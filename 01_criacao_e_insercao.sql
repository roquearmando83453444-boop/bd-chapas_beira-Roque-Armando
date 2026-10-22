-- =====================================================================
-- Sistema Web de Registo e Acompanhamento das Condições de Manutenção
-- dos Transportes Semicolectivos (chapas) na Cidade da Beira
-- Ficheiro: 01_criacao_e_insercao.sql
-- SGBD: MySQL 8
-- Disciplina: Tecnologias de Base de Dados - 2º ano, Informática
-- Executar de raiz: recria a base de dados e carrega 20 registos por tabela.
-- Nota: nomes, BI, matrículas, telefones e oficinas são fictícios.
-- =====================================================================

DROP DATABASE IF EXISTS chapas_beira;
CREATE DATABASE chapas_beira CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE chapas_beira;

-- =====================================================================
-- PARTE 1: CRIAÇÃO DAS TABELAS
-- Ordem: primeiro as tabelas sem dependências, depois as que têm FK.
-- =====================================================================

CREATE TABLE utilizador (
    id_utilizador INT AUTO_INCREMENT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    telefone      VARCHAR(15),
    senha_hash    VARCHAR(255) NOT NULL,
    perfil        ENUM('passageiro','gestor') NOT NULL,
    data_registo  DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE proprietario (
    id_proprietario INT AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL,
    nr_bi           VARCHAR(20)  NOT NULL UNIQUE,
    telefone        VARCHAR(15)  NOT NULL,
    endereco        VARCHAR(150)
) ENGINE=InnoDB;

CREATE TABLE rota (
    id_rota      INT AUTO_INCREMENT PRIMARY KEY,
    codigo       VARCHAR(10)  NOT NULL UNIQUE,
    origem       VARCHAR(80)  NOT NULL,
    destino      VARCHAR(80)  NOT NULL,
    distancia_km DECIMAL(5,1) NOT NULL,
    CONSTRAINT ck_rota_distancia CHECK (distancia_km > 0)
) ENGINE=InnoDB;

CREATE TABLE tipo_problema (
    id_tipo    INT AUTO_INCREMENT PRIMARY KEY,
    nome       VARCHAR(60) NOT NULL UNIQUE,
    descricao  VARCHAR(200),
    gravidade  ENUM('baixa','media','alta') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE oficina (
    id_oficina  INT AUTO_INCREMENT PRIMARY KEY,
    nome        VARCHAR(80) NOT NULL,
    bairro      VARCHAR(60) NOT NULL,
    telefone    VARCHAR(15),
    responsavel VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE viatura (
    id_viatura      INT AUTO_INCREMENT PRIMARY KEY,
    matricula       VARCHAR(12) NOT NULL UNIQUE,
    marca           VARCHAR(40) NOT NULL,
    modelo          VARCHAR(40) NOT NULL,
    ano_fabrico     SMALLINT    NOT NULL,
    nr_lugares      TINYINT UNSIGNED NOT NULL,
    estado          ENUM('ativa','em_manutencao','inativa') NOT NULL DEFAULT 'ativa',
    id_proprietario INT NOT NULL,
    id_rota         INT NOT NULL,
    CONSTRAINT ck_viatura_ano     CHECK (ano_fabrico BETWEEN 1990 AND 2026),
    CONSTRAINT ck_viatura_lugares CHECK (nr_lugares BETWEEN 8 AND 30),
    CONSTRAINT fk_viatura_proprietario FOREIGN KEY (id_proprietario)
        REFERENCES proprietario(id_proprietario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_viatura_rota FOREIGN KEY (id_rota)
        REFERENCES rota(id_rota)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE manutencao (
    id_manutencao INT AUTO_INCREMENT PRIMARY KEY,
    tipo          ENUM('preventiva','corretiva') NOT NULL,
    data_agendada DATE NOT NULL,
    data_realizada DATE NULL,
    estado        ENUM('agendada','em_curso','concluida') NOT NULL DEFAULT 'agendada',
    custo_total   DECIMAL(10,2) NULL,
    id_viatura    INT NOT NULL,
    id_oficina    INT NOT NULL,
    id_gestor     INT NOT NULL,
    -- Regra 11: a data de realização não pode ser anterior à agendada
    CONSTRAINT ck_manut_datas CHECK (data_realizada IS NULL OR data_realizada >= data_agendada),
    -- Só as manutenções concluídas têm data de realização
    CONSTRAINT ck_manut_estado CHECK (
        (estado = 'concluida' AND data_realizada IS NOT NULL)
        OR (estado <> 'concluida' AND data_realizada IS NULL)),
    CONSTRAINT ck_manut_custo CHECK (custo_total IS NULL OR custo_total >= 0),
    CONSTRAINT fk_manut_viatura FOREIGN KEY (id_viatura)
        REFERENCES viatura(id_viatura)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_manut_oficina FOREIGN KEY (id_oficina)
        REFERENCES oficina(id_oficina)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_manut_gestor FOREIGN KEY (id_gestor)
        REFERENCES utilizador(id_utilizador)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE reporte (
    id_reporte    INT AUTO_INCREMENT PRIMARY KEY,
    data_reporte  DATE NOT NULL,
    descricao     VARCHAR(255) NOT NULL,
    estado        ENUM('aberto','em_analise','resolvido') NOT NULL DEFAULT 'aberto',
    id_utilizador INT NOT NULL,
    id_viatura    INT NOT NULL,
    id_tipo       INT NOT NULL,
    id_manutencao INT NULL,          -- pode ficar vazio até haver manutenção
    CONSTRAINT fk_reporte_utilizador FOREIGN KEY (id_utilizador)
        REFERENCES utilizador(id_utilizador)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reporte_viatura FOREIGN KEY (id_viatura)
        REFERENCES viatura(id_viatura)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reporte_tipo FOREIGN KEY (id_tipo)
        REFERENCES tipo_problema(id_tipo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reporte_manutencao FOREIGN KEY (id_manutencao)
        REFERENCES manutencao(id_manutencao)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ENTIDADE FRACA: o item só existe dentro de uma manutenção.
-- A chave primária é composta: (id_manutencao, nr_item).
CREATE TABLE item_intervencao (
    id_manutencao INT NOT NULL,
    nr_item       TINYINT UNSIGNED NOT NULL,
    descricao     VARCHAR(200) NOT NULL,
    custo         DECIMAL(10,2) NOT NULL,
    estado        ENUM('pendente','feito') NOT NULL DEFAULT 'pendente',
    id_tipo       INT NOT NULL,
    PRIMARY KEY (id_manutencao, nr_item),
    CONSTRAINT ck_item_custo CHECK (custo >= 0),
    CONSTRAINT fk_item_manutencao FOREIGN KEY (id_manutencao)
        REFERENCES manutencao(id_manutencao)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_item_tipo FOREIGN KEY (id_tipo)
        REFERENCES tipo_problema(id_tipo)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- PARTE 2: INSERÇÃO DOS DADOS (20 registos por tabela)
-- Ordem imposta pelas chaves estrangeiras:
-- utilizador, proprietario, rota, tipo_problema, oficina -> viatura
-- -> manutencao -> reporte -> item_intervencao
-- (As senhas estão com SHA2 apenas para a base de dados de teste; no
--  sistema web usar password_hash() do PHP.)
-- =====================================================================

-- 1) UTILIZADOR: ids 1-5 gestores, ids 6-20 passageiros
INSERT INTO utilizador (id_utilizador, nome, email, telefone, senha_hash, perfil, data_registo) VALUES
(1,  'Hélder Augusto Nhamussua', 'helder.nhamussua@chapasbeira.co.mz',  '842110011', SHA2('Senha@2026',256), 'gestor',     '2026-01-05'),
(2,  'Marta Celina Bambo',       'marta.bambo@chapasbeira.co.mz',       '843220022', SHA2('Senha@2026',256), 'gestor',     '2026-01-05'),
(3,  'Ismael Faruk Valy',        'ismael.valy@chapasbeira.co.mz',       '824330033', SHA2('Senha@2026',256), 'gestor',     '2026-01-07'),
(4,  'Cristina Dulce Pinto',     'cristina.pinto@chapasbeira.co.mz',    '865440044', SHA2('Senha@2026',256), 'gestor',     '2026-01-07'),
(5,  'Narciso Jaime Tivane',     'narciso.tivane@chapasbeira.co.mz',    '876550055', SHA2('Senha@2026',256), 'gestor',     '2026-01-12'),
(6,  'Ana Beatriz Langa',        'ana.langa@gmail.com',                 '847660066', SHA2('Senha@2026',256), 'passageiro', '2026-01-20'),
(7,  'Pedro Jaime Sambo',        'pedro.sambo@gmail.com',               '828770077', SHA2('Senha@2026',256), 'passageiro', '2026-01-22'),
(8,  'Rosa Mariana Chale',       'rosa.chale@gmail.com',                '859880088', SHA2('Senha@2026',256), 'passageiro', '2026-01-25'),
(9,  'Tiago Salomão Mauaie',     'tiago.mauaie@gmail.com',              '861990099', SHA2('Senha@2026',256), 'passageiro', '2026-02-02'),
(10, 'Graça Eduarda Nhangumbe',  'graca.nhangumbe@gmail.com',           '872010101', SHA2('Senha@2026',256), 'passageiro', '2026-02-03'),
(11, 'Alberto Simão Cumbe',      'alberto.cumbe@gmail.com',             '843020202', SHA2('Senha@2026',256), 'passageiro', '2026-02-10'),
(12, 'Marisa Cláudia Fumo',      'marisa.fumo@gmail.com',               '824030303', SHA2('Senha@2026',256), 'passageiro', '2026-02-14'),
(13, 'Nelson Bento Dimande',     'nelson.dimande@gmail.com',            '855040404', SHA2('Senha@2026',256), 'passageiro', '2026-02-18'),
(14, 'Ivone Lurdes Cuna',        'ivone.cuna@gmail.com',                '866050505', SHA2('Senha@2026',256), 'passageiro', '2026-02-21'),
(15, 'Fernando Aurélio Mapsanganhe','fernando.mapsanganhe@gmail.com',   '877060606', SHA2('Senha@2026',256), 'passageiro', '2026-02-27'),
(16, 'Lídia Sandra Muianga',     'lidia.muianga@gmail.com',             '848070707', SHA2('Senha@2026',256), 'passageiro', '2026-06-11'),
(17, 'Josefa Amélia Bacar',      'josefa.bacar@gmail.com',              '829080808', SHA2('Senha@2026',256), 'passageiro', '2026-08-04'),
(18, 'Hermenegildo Paulo Guambe','hermenegildo.guambe@gmail.com',       '850090909', SHA2('Senha@2026',256), 'passageiro', '2026-09-01'),
(19, 'Cátia Vanessa Zandamela',  'catia.zandamela@gmail.com',           '861101010', SHA2('Senha@2026',256), 'passageiro', '2026-09-10'),
(20, 'Osvaldo Teodoro Maculuve', 'osvaldo.maculuve@gmail.com',          '872111111', SHA2('Senha@2026',256), 'passageiro', '2026-09-25');

-- 2) PROPRIETARIO
INSERT INTO proprietario (id_proprietario, nome, nr_bi, telefone, endereco) VALUES
(1,  'Armando Júlio Macamo',     '110100234561A', '842201001', 'Bairro da Munhava, Beira'),
(2,  'Celeste Isabel Mutemba',   '110100345672B', '823202002', 'Bairro do Macuti, Beira'),
(3,  'Joaquim Pedro Nhantumbo',  '110100456783C', '854203003', 'Bairro da Manga, Beira'),
(4,  'Amélia Rita Sitoe',        '110100567894D', '865204004', 'Bairro de Matacuane, Beira'),
(5,  'Domingos Alberto Cossa',   '110100678905E', '876205005', 'Bairro da Ndunda, Beira'),
(6,  'Luísa Marta Bila',         '110100789016F', '847206006', 'Bairro de Chaimite, Beira'),
(7,  'Francisco Tomás Matavele', '110100890127G', '828207007', 'Bairro do Esturro, Beira'),
(8,  'Esperança Joana Zimba',    '110100901238H', '859208008', 'Bairro do Goto, Beira'),
(9,  'Abdul Karim Mussagy',      '110101012349J', '860209009', 'Bairro do Maquinino, Beira'),
(10, 'Carlos Eduardo Tembe',     '110101123450K', '871210010', 'Bairro de Inhamízua, Beira'),
(11, 'Ana Paula Mabunda',        '110101234561L', '842211011', 'Bairro de Chingussura, Beira'),
(12, 'Rui Manuel Gomes',         '110101345672M', '823212012', 'Bairro do Vaz, Beira'),
(13, 'Sónia Graça Machava',      '110101456783N', '854213013', 'Bairro do Estoril, Beira'),
(14, 'Eusébio António Mavie',    '110101567894P', '865214014', 'Bairro das Palmeiras, Beira'),
(15, 'Teresa Lúcia Nhamitambo',  '110101678905Q', '876215015', 'Bairro dos Pioneiros, Beira'),
(16, 'Hélio Jorge Muchanga',     '110101789016R', '847216016', 'Bairro de Nhaconjo, Beira'),
(17, 'Benedita Maria Uamusse',   '110101890127S', '828217017', 'Bairro da Mungassa, Beira'),
(18, 'Samuel Pedro Chivambo',    '110101901238T', '859218018', 'Bairro Alto da Manga, Beira'),
(19, 'Zaida Rahima Ismael',      '110102012349U', '860219019', 'Bairro do Matadouro, Beira'),
(20, 'Manuel José Chicote',      '110102123450V', '871220020', 'Bairro de Mascarenhas, Beira');

-- 3) ROTA (distâncias aproximadas)
INSERT INTO rota (id_rota, codigo, origem, destino, distancia_km) VALUES
(1,  'R01', 'Munhava',      'Praça do Município',     8.5),
(2,  'R02', 'Macuti',       'Mercado do Maquinino',   7.0),
(3,  'R03', 'Manga',        'Praça do Município',     6.0),
(4,  'R04', 'Matacuane',    'Hospital Central da Beira', 4.5),
(5,  'R05', 'Ndunda',       'Mercado do Maquinino',   5.5),
(6,  'R06', 'Chaimite',     'Praça do Município',     9.0),
(7,  'R07', 'Esturro',      'Mercado do Maquinino',   4.0),
(8,  'R08', 'Goto',         'Praça do Município',     7.5),
(9,  'R09', 'Maquinino',    'Aeroporto da Beira',    12.0),
(10, 'R10', 'Inhamízua',    'Praça do Município',    14.0),
(11, 'R11', 'Chingussura',  'Mercado do Maquinino',  11.0),
(12, 'R12', 'Vaz',          'Praça do Município',     5.0),
(13, 'R13', 'Estoril',      'Praça do Município',     3.5),
(14, 'R14', 'Palmeiras',    'Mercado do Maquinino',   6.5),
(15, 'R15', 'Pioneiros',    'Praça do Município',     8.0),
(16, 'R16', 'Nhaconjo',     'Estação dos CFM',        7.0),
(17, 'R17', 'Mungassa',     'Mercado do Maquinino',   9.5),
(18, 'R18', 'Alto da Manga','Hospital Central da Beira', 5.0),
(19, 'R19', 'Matadouro',    'Praça do Município',     6.5),
(20, 'R20', 'Mascarenhas',  'Mercado do Maquinino',   8.0);

-- 4) TIPO_PROBLEMA
INSERT INTO tipo_problema (id_tipo, nome, descricao, gravidade) VALUES
(1,  'Assento danificado',        'Assentos rasgados, soltos ou partidos',                 'media'),
(2,  'Falta de limpeza',          'Interior sujo, com lixo ou mau cheiro',                 'baixa'),
(3,  'Porta defeituosa',          'Porta que não abre, não fecha ou encrava',              'alta'),
(4,  'Pneus gastos',              'Pneus carecas ou com cortes',                           'alta'),
(5,  'Travões fracos',            'Travões a chiar ou com pouca eficácia',                 'alta'),
(6,  'Luzes avariadas',           'Faróis ou luzes de travagem sem funcionar',             'alta'),
(7,  'Vidro partido',             'Vidros laterais ou traseiro partidos',                  'media'),
(8,  'Suspensão avariada',        'Viatura balança ou bate em excesso',                    'alta'),
(9,  'Motor com ruído excessivo', 'Ruídos anormais no motor',                              'media'),
(10, 'Fuga de óleo',              'Perda de óleo do motor ou da caixa',                    'media'),
(11, 'Escape com fumo excessivo', 'Fumo preto ou denso no escape',                         'media'),
(12, 'Cinto de segurança avariado','Cintos que não prendem ou estão partidos',             'alta'),
(13, 'Retrovisor partido',        'Espelhos retrovisores partidos ou em falta',            'media'),
(14, 'Bateria fraca',             'Dificuldade em ligar ou falhas elétricas',              'baixa'),
(15, 'Carroçaria danificada',     'Chapa amassada ou enferrujada',                         'baixa'),
(16, 'Limpa pára-brisas avariado','Escovas ou motor do limpa pára-brisas sem funcionar',   'media'),
(17, 'Buzina avariada',           'Buzina sem funcionar',                                  'baixa'),
(18, 'Janela que não abre',       'Janelas encravadas, sem ventilação',                    'baixa'),
(19, 'Piso deteriorado',          'Chão enferrujado, com buracos ou solto',                'alta'),
(20, 'Falta de extintor',         'Viatura sem extintor ou com extintor fora de prazo',    'media');

-- 5) OFICINA
INSERT INTO oficina (id_oficina, nome, bairro, telefone, responsavel) VALUES
(1,  'Auto Beira Serviços',          'Maquinino',    '232300001', 'Abílio Fernandes Zuze'),
(2,  'Mecânica Munhava Lda',         'Munhava',      '232300002', 'Bernardo Salvador Mucavele'),
(3,  'Oficina Macuti Motors',        'Macuti',       '232300003', 'Cláudio Rafael Nhantumbo'),
(4,  'Chaimite Auto-Reparações',     'Chaimite',     '232300004', 'Daniel Joaquim Mabote'),
(5,  'Garagem Ndunda',               'Ndunda',       '232300005', 'Elias Gabriel Cumaio'),
(6,  'Beira Pneus e Travões',        'Manga',        '232300006', 'Filipe Armindo Chitsungo'),
(7,  'Mecânica Central da Beira',    'Esturro',      '232300007', 'Gil Alexandre Mondlane'),
(8,  'Oficina Matacuane',            'Matacuane',    '232300008', 'Horácio Sérgio Tamele'),
(9,  'Auto Elétrica Goto',           'Goto',         '232300009', 'Inácio Moisés Ngovene'),
(10, 'Funilaria e Pintura Estoril',  'Estoril',      '232300010', 'Jorge Luís Massinga'),
(11, 'Oficina Inhamízua',            'Inhamízua',    '232300011', 'Kassamo Yussuf Abdala'),
(12, 'Mecânica Chingussura',         'Chingussura',  '232300012', 'Leonel Anselmo Bila'),
(13, 'Auto Sofala Reparações',       'Vaz',          '232300013', 'Mateus Domingos Cossa'),
(14, 'Oficina Palmeiras',            'Palmeiras',    '232300014', 'Nuno Ricardo Sitoe'),
(15, 'Garagem Pioneiros',            'Pioneiros',    '232300015', 'Óscar Tomé Machaieie'),
(16, 'Mecânica Alto da Manga',       'Alto da Manga','232300016', 'Paulo Vicente Mandlate'),
(17, 'Estofos e Acessórios Beira',   'Matadouro',    '232300017', 'Quitéria Lina Mabjaia'),
(18, 'Auto Peças e Serviços Mungassa','Mungassa',    '232300018', 'Rogério Fidel Chauque'),
(19, 'Oficina Mascarenhas',          'Mascarenhas',  '232300019', 'Sérgio Ismael Tivane'),
(20, 'Mecânica Nhaconjo',            'Nhaconjo',     '232300020', 'Tomás Elídio Nhavoto');

-- 6) VIATURA (depende de proprietario e rota)
INSERT INTO viatura (id_viatura, matricula, marca, modelo, ano_fabrico, nr_lugares, estado, id_proprietario, id_rota) VALUES
(1,  'AFA-101-SF', 'Toyota',     'HiAce',    2012, 15, 'ativa',         1,  1),
(2,  'AFB-212-SF', 'Toyota',     'HiAce',    2014, 15, 'ativa',         1,  2),
(3,  'AFC-323-SF', 'Nissan',     'Caravan',  2010, 14, 'ativa',         2,  3),
(4,  'AFD-434-SF', 'Toyota',     'Quantum',  2016, 16, 'ativa',         3,  4),
(5,  'AFE-545-SF', 'Nissan',     'Urvan',    2011, 14, 'ativa',         4,  5),
(6,  'AFF-656-SF', 'Toyota',     'HiAce',    2015, 15, 'ativa',         5,  6),
(7,  'AFG-767-SF', 'Hyundai',    'H1',       2013, 12, 'ativa',         5,  7),
(8,  'AFH-878-SF', 'Toyota',     'Quantum',  2018, 16, 'ativa',         6,  8),
(9,  'AFJ-989-SF', 'Mitsubishi', 'L300',     2009, 14, 'em_manutencao', 7,  9),
(10, 'AGA-110-SF', 'Toyota',     'HiAce',    2013, 15, 'em_manutencao', 8,  10),
(11, 'AGB-221-SF', 'Nissan',     'Caravan',  2012, 14, 'em_manutencao', 9,  1),
(12, 'AGC-332-SF', 'Toyota',     'HiAce',    2017, 15, 'em_manutencao', 10, 2),
(13, 'AGD-443-SF', 'Toyota',     'Quantum',  2019, 16, 'em_manutencao', 11, 3),
(14, 'AGE-554-SF', 'Nissan',     'Urvan',    2014, 14, 'ativa',         12, 4),
(15, 'AGF-665-SF', 'Toyota',     'HiAce',    2011, 15, 'ativa',         13, 5),
(16, 'AGG-776-SF', 'Hyundai',    'H1',       2016, 12, 'ativa',         14, 11),
(17, 'AGH-887-SF', 'Toyota',     'HiAce',    2010, 15, 'inativa',       15, 12),
(18, 'AGJ-998-SF', 'Toyota',     'Quantum',  2020, 16, 'ativa',         16, 13),
(19, 'AHA-119-SF', 'Nissan',     'Caravan',  2013, 14, 'ativa',         17, 14),
(20, 'AHB-220-SF', 'Toyota',     'HiAce',    2015, 15, 'ativa',         18, 15);

-- 7) MANUTENCAO (depende de viatura, oficina e utilizador gestor)
-- 1-10 concluídas (com custo), 11-15 em curso, 16-20 agendadas
INSERT INTO manutencao (id_manutencao, tipo, data_agendada, data_realizada, estado, custo_total, id_viatura, id_oficina, id_gestor) VALUES
(1,  'corretiva',  '2026-03-10', '2026-03-11', 'concluida',  7300.00, 1,  1,  1),
(2,  'corretiva',  '2026-03-18', '2026-03-18', 'concluida',  3000.00, 2,  2,  2),
(3,  'corretiva',  '2026-04-02', '2026-04-04', 'concluida',  5500.00, 3,  3,  1),
(4,  'preventiva', '2026-04-15', '2026-04-15', 'concluida', 15800.00, 4,  4,  3),
(5,  'corretiva',  '2026-05-06', '2026-05-08', 'concluida',  9200.00, 5,  5,  2),
(6,  'preventiva', '2026-05-20', '2026-05-20', 'concluida',  7000.00, 6,  1,  4),
(7,  'corretiva',  '2026-06-09', '2026-06-10', 'concluida',  5600.00, 3,  6,  1),
(8,  'corretiva',  '2026-06-25', '2026-06-27', 'concluida', 10400.00, 7,  7,  5),
(9,  'preventiva', '2026-07-14', '2026-07-14', 'concluida',  8000.00, 8,  8,  3),
(10, 'corretiva',  '2026-08-05', '2026-08-07', 'concluida',  7700.00, 3,  3,  2),
(11, 'corretiva',  '2026-09-22', NULL, 'em_curso',  NULL, 9,  9,  4),
(12, 'corretiva',  '2026-09-29', NULL, 'em_curso',  NULL, 10, 10, 1),
(13, 'preventiva', '2026-10-05', NULL, 'em_curso',  NULL, 11, 2,  5),
(14, 'corretiva',  '2026-10-08', NULL, 'em_curso',  NULL, 12, 11, 3),
(15, 'corretiva',  '2026-10-12', NULL, 'em_curso',  NULL, 13, 12, 2),
(16, 'preventiva', '2026-10-20', NULL, 'agendada',  NULL, 14, 13, 4),
(17, 'corretiva',  '2026-10-22', NULL, 'agendada',  NULL, 15, 14, 1),
(18, 'preventiva', '2026-10-27', NULL, 'agendada',  NULL, 16, 15, 5),
(19, 'corretiva',  '2026-11-03', NULL, 'agendada',  NULL, 17, 16, 3),
(20, 'preventiva', '2026-11-10', NULL, 'agendada',  NULL, 18, 17, 2);

-- 8) REPORTE (depende de utilizador, viatura, tipo_problema e manutencao)
-- A viatura 3 tem 5 reportes: exemplo de problemas recorrentes.
INSERT INTO reporte (id_reporte, data_reporte, descricao, estado, id_utilizador, id_viatura, id_tipo, id_manutencao) VALUES
(1,  '2026-03-05', 'Dois assentos rasgados com molas expostas',              'resolvido',  6,  1,  1,  1),
(2,  '2026-03-06', 'A porta lateral não fecha completamente',                'resolvido',  7,  1,  3,  1),
(3,  '2026-03-12', 'Interior muito sujo e com mau cheiro',                   'resolvido',  8,  2,  2,  2),
(4,  '2026-03-28', 'Assento do motorista solto',                             'resolvido',  9,  3,  1,  3),
(5,  '2026-03-30', 'Assentos traseiros partidos',                            'resolvido',  10, 3,  1,  3),
(6,  '2026-04-20', 'Faróis dianteiros fracos, má visibilidade à noite',      'resolvido',  11, 5,  6,  5),
(7,  '2026-05-01', 'Vidro lateral partido, entra chuva',                     'resolvido',  12, 5,  7,  5),
(8,  '2026-05-30', 'Porta de correr encrava ao abrir',                       'resolvido',  13, 3,  3,  7),
(9,  '2026-06-02', 'Cintos de segurança não prendem',                        'resolvido',  14, 3,  12, 7),
(10, '2026-06-18', 'A viatura balança muito nas curvas',                     'resolvido',  15, 7,  8,  8),
(11, '2026-07-25', 'Chão enferrujado com buraco junto à porta',              'resolvido',  16, 3,  19, 10),
(12, '2026-09-15', 'Fumo preto excessivo no escape',                         'em_analise', 17, 9,  11, 11),
(13, '2026-09-20', 'Travões a chiar e pedal baixo',                          'em_analise', 18, 10, 5,  12),
(14, '2026-09-27', 'Janela do lado direito não abre',                        'em_analise', 19, 12, 18, 14),
(15, '2026-10-02', 'Espelho retrovisor partido do lado do passageiro',       'em_analise', 20, 13, 13, 15),
(16, '2026-10-06', 'Buzina e luzes de travagem sem funcionar',               'em_analise', 6,  14, 17, 16),
(17, '2026-10-07', 'Não existe extintor visível na viatura',                 'em_analise', 7,  15, 20, 17),
(18, '2026-10-09', 'Pneus carecas, risco em dias de chuva',                  'aberto',     8,  19, 4,  NULL),
(19, '2026-10-11', 'Muita sujidade e lixo no chão da viatura',               'aberto',     9,  20, 2,  NULL),
(20, '2026-10-13', 'Assento ao lado da porta danificado',                    'aberto',     10, 11, 1,  NULL);

-- 9) ITEM_INTERVENCAO (entidade fraca; depende de manutencao e tipo_problema)
-- Cada manutenção concluída (1 a 10) tem 2 itens numerados 1 e 2.
-- O custo_total de cada manutenção é a soma dos seus itens.
INSERT INTO item_intervencao (id_manutencao, nr_item, descricao, custo, estado, id_tipo) VALUES
(1,  1, 'Substituição do estofo de 3 assentos',            4500.00,  'feito', 1),
(1,  2, 'Reparação da dobradiça da porta lateral',         2800.00,  'feito', 3),
(2,  1, 'Limpeza profunda e desinfeção do interior',       1200.00,  'feito', 2),
(2,  2, 'Reparação da fechadura da porta traseira',        1800.00,  'feito', 3),
(3,  1, 'Substituição do assento do motorista',            3500.00,  'feito', 1),
(3,  2, 'Colagem e reforço dos assentos traseiros',        2000.00,  'feito', 1),
(4,  1, 'Troca dos pneus dianteiros',                     12000.00,  'feito', 4),
(4,  2, 'Troca das pastilhas de travão',                   3800.00,  'feito', 5),
(5,  1, 'Substituição dos faróis dianteiros',              5200.00,  'feito', 6),
(5,  2, 'Substituição do vidro lateral partido',           4000.00,  'feito', 7),
(6,  1, 'Revisão do sistema de travagem',                  4500.00,  'feito', 5),
(6,  2, 'Mudança de óleo e filtros',                       2500.00,  'feito', 10),
(7,  1, 'Reparação da porta de correr',                    3200.00,  'feito', 3),
(7,  2, 'Substituição dos cintos de segurança',            2400.00,  'feito', 12),
(8,  1, 'Reparação da suspensão traseira',                 9500.00,  'feito', 8),
(8,  2, 'Substituição do limpa pára-brisas',                900.00,  'feito', 16),
(9,  1, 'Substituição da bateria',                         6500.00,  'feito', 14),
(9,  2, 'Colocação de extintor novo',                      1500.00,  'feito', 20),
(10, 1, 'Reparação do piso deteriorado',                   4200.00,  'feito', 19),
(10, 2, 'Substituição de assento danificado',              3500.00,  'feito', 1);

-- Verificação rápida: deve mostrar 20 em todas as tabelas
SELECT 'utilizador' AS tabela, COUNT(*) AS registos FROM utilizador
UNION ALL SELECT 'proprietario',     COUNT(*) FROM proprietario
UNION ALL SELECT 'rota',             COUNT(*) FROM rota
UNION ALL SELECT 'tipo_problema',    COUNT(*) FROM tipo_problema
UNION ALL SELECT 'oficina',          COUNT(*) FROM oficina
UNION ALL SELECT 'viatura',          COUNT(*) FROM viatura
UNION ALL SELECT 'manutencao',       COUNT(*) FROM manutencao
UNION ALL SELECT 'reporte',          COUNT(*) FROM reporte
UNION ALL SELECT 'item_intervencao', COUNT(*) FROM item_intervencao;
