param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='08-java-supply-chain-monolith';Title='Java Supply Chain Modular Monolith';Type='Modular monolith';Backend='Java 21 / Spring Boot 4.1 / PostgreSQL';Frontend='Spring static web application';Domain='supplychain';Namespace='supplychain-java';PublicPort=8088;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Planner --> UI["Supply planning workspace"] --> HTTP["Spring MVC adapters"]
    HTTP --> Purchase["Purchase order module"]
    HTTP --> Receiving["Receiving module"]
    HTTP --> Inventory["Inventory module"]
    Purchase --> Domain["Transactional domain services"]
    Receiving --> Domain
    Inventory --> Domain
    Domain --> JDBC["JDBC adapters"] --> PG[(PostgreSQL)]
    HTTP --> Actuator["Actuator and Micrometer"]
'@
 Workloads=@(
  @{Name='app';Port=8080;Health='/health';Responsibility='Planning UI, purchase/receiving/inventory modules, API, and JDBC adapters in one deployable unit'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/pom.xml' @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion><parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>4.1.0</version><relativePath/></parent>
 <groupId>com.example.supplychain</groupId><artifactId>supply-chain-monolith</artifactId><version>0.1.0</version><properties><java.version>21</java.version></properties>
 <dependencies>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-jdbc</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
  <dependency><groupId>io.micrometer</groupId><artifactId>micrometer-registry-prometheus</artifactId></dependency>
  <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><scope>runtime</scope></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
 </dependencies>
 <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/resources/application.properties' @'
server.port=${PORT:8080}
spring.application.name=supply-chain-app
spring.datasource.url=jdbc:${DATABASE_URL:postgresql://localhost:5432/app}
spring.datasource.username=${POSTGRES_USER:app}
spring.datasource.password=${POSTGRES_PASSWORD:local-development-only}
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.connection-timeout=3000
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoints.web.base-path=/
management.endpoints.web.path-mapping.prometheus=metrics
management.endpoint.health.probes.enabled=true
management.metrics.tags.service=supply-chain-app
server.shutdown=graceful
spring.lifecycle.timeout-per-shutdown-phase=25s
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/java/com/example/supplychain/SupplyChainApplication.java' @'
package com.example.supplychain;

import java.time.Instant;import java.util.*;import org.springframework.boot.*;import org.springframework.boot.autoconfigure.*;import org.springframework.http.*;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;import org.springframework.web.bind.annotation.*;import org.springframework.web.server.ResponseStatusException;

@SpringBootApplication public class SupplyChainApplication{public static void main(String[]args){SpringApplication.run(SupplyChainApplication.class,args);}}

record PurchaseOrderDraft(String supplier,String sku,Integer quantity){}
record PurchaseOrder(UUID id,String supplier,String sku,int quantity,int receivedQuantity,String status,Instant createdAt){}

final class PurchaseRules{
 private PurchaseRules(){}
 static PurchaseOrderDraft validate(PurchaseOrderDraft draft){if(draft==null)throw invalid("INVALID_ORDER");var supplier=draft.supplier()==null?"":draft.supplier().trim();var sku=draft.sku()==null?"":draft.sku().trim().toUpperCase(Locale.ROOT);if(supplier.length()<2||supplier.length()>120)throw invalid("INVALID_SUPPLIER");if(!sku.matches("[A-Z0-9][A-Z0-9._-]{2,63}"))throw invalid("INVALID_SKU");if(draft.quantity()==null||draft.quantity()<1||draft.quantity()>100000)throw invalid("INVALID_QUANTITY");return new PurchaseOrderDraft(supplier,sku,draft.quantity());}
 static ResponseStatusException invalid(String code){return new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,code);}
}

@Service class SupplyChainService{
 private final JdbcTemplate db;SupplyChainService(JdbcTemplate db){this.db=db;initialize();}
 private void initialize(){db.execute("CREATE TABLE IF NOT EXISTS purchase_orders(id uuid PRIMARY KEY,supplier varchar(120) NOT NULL,sku varchar(64) NOT NULL,quantity integer NOT NULL CHECK(quantity>0),received_quantity integer NOT NULL DEFAULT 0 CHECK(received_quantity>=0),status varchar(24) NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL)");}
 List<PurchaseOrder> list(){return db.query("SELECT id,supplier,sku,quantity,received_quantity,status,created_at FROM purchase_orders ORDER BY created_at DESC LIMIT 200",(rs,n)->new PurchaseOrder(rs.getObject("id",UUID.class),rs.getString("supplier"),rs.getString("sku"),rs.getInt("quantity"),rs.getInt("received_quantity"),rs.getString("status"),rs.getTimestamp("created_at").toInstant()));}
 @Transactional PurchaseOrder create(PurchaseOrderDraft raw,String key){if(key==null||key.isBlank()||key.length()>128)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"IDEMPOTENCY_KEY_REQUIRED");var draft=PurchaseRules.validate(raw),existing=byKey(key);if(existing.isPresent())return existing.get();var id=UUID.randomUUID();db.update("INSERT INTO purchase_orders(id,supplier,sku,quantity,status,idempotency_key) VALUES(?,?,?,?,'ordered',?) ON CONFLICT(idempotency_key) DO NOTHING",id,draft.supplier(),draft.sku(),draft.quantity(),key);return byKey(key).orElseThrow();}
 @Transactional PurchaseOrder receive(UUID id,int amount){if(amount<1)throw PurchaseRules.invalid("INVALID_RECEIPT");var order=byIdForUpdate(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"ORDER_NOT_FOUND"));if(order.receivedQuantity()+amount>order.quantity())throw new ResponseStatusException(HttpStatus.CONFLICT,"RECEIPT_EXCEEDS_ORDER");var total=order.receivedQuantity()+amount,status=total==order.quantity()?"received":"partially_received";db.update("UPDATE purchase_orders SET received_quantity=?,status=? WHERE id=?",total,status,id);return byId(id).orElseThrow();}
 private Optional<PurchaseOrder> byKey(String key){return queryOne("SELECT id,supplier,sku,quantity,received_quantity,status,created_at FROM purchase_orders WHERE idempotency_key=?",key);}
 private Optional<PurchaseOrder> byId(UUID id){return queryOne("SELECT id,supplier,sku,quantity,received_quantity,status,created_at FROM purchase_orders WHERE id=?",id);}
 private Optional<PurchaseOrder> byIdForUpdate(UUID id){return queryOne("SELECT id,supplier,sku,quantity,received_quantity,status,created_at FROM purchase_orders WHERE id=? FOR UPDATE",id);}
 private Optional<PurchaseOrder> queryOne(String sql,Object value){var rows=db.query(sql,(rs,n)->new PurchaseOrder(rs.getObject("id",UUID.class),rs.getString("supplier"),rs.getString("sku"),rs.getInt("quantity"),rs.getInt("received_quantity"),rs.getString("status"),rs.getTimestamp("created_at").toInstant()),value);return rows.stream().findFirst();}
}

