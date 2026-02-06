# ☁️ Configuração AWS (S3, Glue, Athena)

## Pré-requisitos

- AWS CLI instalado e configurado
- Credenciais IAM com permissões adequadas
- Docker e Docker Compose instalados

---

## 1. Permissões IAM Necessárias

O usuário/role IAM precisa das seguintes policies:

### S3 (Armazenamento)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::iceberg-lakehouse-lab-*",
                "arn:aws:s3:::iceberg-lakehouse-lab-*/*"
            ]
        }
    ]
}
```

### Glue Data Catalog (Metadados)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase",
                "glue:GetDatabases",
                "glue:CreateDatabase",
                "glue:GetTable",
                "glue:GetTables",
                "glue:CreateTable",
                "glue:UpdateTable",
                "glue:DeleteTable",
                "glue:GetPartitions",
                "glue:BatchGetPartition"
            ],
            "Resource": ["*"]
        }
    ]
}
```

### Athena (Queries)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "athena:StartQueryExecution",
                "athena:GetQueryExecution",
                "athena:GetQueryResults",
                "athena:StopQueryExecution"
            ],
            "Resource": ["*"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::athena-results-*",
                "arn:aws:s3:::athena-results-*/*"
            ]
        }
    ]
}
```

---

## 2. Configurar AWS CLI

```bash
# Verificar se o CLI está configurado
aws sts get-caller-identity

# Se necessário, configurar
aws configure
# → AWS Access Key ID
# → AWS Secret Access Key
# → Default region: us-east-1
# → Default output format: json
```

---

## 3. Criar Bucket S3

```bash
# Criar bucket para o warehouse Iceberg
aws s3 mb s3://iceberg-lakehouse-lab-<ACCOUNT_ID> --region us-east-1

# Criar bucket para resultados do Athena
aws s3 mb s3://athena-results-<ACCOUNT_ID> --region us-east-1

# Verificar
aws s3 ls | grep iceberg
aws s3 ls | grep athena
```

### Estrutura do bucket após uso:

```
s3://iceberg-lakehouse-lab-<ACCOUNT_ID>/
└── warehouse/
    └── iceberg_db.db/
        └── clientes/
            ├── data/
            │   ├── 00000-0-xxx.parquet
            │   ├── 00001-1-xxx.parquet
            │   └── ...
            └── metadata/
                ├── v1.metadata.json
                ├── v2.metadata.json
                ├── snap-xxx.avro
                ├── xxx-m0.avro
                └── version-hint.text
```

---

## 4. Criar Database no Glue

```bash
aws glue create-database \
  --database-input '{"Name": "iceberg_db", "Description": "Iceberg Lakehouse Lab"}' \
  --region us-east-1

# Verificar
aws glue get-database --name iceberg_db --region us-east-1
```

---

## 5. Configuração do Spark com Glue Catalog

### Via docker exec (CLI):

```bash
docker exec -it spark-iceberg /opt/spark/bin/pyspark \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.glue=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.glue.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog \
  --conf spark.sql.catalog.glue.warehouse=s3a://iceberg-lakehouse-lab-<ACCOUNT_ID>/warehouse \
  --conf spark.sql.catalog.glue.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.defaultCatalog=glue \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.DefaultAWSCredentialsProviderChain
```

### Explicação das configurações:

| Configuração | Valor | Função |
|---|---|---|
| `spark.sql.extensions` | `IcebergSparkSessionExtensions` | Habilita DDL do Iceberg no Spark |
| `spark.sql.catalog.glue` | `SparkCatalog` | Registra catalog `glue` como Iceberg |
| `catalog-impl` | `GlueCatalog` | Usa AWS Glue como backend |
| `warehouse` | `s3a://bucket/warehouse` | Onde dados e metadata são armazenados |
| `io-impl` | `S3FileIO` | I/O nativo do Iceberg para S3 |
| `defaultCatalog` | `glue` | Catalog padrão nas queries |
| `fs.s3a.impl` | `S3AFileSystem` | Conector Hadoop para S3 |
| `credentials.provider` | `DefaultAWSCredentialsProviderChain` | Usa credentials de ~/.aws |

---

## 6. Queries no Athena

### Via AWS CLI:

```bash
# Executar query
aws athena start-query-execution \
  --query-string "SELECT * FROM iceberg_db.clientes" \
  --result-configuration '{"OutputLocation": "s3://athena-results-<ACCOUNT_ID>/"}' \
  --region us-east-1

# Obter resultado (usar QueryExecutionId retornado)
aws athena get-query-results \
  --query-execution-id <QUERY_EXECUTION_ID> \
  --region us-east-1
```

### Via Console AWS:

1. Acesse: **AWS Console → Athena → Query Editor**
2. Selecione **Data source**: `AwsDataCatalog`
3. Selecione **Database**: `iceberg_db`
4. Execute queries SQL normalmente

### Queries de metadados Iceberg no Athena:

```sql
-- Snapshots
SELECT * FROM iceberg_db."clientes$snapshots";

-- Histórico
SELECT * FROM iceberg_db."clientes$history";

-- Arquivos de dados
SELECT * FROM iceberg_db."clientes$files";

-- Manifests
SELECT * FROM iceberg_db."clientes$manifests";
```

> ⚠️ **Nota:** No Athena, tabelas de metadados usam `$` (escaped com aspas).
> No Spark, usam `.` (ponto): `clientes.snapshots`.

---

## 7. Limpeza de Recursos

Para evitar custos, quando não estiver usando:

```bash
# Esvaziar e remover bucket S3
aws s3 rm s3://iceberg-lakehouse-lab-<ACCOUNT_ID> --recursive
aws s3 rb s3://iceberg-lakehouse-lab-<ACCOUNT_ID>

# Remover bucket Athena
aws s3 rm s3://athena-results-<ACCOUNT_ID> --recursive
aws s3 rb s3://athena-results-<ACCOUNT_ID>

# Remover tabela e database do Glue
aws glue delete-table --database-name iceberg_db --name clientes --region us-east-1
aws glue delete-database --name iceberg_db --region us-east-1

# Parar container Docker
cd docker && docker compose down
```

---

## Troubleshooting

| Erro | Causa | Solução |
|---|---|---|
| `ClassNotFoundException: S3AFileSystem` | Falta JAR `hadoop-aws` | Adicionar ao Dockerfile |
| `Access Denied` no S3 | Permissões IAM insuficientes | Verificar policies acima |
| `Table not found` no Athena | Tabela não registrada no Glue | Usar GlueCatalog no Spark |
| `HIVE_METASTORE_ERROR` | Incompatibilidade de formato | Verificar table format = Iceberg |
| `Forbidden` no Glue | Falta permissão glue:GetTable | Adicionar Glue policies |
