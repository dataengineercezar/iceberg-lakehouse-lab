# 🏗️ Arquitetura do Lakehouse

## Visão Geral

Este projeto implementa uma arquitetura **Data Lakehouse** utilizando Apache Iceberg como formato de tabela, AWS S3 como camada de armazenamento e AWS Glue Data Catalog como metastore centralizado.

---

## Diagrama Arquitetural

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CAMADA DE CONSUMO                            │
│                                                                      │
│    ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐    │
│    │  AWS Athena  │    │   Spark     │    │  BI Tools / Apps    │    │
│    │  (Serverless │    │  (PySpark)  │    │  (Redshift Spectrum │    │
│    │   SQL)       │    │             │    │   Trino, Presto)    │    │
│    └──────┬───────┘    └──────┬──────┘    └──────────┬──────────┘    │
│           │                   │                      │               │
└───────────┼───────────────────┼──────────────────────┼───────────────┘
            │                   │                      │
            ▼                   ▼                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    CAMADA DE METADADOS (CATALOG)                     │
│                                                                      │
│    ┌────────────────────────────────────────────────────────────┐    │
│    │              AWS Glue Data Catalog                          │    │
│    │                                                            │    │
│    │  ┌──────────┐  ┌──────────────┐  ┌───────────────────┐    │    │
│    │  │ Database │  │    Tables    │  │  Table Properties │    │    │
│    │  │iceberg_db│  │  (Iceberg)   │  │  (metadata.json   │    │    │
│    │  │          │  │              │  │   location)       │    │    │
│    │  └──────────┘  └──────────────┘  └───────────────────┘    │    │
│    └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                 CAMADA DE FORMATO DE TABELA (ICEBERG)                │
│                                                                      │
│    metadata.json ──► manifest list (.avro) ──► manifest files (.avro)│
│         │                                            │               │
│         │              Snapshots                     │               │
│         │              Schema History                │               │
│         │              Partition Specs               │               │
│         ▼                                            ▼               │
│    ┌─────────────────────────────────────────────────────────────┐   │
│    │                    Data Files (.parquet)                     │   │
│    └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    CAMADA DE ARMAZENAMENTO                           │
│                                                                      │
│    ┌────────────────────────────────────────────────────────────┐    │
│    │                      AWS S3 Bucket                         │    │
│    │                                                            │    │
│    │   s3://iceberg-lakehouse-lab-732592767587/                 │    │
│    │   └── warehouse/                                           │    │
│    │       └── iceberg_db.db/                                   │    │
│    │           └── clientes/                                    │    │
│    │               ├── data/          ← Parquet files           │    │
│    │               └── metadata/      ← Iceberg metadata       │    │
│    └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                    CAMADA DE PROCESSAMENTO (LOCAL)                    │
│                                                                      │
│    ┌────────────────────────────────────────────────────────────┐    │
│    │                    Docker Container                         │    │
│    │                                                            │    │
│    │   ┌──────────────┐  ┌────────────┐  ┌─────────────────┐   │    │
│    │   │ Apache Spark │  │  Iceberg   │  │   Hadoop AWS    │   │    │
│    │   │    3.5.3     │  │ Runtime    │  │   (S3A Client)  │   │    │
│    │   │              │  │   1.7.1    │  │                 │   │    │
│    │   └──────────────┘  └────────────┘  └─────────────────┘   │    │
│    │                                                            │    │
│    │   Volumes: ~/.aws (credentials) | src/ | data/            │    │
│    └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Componentes

### 1. Camada de Armazenamento (Storage Layer)

- **AWS S3** como data lake storage
- Bucket único com prefixo `warehouse/` para dados Iceberg
- Dados armazenados em formato **Parquet** com compressão **ZSTD**
- Metadados Iceberg (JSON e Avro) no mesmo bucket

### 2. Camada de Formato de Tabela (Table Format Layer)

- **Apache Iceberg** como table format
- Hierarquia de metadados:
  - `metadata.json` → estado atual da tabela (schema, snapshots, partitions)
  - `manifest list` → lista de manifest files para cada snapshot
  - `manifest file` → lista de data files com estatísticas
  - `data files` → arquivos Parquet com os dados reais

### 3. Camada de Metadados (Catalog Layer)

- **AWS Glue Data Catalog** como catálogo centralizado
- Registra databases e tabelas Iceberg
- Armazena ponteiro para o `metadata.json` mais recente no S3
- Permite que múltiplos serviços (Athena, EMR, Redshift) acessem as mesmas tabelas

### 4. Camada de Consumo (Consumption Layer)

- **AWS Athena** — queries SQL serverless (sem infraestrutura)
- **Apache Spark** — processamento batch via PySpark
- Extensível para: Trino, Presto, Redshift Spectrum, EMR

### 5. Camada de Processamento Local (Local Processing)

- **Docker** com imagem `apache/spark:3.5.3`
- JARs adicionais: Iceberg Runtime, AWS Bundle, Hadoop AWS, AWS SDK
- Credenciais AWS montadas via volume (read-only)
- Volumes para código-fonte e dados

---

## Fluxo de Dados

```
1. Spark (container Docker)
   │
   ├── Cria tabela Iceberg via SQL
   │
   ├── Registra no Glue Catalog ──────► Glue guarda ponteiro
   │                                     para metadata.json
   │
   ├── Escreve data files (Parquet) ──► S3 warehouse/db/table/data/
   │
   └── Escreve metadata (Avro/JSON) ──► S3 warehouse/db/table/metadata/

2. Athena (serverless)
   │
   ├── Consulta Glue Catalog ──────────► Encontra metadata.json
   │
   ├── Lê manifest list ──────────────► Sabe quais manifests carregar
   │
   ├── Lê manifest files ─────────────► Sabe quais data files ler
   │                                     (com pruning por estatísticas)
   │
   └── Lê apenas data files necessários ► Retorna resultados
```

---

## Decisões de Arquitetura

| Decisão | Escolha | Justificativa |
|---|---|---|
| Table Format | Apache Iceberg | ACID, Time Travel, Schema/Partition Evolution, open-source |
| Storage | AWS S3 | Custo baixo, durabilidade 99.999999999%, escalável |
| Catalog | AWS Glue | Nativo AWS, serverless, integrado com Athena/EMR |
| Query Engine | Athena + Spark | Athena para ad-hoc, Spark para ETL batch |
| Formato de dados | Parquet | Colunar, eficiente, amplamente suportado |
| Compressão | ZSTD | Melhor ratio compressão/velocidade |
| Ambiente local | Docker | Reprodutível, isolado, portável |
| Iceberg Format Version | v2 | Suporte a row-level deletes (MERGE, UPDATE, DELETE) |
