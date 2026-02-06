# 🧊 Iceberg Lakehouse Lab

Repositório hands-on para exploração avançada do **Apache Iceberg** em arquitetura **Lakehouse**, utilizando **AWS (S3, Glue Catalog, Athena)** e ambiente local com **Docker + Spark**.

---

## 📦 Stack Tecnológica

| Tecnologia | Papel |
|---|---|
| Apache Iceberg | Formato de tabela open-source para Data Lakehouse |
| Apache Spark (PySpark) | Engine de processamento distribuído |
| AWS S3 | Armazenamento do Data Lake (warehouse) |
| AWS Glue Data Catalog | Catálogo de metadados das tabelas Iceberg |
| AWS Athena | Consultas SQL serverless sobre tabelas Iceberg |
| Docker + Docker Compose | Ambiente local reprodutível |
| Python 3.x | Linguagem principal (PySpark) |
| Git | Versionamento com commits semânticos |

---

## 🗂️ Estrutura do Repositório

```
iceberg-lakehouse-lab/
├── docker/                  # Infraestrutura local
│   ├── docker-compose.yml
│   └── spark/
│       └── Dockerfile
├── src/
│   ├── ingestion/           # Scripts de ingestão (camada Bronze)
│   ├── transformations/     # Transformações (camada Silver/Gold)
│   └── queries/             # Consultas analíticas Iceberg
├── data/
│   └── raw/                 # Dados de exemplo para testes locais
├── docs/
│   ├── architecture.md      # Arquitetura do Lakehouse
│   ├── iceberg-concepts.md  # Guia conceitual Apache Iceberg
│   └── aws-setup.md         # Configuração AWS (S3, Glue, Athena)
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start

> ⚠️ Pré-requisitos: Docker, Docker Compose, AWS CLI configurado

```bash
# 1. Clonar o repositório
git clone https://github.com/seu-usuario/iceberg-lakehouse-lab.git
cd iceberg-lakehouse-lab

# 2. Subir o ambiente local
docker compose up -d

# 3. Acessar o Spark
docker exec -it spark-iceberg pyspark
```

---

## 🧪 Funcionalidades Demonstradas

- [x] Criação de tabelas Iceberg com Spark
- [x] Integração com AWS S3 como warehouse
- [x] Registro de tabelas no AWS Glue Data Catalog
- [x] Consultas via AWS Athena
- [x] **Time Travel** — consulta a snapshots anteriores
- [x] **Schema Evolution** — adição/remoção de colunas sem rewrite
- [x] **Partition Evolution** — mudança de particionamento sem rewrite
- [x] **Snapshot Management** — expiração e rollback

---

## 📚 Documentação

- [Arquitetura do Lakehouse](docs/architecture.md)
- [Conceitos Apache Iceberg](docs/iceberg-concepts.md)
- [Configuração AWS](docs/aws-setup.md)

---

## 👤 Autor

**Cezar Carmo** — Engenheiro de Dados

---

## 📝 Licença

Este projeto é disponibilizado para fins educacionais e de portfólio.
