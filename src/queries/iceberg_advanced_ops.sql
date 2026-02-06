-- =====================================================
-- Operações Avançadas Iceberg - Lakehouse Lab
-- Demonstra: Time Travel, Schema/Partition Evolution,
--            Snapshot Management, Rollback
-- =====================================================

-- =====================================================
-- 1. TIME TRAVEL
-- =====================================================

-- Consultar estado anterior por Snapshot ID
SELECT * FROM iceberg_db.clientes VERSION AS OF 469597217705061286;

-- Listar todos os snapshots disponíveis
SELECT snapshot_id, committed_at, operation,
       summary['added-records'] as added,
       summary['deleted-records'] as deleted,
       summary['total-records'] as total
FROM iceberg_db.clientes.snapshots
ORDER BY committed_at;

-- =====================================================
-- 2. SCHEMA EVOLUTION (sem reescrita de dados!)
-- =====================================================

-- Adicionar coluna
ALTER TABLE iceberg_db.clientes ADD COLUMNS (email STRING);

-- Renomear coluna
ALTER TABLE iceberg_db.clientes RENAME COLUMN cidade TO localidade;

-- =====================================================
-- 3. PARTITION EVOLUTION (sem reescrita de dados!)
-- =====================================================

-- Adicionar partição por mês
ALTER TABLE iceberg_db.clientes ADD PARTITION FIELD month(data_cadastro);

-- Verificar partições
SELECT * FROM iceberg_db.clientes.partitions;

-- =====================================================
-- 4. SNAPSHOT MANAGEMENT
-- =====================================================

-- Rollback para snapshot específico
CALL glue.system.rollback_to_snapshot('iceberg_db.clientes', 1618509814162713817);

-- Expirar snapshots antigos (manter últimos N)
-- CALL glue.system.expire_snapshots('iceberg_db.clientes', TIMESTAMP '2026-02-06 18:00:00', 1);