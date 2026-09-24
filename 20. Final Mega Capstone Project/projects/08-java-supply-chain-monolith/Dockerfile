FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY app/pom.xml ./pom.xml
RUN mvn -B -ntp dependency:go-offline
COPY app/src ./src
RUN mvn -B -ntp verify

FROM eclipse-temurin:21-jre-jammy
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY --from=build --chown=app:app /src/target/supply-chain-monolith-0.1.0.jar app.jar
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-XX:+ExitOnOutOfMemoryError","-jar","/app/app.jar"]
