param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='18-kotlin-energy-trading-api';Title='Kotlin Reactive Energy Trading Service';Type='Reactive enterprise service';Backend='Kotlin 2.4 / Java 25 / Spring Boot 4.1 / WebFlux / R2DBC / PostgreSQL';Frontend='HTTP API';Domain='energy-trading';Namespace='energy-kotlin';PublicPort=8098;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Trader --> API["Coroutines WebFlux API"]
    API --> Rules["Null-safe trade rules"]
    Rules --> Repo["Reactive repository"]
    Repo --> PG[(PostgreSQL)]
    API --> Health["Actuator and metrics"]
    Settlement["Settlement consumers"] --> API
'@
 Workloads=@(@{Name='app';Port=8080;Health='/health';Responsibility='Kotlin coroutine API, deterministic trade rules, reactive persistence, health, and metrics'})
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/pom.xml' @'
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>4.1.0</version><relativePath/></parent>
  <groupId>dev.masterclass</groupId><artifactId>energy-trading</artifactId><version>0.1.0</version>
  <properties><java.version>25</java.version><kotlin.version>2.4.10</kotlin.version></properties>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webflux</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-r2dbc</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-opentelemetry</artifactId></dependency>
    <dependency><groupId>org.jetbrains.kotlin</groupId><artifactId>kotlin-reflect</artifactId></dependency>
    <dependency><groupId>org.jetbrains.kotlinx</groupId><artifactId>kotlinx-coroutines-reactor</artifactId></dependency>
    <dependency><groupId>tools.jackson.module</groupId><artifactId>jackson-module-kotlin</artifactId></dependency>
    <dependency><groupId>org.postgresql</groupId><artifactId>r2dbc-postgresql</artifactId><scope>runtime</scope></dependency>
    <dependency><groupId>io.micrometer</groupId><artifactId>micrometer-registry-prometheus</artifactId><scope>runtime</scope></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
    <dependency><groupId>io.projectreactor</groupId><artifactId>reactor-test</artifactId><scope>test</scope></dependency>
  </dependencies>
  <build><sourceDirectory>${project.basedir}/src/main/kotlin</sourceDirectory><testSourceDirectory>${project.basedir}/src/test/kotlin</testSourceDirectory><plugins>
    <plugin><groupId>org.jetbrains.kotlin</groupId><artifactId>kotlin-maven-plugin</artifactId><version>${kotlin.version}</version><extensions>true</extensions><configuration><jvmTarget>25</jvmTarget><javaParameters>true</javaParameters><args><arg>-Xannotation-default-target=param-property</arg></args><compilerPlugins><plugin>spring</plugin></compilerPlugins></configuration><dependencies><dependency><groupId>org.jetbrains.kotlin</groupId><artifactId>kotlin-maven-allopen</artifactId><version>${kotlin.version}</version></dependency></dependencies></plugin>
    <plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin>
  </plugins></build>
</project>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/kotlin/dev/masterclass/energy/Application.kt' @'
package dev.masterclass.energy
import kotlinx.coroutines.reactor.awaitSingle
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.r2dbc.core.DatabaseClient
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.util.UUID

@SpringBootApplication class Application{
 @Bean fun schema(db:DatabaseClient)=ApplicationRunner{db.sql("CREATE TABLE IF NOT EXISTS energy_trades(id uuid PRIMARY KEY,portfolio varchar(64) NOT NULL,market char(2) NOT NULL,megawatt_hours numeric(14,3) NOT NULL,price_per_mwh numeric(14,2) NOT NULL,side varchar(4) NOT NULL,status varchar(16) NOT NULL,idempotency_key varchar(128) UNIQUE NOT NULL,created_at timestamptz NOT NULL DEFAULT now())").then().block()}
}
fun main(args:Array<String>)=runApplication<Application>(*args)

