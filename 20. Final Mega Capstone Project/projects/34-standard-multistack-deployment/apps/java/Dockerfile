FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /src
COPY App.java .
RUN javac --release 21 -d /out App.java
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /out/ /app/
ENV APP_VERSION=dev JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=65.0 -Dsun.net.httpserver.maxReqTime=15 -Dsun.net.httpserver.maxRspTime=15"
USER 10001:10001
EXPOSE 8080
CMD ["java", "App"]
