FROM apache/spark:3.5.3

USER root

# Dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Versões dos JARs
ENV ICEBERG_VERSION=1.7.1

# Download dos JARs do Iceberg e AWS
RUN curl -L -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar && \
    curl -L -o /opt/spark/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar

# Cria diretório do warehouse
RUN mkdir -p /home/iceberg/warehouse && chmod 777 /home/iceberg/warehouse

USER spark

ENTRYPOINT ["/opt/entrypoint.sh"]