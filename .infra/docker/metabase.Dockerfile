FROM amazoncorretto:21

ADD https://downloads.metabase.com/enterprise/v1.56.4.x/metabase.jar /home
ADD https://github.com/motherduckdb/metabase_duckdb_driver/releases/download/0.4.1/duckdb.metabase-driver.jar /home/plugins/

RUN chmod 744 /home/plugins/duckdb.metabase-driver.jar

# Metabase plugin path
ENV MB_PLUGINS_DIR=/home/plugins/

# Timezone config
ENV TZ=Europe/Paris
ENV JAVA_TIMEZONE=Europe/Paris
ENV DUCKDB_LOAD_EXTENSIONS=icu

CMD ["java", "-jar", "/home/metabase.jar"]