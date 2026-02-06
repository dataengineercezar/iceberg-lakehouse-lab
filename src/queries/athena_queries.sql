-- =====================================================
-- Athena Queries - Iceberg Lakehouse Lab
-- Database: iceberg_db | Table Format: Apache Iceberg
-- =====================================================

-- 1. Consulta básica
SELECT * FROM iceberg_db.clientes;

-- 2. Snapshots (metadados de versionamento)
SELECT * FROM iceberg_db."clientes$snapshots";

-- 3. Histórico da tabela
SELECT * FROM iceberg_db."clientes$history";

-- 4. Arquivos de dados (data files)
SELECT * FROM iceberg_db."clientes$files";

-- 5. Manifests
SELECT * FROM iceberg_db."clientes$manifests";