@RestController @RequestMapping("/api/orders") class PurchaseOrderController{
 private final SupplyChainService service;PurchaseOrderController(SupplyChainService service){this.service=service;}
 @GetMapping List<PurchaseOrder> list(){return service.list();}
 @PostMapping @ResponseStatus(HttpStatus.CREATED) PurchaseOrder create(@RequestBody PurchaseOrderDraft draft,@RequestHeader(value="Idempotency-Key",required=false)String key){return service.create(draft,key);}
 @PostMapping("/{id}/receipts") PurchaseOrder receive(@PathVariable UUID id,@RequestBody Map<String,Integer> body){return service.receive(id,body.getOrDefault("quantity",0));}
}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/test/java/com/example/supplychain/PurchaseRulesTest.java' @'
package com.example.supplychain;import static org.junit.jupiter.api.Assertions.*;import org.junit.jupiter.api.Test;class PurchaseRulesTest{@Test void normalizesSku(){var value=PurchaseRules.validate(new PurchaseOrderDraft("Acme"," sku-100 ",25));assertEquals("SKU-100",value.sku());}@Test void rejectsZeroQuantity(){assertThrows(Exception.class,()->PurchaseRules.validate(new PurchaseOrderDraft("Acme","SKU-100",0)));}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/resources/static/index.html' @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Supply Atlas</title><link rel="stylesheet" href="/style.css"></head><body><main><header><p>SUPPLY ATLAS</p><h1>Know what is coming.<br>Know what arrived.</h1><output id="message">Ready</output></header><form id="order"><input name="supplier" placeholder="Supplier" required><input name="sku" placeholder="SKU-100" required><input name="quantity" type="number" min="1" value="100"><button>Create purchase order</button></form><section id="orders"></section></main><script src="/app.js" defer></script></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/resources/static/app.js' @'
const list=document.querySelector("#orders"),form=document.querySelector("#order"),message=document.querySelector("#message");async function load(){const r=await fetch("/api/orders");if(!r.ok)throw Error("Unable to load orders");list.innerHTML=(await r.json()).map(x=>`<article><span>${x.status.replaceAll("_"," ")}</span><h2>${x.sku}</h2><p>${x.supplier}</p><strong>${x.receivedQuantity} / ${x.quantity} received</strong><button data-id="${x.id}">Receive one</button></article>`).join("")}form.addEventListener("submit",async e=>{e.preventDefault();const f=new FormData(form),r=await fetch("/api/orders",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({supplier:f.get("supplier"),sku:f.get("sku"),quantity:Number(f.get("quantity"))})});message.textContent=r.ok?"Order created":JSON.stringify(await r.json());if(r.ok){form.reset();await load()}});list.addEventListener("click",async e=>{const id=e.target.dataset.id;if(!id)return;const r=await fetch(`/api/orders/${id}/receipts`,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({quantity:1})});message.textContent=r.ok?"Receipt recorded":JSON.stringify(await r.json());if(r.ok)await load()});load().catch(e=>message.textContent=e.message);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main/resources/static/style.css' @'
:root{font-family:Arial,sans-serif;color:#222;background:#efeee9}*{box-sizing:border-box}body{margin:0;border-top:10px solid #db3a34}main{max-width:1120px;margin:auto;padding:4rem 2rem}header p{letter-spacing:.22em;font-weight:bold;color:#db3a34}h1{font:800 clamp(2.8rem,7vw,6rem)/.9 Arial,sans-serif;letter-spacing:-.06em;max-width:900px}form{display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:1px;background:#222;padding:1px;margin:3rem 0}input,button{padding:1rem;border:0}button{background:#f4c95d;font-weight:bold}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:1px;background:#222}article{background:#fff;padding:1.2rem;display:grid;gap:.5rem}article span{text-transform:uppercase;font-size:.7rem;color:#db3a34}article button{margin-top:.5rem;background:#222;color:white}@media(max-width:700px){form{grid-template-columns:1fr}}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 20 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/08-java-supply-chain-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment: { PORT: 8080, DATABASE_URL: "postgresql://postgres:5432/${POSTGRES_DB:-app}", POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}" }
    ports: ["${PUBLIC_PORT:-8088}:8080"]
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
docker run --rm -v "$PWD/app:/src" -w /src maven:3.9.9-eclipse-temurin-21 mvn -B -ntp test
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
