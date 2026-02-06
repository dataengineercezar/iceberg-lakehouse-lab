# 🧊 Iceberg Lakehouse Lab

Repositório hands-on para exploração avançada do **Apache Iceberg** em arquitetura **Data Lakehouse**, utilizando **AWS (S3, Glue Catalog, Athena)** e ambiente local com **Docker + Spark**.

Demonstra domínio em operações avançadas de Iceberg: **Time Travel**, **Schema Evolution**, **Partition Evolution**, **ACID Transactions** e **Snapshot Management** — todas validadas em ambiente real AWS.

---

## 📦 Stack Tecnológica

| Tecnologia | Versão | Papel |
|---|---|---|
| Apache Iceberg | 1.7.1 | Formato de tabela open-source para Data Lakehouse |
| Apache Spark | 3.5.3 | Engine de processamento distribuído (PySpark) |
| AWS S3 | — | Armazenamento do Data Lake (warehouse) |
| AWS Glue Data Catalog | — | Catálogo centralizado de metadados |
| AWS Athena | v3 | Consultas SQL serverless sobre tabelas Iceberg |
| Docker + Compose | — | Ambiente local reprodutível |
| Python | 3.8+ | Linguagem principal (PySpark) |
| Git | — | Versionamento com commits semânticos |

---

## 🗂️ Estrutura do Repositório

```
iceberg-lakehouse-lab/
├── docker/                    # Infraestrutura local
│   ├── docker-compose.yml     # Orquestração do container Spark
│   └── spark/
│       └── Dockerfile         # Spark 3.5.3 + Iceberg 1.7.1 + AWS JARs
├── src/
│   ├── ingestion/             # Scripts de ingestão (camada Bronze)
│   ├── transformations/       # Transformações (camada Silver/Gold)
│   └── queries/
│       ├── athena_queries.sql       # Queries Athena (serverless)
│       └── iceberg_advanced_ops.sql # Time Travel, Schema/Partition Evolution
├── data/
│   └── raw/                   # Dados de exemplo para testes locais
├── docs/
│   ├── architecture.md        # Arquitetura do Lakehouse (diagramas)
│   ├── iceberg-concepts.md    # Guia conceitual profundo de Iceberg
│   └── aws-setup.md           # Configuração AWS (S3, Glue, Athena, IAM)
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start

### Pré-requisitos

- Docker e Docker Compose
- AWS CLI configurado (`aws configure`)
- Conta AWS com permissões para S3, Glue e Athena

### 1. Clonar o repositório

```bash
git clone https://github.com/dataengineercezar/iceberg-lakehouse-lab.git
cd iceberg-lakehouse-lab
```

### 2. Subir o ambiente local

```bash
cd docker
docker compose build
docker compose up -d
```

### 3. Acessar o PySpark com Iceberg (Hadoop Catalog — local)

```bash
docker exec -it spark-iceberg /opt/spark/bin/pyspark \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.local.type=hadoop \
  --conf spark.sql.catalog.local.warehouse=/home/iceberg/warehouse \
  --conf spark.sql.defaultCatalog=local
```

### 4. Acessar o PySpark com Iceberg (Glue Catalog — AWS)

```bash
docker exec -it spark-iceberg /opt/spark/bin/pyspark \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.glue=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.glue.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog \
  --conf spark.sql.catalog.glue.warehouse=s3a://<SEU_BUCKET>/warehouse \
  --conf spark.sql.catalog.glue.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.defaultCatalog=glue \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.DefaultAWSCredentialsProviderChain
```

---

## 🧪 Funcionalidades Demonstradas

### Operações Básicas
- [x] Criação de tabelas Iceberg com Spark SQL
- [x] INSERT, UPDATE, DELETE com garantia ACID
- [x] Integração com AWS S3 como warehouse
- [x] Registro de tabelas no AWS Glue Data Catalog
- [x] Consultas serverless via AWS Athena

### Operações Avançadas Iceberg
- [x] **Time Travel** — consulta a snapshots anteriores com `VERSION AS OF`
- [x] **Schema Evolution** — ADD/RENAME/DROP colunas sem reescrita de dados
- [x] **Partition Evolution** — mudança de particionamento sem reescrita
- [x] **Snapshot Management** — listagem, rollback (`rollback_to_snapshot`)
- [x] **ACID Transactions** — operações atômicas com snapshot isolation

### Queries de Metadados Iceberg

```sql
-- Spark
SELECT * FROM tabela.snapshots;
SELECT * FROM tabela.history;
SELECT * FROM tabela.files;
SELECT * FROM tabela.manifests;
SELECT * FROM tabela.partitions;

-- Athena
SELECT * FROM "tabela$snapshots";
SELECT * FROM "tabela$history";
```

---

## 🏗️ Arquitetura

```
 ┌─────────────────────────────────────────────────────┐
 │              Camada de Consumo                       │
 │   Athena (SQL) │ Spark (ETL) │ BI Tools             │
 └────────┬───────┴──────┬──────┴────────┬─────────────┘
          │              │               │
          ▼              ▼               ▼
 ┌─────────────────────────────────────────────────────┐
 │           AWS Glue Data Catalog                      │
 │     (metastore: database + tabelas Iceberg)          │
 └────────────────────────┬────────────────────────────┘
                          │
                          ▼
 ┌─────────────────────────────────────────────────────┐
 │              Apache Iceberg Layer                    │
 │  metadata.json → manifest list → manifest → data    │
 └────────────────────────┬────────────────────────────┘
                          │
                          ▼
 ┌─────────────────────────────────────────────────────┐
 │                   AWS S3                             │
 │   s3://bucket/warehouse/db/tabela/{data,metadata}/  │
 └─────────────────────────────────────────────────────┘
```

> Documentação completa: [docs/architecture.md](docs/architecture.md)

---

## 📚 Documentação

| Documento | Conteúdo |
|---|---|
| [Arquitetura do Lakehouse](docs/architecture.md) | Diagrama completo, componentes, fluxo de dados, decisões |
| [Conceitos Apache Iceberg](docs/iceberg-concepts.md) | Metadados, snapshots, Time Travel, Schema/Partition Evolution, ACID, v2 |
| [Configuração AWS](docs/aws-setup.md) | IAM policies, S3, Glue, Athena, troubleshooting |

---

## 🔖 Commit History (Semântico)

| Commit | Descrição |
|---|---|
| `feat(init)` | Estrutura base do repositório |
| `feat(docker)` | Spark 3.5.3 + Iceberg 1.7.1 containerizado |
| `feat(s3)` | Integração Iceberg + S3 warehouse |
| `feat(glue)` | Registro de tabelas no Glue Data Catalog |
| `feat(athena)` | Queries serverless no Athena |
| `feat(iceberg)` | Operações avançadas: Time Travel, Schema/Partition Evolution |
| `docs` | Documentação técnica sênior |

---

## 👤 Autor

**Cezar Carmo** — Engenheiro de Dados

- GitHub: [@dataengineercezar](https://github.com/dataengineercezar)

---

## 📝 Licença

Este projeto é disponibilizado para fins educacionais e de portfólio.
