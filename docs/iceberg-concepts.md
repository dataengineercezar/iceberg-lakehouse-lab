# 🧊 Conceitos Apache Iceberg

## O que é Apache Iceberg?

Apache Iceberg é um **formato de tabela aberto** (*open table format*) projetado para datasets analíticos massivos. Ele adiciona uma camada de gerenciamento sobre os arquivos de dados (Parquet, ORC, Avro), trazendo funcionalidades que antes só existiam em data warehouses tradicionais.

> **Iceberg não é uma engine de processamento.** Ele é um formato que engines como Spark, Trino, Flink e Presto utilizam para ler e escrever dados de forma confiável.

---

## Por que Iceberg existe?

### Problemas do Hive Table Format (tradicional)

| Problema | Hive/Parquet | Iceberg |
|---|---|---|
| Listagem de arquivos | `LIST` em diretórios S3 (lento) | Manifest files com tracking explícito |
| Transações ACID | ❌ Não suporta | ✅ Optimistic concurrency |
| Schema Evolution | Reescreve todos os dados | Metadata-only (sem reescrita) |
| Partition Evolution | Reescreve todos os dados | Metadata-only (sem reescrita) |
| Time Travel | ❌ Não suporta | ✅ Via snapshots |
| Consistência | Eventual (S3 listing race) | ✅ Snapshot isolation |
| UPDATE/DELETE | ❌ Não suporta nativamente | ✅ Row-level operations (v2) |

---

## Arquitetura de Metadados

O Iceberg utiliza uma **árvore de metadados** em 4 níveis:

```
                    ┌──────────────────┐
                    │  Catalog         │
                    │  (Glue/Hive/     │
                    │   Hadoop/REST)   │
                    └────────┬─────────┘
                             │ ponteiro para
                             ▼
                    ┌──────────────────┐
                    │ metadata.json    │  ◄── Estado atual da tabela
                    │                  │      (schema, partitions,
                    │ - current snap   │       snapshots, properties)
                    │ - schema history │
                    │ - partition specs│
                    └────────┬─────────┘
                             │ lista de snapshots
                             ▼
                    ┌──────────────────┐
                    │ Manifest List    │  ◄── Ponteiro para manifests
                    │ (.avro)          │      de um snapshot específico
                    │                  │
                    │ snap-xxxxx.avro  │
                    └────────┬─────────┘
                             │ lista de manifest files
                             ▼
                    ┌──────────────────┐
                    │ Manifest File    │  ◄── Lista de data files
                    │ (.avro)          │      com estatísticas por
                    │                  │      coluna (min, max, count,
                    │ - file paths     │      null count)
                    │ - partition info │
                    │ - column stats   │
                    └────────┬─────────┘
                             │ ponteiros para arquivos
                             ▼
                    ┌──────────────────┐
                    │ Data Files       │  ◄── Dados reais
                    │ (.parquet)       │      (Parquet, ORC ou Avro)
                    │                  │
                    │ 00001.parquet    │
                    │ 00002.parquet    │
                    └──────────────────┘
```

### Papel de cada nível:

| Nível | Arquivo | Conteúdo | Formato |
|---|---|---|---|
| **Catalog** | — | Ponteiro para `metadata.json` atual | Glue/Hive/filesystem |
| **Metadata File** | `v1.metadata.json` | Schema, partitions, snapshots, properties | JSON |
| **Manifest List** | `snap-xxx.avro` | Lista de manifests para um snapshot | Avro |
| **Manifest File** | `xxx-m0.avro` | Lista de data files + estatísticas | Avro |
| **Data File** | `00001.parquet` | Dados reais em formato colunar | Parquet |

---

## Conceitos Fundamentais

### 1. Snapshots

Cada operação de escrita (INSERT, UPDATE, DELETE, MERGE) cria um **novo snapshot**. Um snapshot é uma foto imutável do estado da tabela em um momento.

```
Snapshot 1 (append)   → 3 registros
Snapshot 2 (append)   → 5 registros
Snapshot 3 (overwrite)→ 5 registros (1 atualizado)
Snapshot 4 (delete)   → 4 registros (1 removido)
```

**Propriedades:**
- Snapshots são **imutáveis** — nunca são modificados após criação
- Dados antigos não são deletados — ficam disponíveis para Time Travel
- Cada snapshot aponta para sua própria manifest list

### 2. Time Travel

Permite consultar dados **em qualquer ponto anterior no tempo**:

```sql
-- Por Snapshot ID
SELECT * FROM tabela VERSION AS OF 469597217705061286;

-- Por Timestamp
SELECT * FROM tabela TIMESTAMP AS OF '2026-02-06 18:20:00';
```

**Casos de uso:**
- Auditoria e compliance
- Debugging de pipelines
- Rollback de dados corrompidos
- Reproduzir resultados de ML

### 3. Schema Evolution

Permite alterar o schema **sem reescrever dados existentes**:

```sql
-- Adicionar coluna (dados existentes recebem NULL)
ALTER TABLE tabela ADD COLUMNS (email STRING);

-- Renomear coluna (apenas metadata)
ALTER TABLE tabela RENAME COLUMN cidade TO localidade;

-- Remover coluna (apenas metadata)
ALTER TABLE tabela DROP COLUMN coluna_obsoleta;

-- Alterar tipo (widening: int → long)
ALTER TABLE tabela ALTER COLUMN id TYPE bigint;
```