data class TradeDraft(val portfolio:String?,val market:String?,val megawattHours:BigDecimal?,val pricePerMwh:BigDecimal?,val side:String?)
data class ValidTrade(val portfolio:String,val market:String,val megawattHours:BigDecimal,val pricePerMwh:BigDecimal,val side:String)
data class Trade(val id:String,val portfolio:String,val market:String,val megawattHours:BigDecimal,val pricePerMwh:BigDecimal,val side:String,val status:String,val createdAt:String)
object TradeRules{fun parse(value:TradeDraft):ValidTrade{val portfolio=value.portfolio.orEmpty().trim().uppercase();val market=value.market.orEmpty().trim().uppercase();val side=value.side.orEmpty().trim().uppercase();require(portfolio.matches(Regex("[A-Z0-9-]{4,64}"))){"INVALID_PORTFOLIO"};require(market.matches(Regex("[A-Z]{2}"))){"INVALID_MARKET"};require(value.megawattHours!=null&&value.megawattHours>BigDecimal.ZERO&&value.megawattHours<=BigDecimal("1000000")){"INVALID_VOLUME"};require(value.pricePerMwh!=null&&value.pricePerMwh>BigDecimal.ZERO&&value.pricePerMwh<=BigDecimal("100000")){"INVALID_PRICE"};require(side in setOf("BUY","SELL")){"INVALID_SIDE"};return ValidTrade(portfolio,market,value.megawattHours,value.pricePerMwh,side)}}
class TradeRepository(private val db:DatabaseClient){private fun map(row:io.r2dbc.spi.Row)=Trade(row.get("id",String::class.java)!!,row.get("portfolio",String::class.java)!!,row.get("market",String::class.java)!!,row.get("megawatt_hours",BigDecimal::class.java)!!,row.get("price_per_mwh",BigDecimal::class.java)!!,row.get("side",String::class.java)!!,row.get("status",String::class.java)!!,row.get("created_at",String::class.java)!!);suspend fun list()=db.sql("SELECT id::text,portfolio,market,megawatt_hours,price_per_mwh,side,status,created_at::text FROM energy_trades ORDER BY created_at DESC LIMIT 200").map{row,_->map(row)}.all().collectList().awaitSingle();suspend fun create(value:ValidTrade,key:String):Trade=db.sql("INSERT INTO energy_trades(id,portfolio,market,megawatt_hours,price_per_mwh,side,status,idempotency_key) VALUES(:id,:portfolio,:market,:volume,:price,:side,'accepted',:key) ON CONFLICT(idempotency_key) DO UPDATE SET idempotency_key=excluded.idempotency_key RETURNING id::text,portfolio,market,megawatt_hours,price_per_mwh,side,status,created_at::text").bind("id",UUID.randomUUID()).bind("portfolio",value.portfolio).bind("market",value.market).bind("volume",value.megawattHours).bind("price",value.pricePerMwh).bind("side",value.side).bind("key",key).map{row,_->map(row)}.one().awaitSingle()}
@RestController class TradeController(private val db:DatabaseClient){private val repository=TradeRepository(db);@GetMapping("/health")suspend fun health():Map<String,String>{db.sql("SELECT 1").fetch().rowsUpdated().awaitSingle();return mapOf("status" to "ok","service" to "energy-trading")};@GetMapping("/metrics",produces=[MediaType.TEXT_PLAIN_VALUE])fun metrics()="# HELP energy_trading_up Service readiness\n# TYPE energy_trading_up gauge\nenergy_trading_up 1\n";@GetMapping("/api/trades")suspend fun list()=repository.list();@PostMapping("/api/trades")suspend fun create(@RequestHeader("Idempotency-Key",required=false)key:String?,@RequestBody draft:TradeDraft):ResponseEntity<Any>{if(key.isNullOrBlank()||key.length>128)return ResponseEntity.badRequest().body(mapOf("code" to "IDEMPOTENCY_KEY_REQUIRED"));return try{ResponseEntity.status(201).body(repository.create(TradeRules.parse(draft),key))}catch(error:IllegalArgumentException){ResponseEntity.unprocessableEntity().body(mapOf("code" to (error.message?:"INVALID_TRADE")))}}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/resources/application.yml' @'
server: { port: 8080, shutdown: graceful }
spring:
  application: { name: energy-trading }
  r2dbc: { url: "${DATABASE_URL:r2dbc:postgresql://localhost:5432/app}", username: "${POSTGRES_USER:app}", password: "${POSTGRES_PASSWORD:local-development-only}" }
  lifecycle: { timeout-per-shutdown-phase: 20s }
management:
  endpoints: { web: { exposure: { include: "health,info,prometheus" } } }
  endpoint: { health: { probes: { enabled: true } } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/test/kotlin/dev/masterclass/energy/TradeRulesTest.kt' @'
package dev.masterclass.energy
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import java.math.BigDecimal
class TradeRulesTest{@Test fun normalizesValidTrade(){val value=TradeRules.parse(TradeDraft(" desk-1 ","in",BigDecimal("12.5"),BigDecimal("70"),"buy"));assertEquals("DESK-1",value.portfolio);assertEquals("BUY",value.side)}@Test fun rejectsNegativeVolume(){val error=assertThrows(IllegalArgumentException::class.java){TradeRules.parse(TradeDraft("desk-1","IN",BigDecimal("-1"),BigDecimal("70"),"BUY"))};assertEquals("INVALID_VOLUME",error.message)}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Dockerfile' @'
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /src
COPY pom.xml ./
RUN mvn -B -ntp dependency:go-offline
COPY src ./src
RUN mvn -B -ntp verify
FROM eclipse-temurin:25-jre
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY --from=build --chown=10001:10001 /src/target/energy-trading-0.1.0.jar app.jar
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-jar","app.jar"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/18-kotlin-energy-trading-api-app:${IMAGE_TAG:-dev}
    build: app
    environment: { DATABASE_URL: "r2dbc:postgresql://postgres:5432/${POSTGRES_DB:-app}", POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}" }
    ports: ["${PUBLIC_PORT:-8098}:8080"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src maven:3.9-eclipse-temurin-25 mvn -B -ntp test
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