**Como funciona internamente:**
- O Iceberg usa **IDs de coluna** (não nomes) para mapear dados
- Quando uma coluna é adicionada, registros antigos retornam `NULL`
- Quando uma coluna é renomeada, o ID permanece o mesmo
- **Nenhum dado é reescrito** — apenas o `metadata.json` é atualizado

### 4. Partition Evolution

Permite mudar a estratégia de partição **sem reescrever dados**:

```sql
-- Adicionar partição por mês
ALTER TABLE tabela ADD PARTITION FIELD month(data_cadastro);

-- Adicionar partição por bucket
ALTER TABLE tabela ADD PARTITION FIELD bucket(16, id);

-- Remover partição
ALTER TABLE tabela DROP PARTITION FIELD month(data_cadastro);
```

**Transformações de partição disponíveis:**

| Transformação | Exemplo | Resultado |
|---|---|---|
| `identity` | `identity(cidade)` | Valor exato |
| `year` | `year(data)` | Ano |
| `month` | `month(data)` | Ano-Mês |
| `day` | `day(data)` | Ano-Mês-Dia |
| `hour` | `hour(timestamp)` | Ano-Mês-Dia-Hora |
| `bucket` | `bucket(N, coluna)` | Hash em N buckets |
| `truncate` | `truncate(N, coluna)` | Truncar em N caracteres |

**Hidden Partitioning:** O Iceberg calcula a partição automaticamente a partir dos dados. O usuário nunca precisa especificar a coluna de partição no INSERT — não existe `partition by` no write path.

### 5. ACID Transactions

O Iceberg garante propriedades ACID usando **optimistic concurrency control**:

| Propriedade | Como o Iceberg implementa |
|---|---|
| **Atomicity** | Operações são atômicas — commit ou rollback total |
| **Consistency** | Schema e constraints validados antes do commit |
| **Isolation** | Snapshot isolation — leitores não veem escritas parciais |
| **Durability** | Dados e metadata persistidos no S3 antes do commit |

**Conflitos de concorrência:**
- Duas escritas simultâneas: Iceberg faz retry automático (optimistic)
- Se houver conflito real (mesmos arquivos), a segunda operação falha

### 6. Format Version v2 (Row-Level Operations)

O Iceberg v2 introduz **delete files** para operações row-level eficientes:

| Tipo | Descrição | Uso |
|---|---|---|
| **Position Delete** | Marca posições específicas para delete | UPDATE, DELETE |
| **Equality Delete** | Marca valores para delete | MERGE, streaming |

```
Data File (00001.parquet)     Delete File (00001-deletes.parquet)
┌────┬───────────┐            ┌────┬──────────┐
│ id │ nome      │            │ file_path    │ pos  │
├────┼───────────┤            ├──────────────┼──────┤
│  1 │ Maria     │  ◄─────── │ 00001.parquet│  0   │ (deletado)
│  2 │ João      │            └──────────────┴──────┘
│  3 │ Ana       │
└────┴───────────┘
```

---

## Catálogos Iceberg

| Catalog | Backend | Uso Recomendado |
|---|---|---|
| **Hadoop** | Filesystem (S3/HDFS) | Desenvolvimento, testes |
| **Hive** | Hive Metastore | Ambientes on-premise com Hive |
| **Glue** | AWS Glue Data Catalog | **Produção AWS** ✅ |
| **REST** | API REST (Tabular, Polaris) | Multi-engine, governança centralizada |
| **JDBC** | Banco relacional | Ambientes sem Hive/Glue |
| **Nessie** | Nessie Server | Git-like branching de dados |

### Glue Catalog (usado neste projeto)

```
Spark ──► GlueCatalog ──► Glue API ──► Armazena:
                                        - Database: iceberg_db
                                        - Table: clientes
                                        - Property: metadata_location
                                          → s3://bucket/warehouse/.../metadata/v2.metadata.json
```

O Glue guarda apenas o **ponteiro para o `metadata.json` mais recente**. Todo o restante (snapshots, manifests, data files) vive no S3.

---

## Comparativo: Iceberg vs Delta Lake vs Hudi

| Feature | Iceberg | Delta Lake | Hudi |
|---|---|---|---|
| Schema Evolution | ✅ Completa | ✅ Parcial | ✅ Parcial |
| Partition Evolution | ✅ Sem reescrita | ❌ Requer reescrita | ❌ Requer reescrita |
| Hidden Partitioning | ✅ | ❌ | ❌ |
| Time Travel | ✅ | ✅ | ✅ |
| Engine Support | Spark, Flink, Trino, Presto, Athena, Dremio | Spark (nativo), Trino (limitado) | Spark, Flink |
| Formato Aberto | ✅ Apache Foundation | ⚠️ Databricks-led | ✅ Apache Foundation |
| Merge-on-Read | ✅ (v2) | ✅ | ✅ |
| Branching/Tagging | ✅ | ❌ | ❌ |
| Catalog Agnostic | ✅ | ❌ (Unity Catalog) | ⚠️ Parcial |

---

## Referências

- [Apache Iceberg - Documentação Oficial](https://iceberg.apache.org/docs/latest/)
- [Iceberg Table Spec](https://iceberg.apache.org/spec/)
- [Iceberg AWS Integration](https://iceberg.apache.org/docs/latest/aws/)
- [AWS Athena + Iceberg](https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html)
