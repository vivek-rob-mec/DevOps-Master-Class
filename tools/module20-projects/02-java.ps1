param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='02-java-banking-microservices';Title='Java Banking Microservices Platform';Type='Microservices';Backend='Java 21 / Spring Boot 4.1';Frontend='Vue 3 / Vite';Domain='banking';Namespace='banking-java';PublicPort=8082;Entry='gateway';Ui='frontend'
 Diagram=@'
flowchart LR
    User --> Vue["Vue banking portal"] --> Gateway["Spring gateway"]
    Gateway --> Accounts["Account service"]
    Gateway --> Ledger["Ledger service"]
    Ledger --> Accounts
    Accounts --> AccountDB[("Account state")]
    Ledger --> LedgerDB[("Journal state")]
    Gateway --> Observe["Actuator and metrics"]
'@
 Workloads=@(
  @{Name='gateway';Port=8080;Health='/actuator/health';Responsibility='Public API and routing'},
  @{Name='accounts';Port=8081;Health='/actuator/health';Responsibility='Account ownership and queries'},
  @{Name='ledger';Port=8082;Health='/actuator/health';Responsibility='Idempotent transfer journal'},
  @{Name='frontend';Port=8080;Health='/health';Responsibility='Vue banking portal'}
 )
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'pom.xml' @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion><parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>4.1.0</version><relativePath/></parent>
 <groupId>com.example.banking</groupId><artifactId>banking-platform</artifactId><version>0.1.0</version><packaging>pom</packaging><properties><java.version>21</java.version></properties>
 <modules><module>services/gateway</module><module>services/accounts</module><module>services/ledger</module></modules>
</project>
'@ -WhatIfMode:$WhatIfMode
$pom=@'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion><parent><groupId>com.example.banking</groupId><artifactId>banking-platform</artifactId><version>0.1.0</version><relativePath>../../pom.xml</relativePath></parent><artifactId>@@SERVICE@@</artifactId>
 <dependencies><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc</artifactId></dependency><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency><dependency><groupId>io.micrometer</groupId><artifactId>micrometer-registry-prometheus</artifactId></dependency><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency></dependencies>
 <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
'@
$docker=@'
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
COPY services ./services
RUN mvn -B -ntp -pl services/@@SERVICE@@ -am package -DskipTests
FROM eclipse-temurin:21-jre-jammy
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app -m app
WORKDIR /app
COPY --from=build /src/services/@@SERVICE@@/target/@@SERVICE@@-0.1.0.jar app.jar
USER 10001:10001
EXPOSE @@SERVICE_PORT@@
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-XX:+ExitOnOutOfMemoryError","-jar","/app/app.jar"]
'@
foreach($s in @(@{Name='gateway';Port=8080},@{Name='accounts';Port=8081},@{Name='ledger';Port=8082})){
 $x=@{SERVICE=$s.Name;SERVICE_PORT=$s.Port}
 Write-TemplateFile $root "services/$($s.Name)/pom.xml" (Expand-ProjectTemplate $pom $x) -WhatIfMode:$WhatIfMode
 Write-TemplateFile $root "services/$($s.Name)/Dockerfile" (Expand-ProjectTemplate $docker $x) -WhatIfMode:$WhatIfMode
 Write-TemplateFile $root "services/$($s.Name)/src/main/resources/application.properties" (Expand-ProjectTemplate @'
server.port=${PORT:@@SERVICE_PORT@@}
spring.application.name=@@SERVICE@@
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoint.health.probes.enabled=true
management.metrics.tags.service=@@SERVICE@@
server.shutdown=graceful
'@ $x) -WhatIfMode:$WhatIfMode
}
Write-TemplateFile $root 'services/accounts/src/main/java/com/example/banking/accounts/AccountsApplication.java' @'
package com.example.banking.accounts;
import java.math.BigDecimal;import java.util.*;import java.util.concurrent.ConcurrentHashMap;import org.springframework.boot.*;import org.springframework.boot.autoconfigure.*;import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import org.springframework.web.server.ResponseStatusException;
@SpringBootApplication public class AccountsApplication{public static void main(String[]a){SpringApplication.run(AccountsApplication.class,a);}}
record Account(String id,String owner,String currency,BigDecimal availableBalance){}
@RestController @RequestMapping("/accounts") class AccountController{
 private final Map<String,Account> data=new ConcurrentHashMap<>(Map.of("acct-100",new Account("acct-100","Asha","INR",new BigDecimal("250000.00")),"acct-200",new Account("acct-200","Vikram","INR",new BigDecimal("175000.00"))));
 @GetMapping Collection<Account> list(){return data.values();}
 @GetMapping("/{id}") Account get(@PathVariable String id){var value=data.get(id);if(value==null)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"account not found");return value;}
}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/ledger/src/main/java/com/example/banking/ledger/LedgerApplication.java' @'
package com.example.banking.ledger;
import java.math.BigDecimal;import java.time.Instant;import java.util.*;import java.util.concurrent.ConcurrentHashMap;import org.springframework.beans.factory.annotation.Value;import org.springframework.boot.*;import org.springframework.boot.autoconfigure.*;import org.springframework.context.annotation.Bean;import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import org.springframework.web.client.RestClient;import org.springframework.web.server.ResponseStatusException;
@SpringBootApplication public class LedgerApplication{public static void main(String[]a){SpringApplication.run(LedgerApplication.class,a);}@Bean RestClient accounts(@Value("${ACCOUNTS_URL:http://accounts:8081}")String url){return RestClient.create(url);}}
record TransferCommand(String sourceAccountId,String destinationAccountId,BigDecimal amount,String currency){}record Transfer(String id,String sourceAccountId,String destinationAccountId,BigDecimal amount,String currency,String status,Instant createdAt){}
@RestController @RequestMapping("/transfers") class LedgerController{
 private final RestClient accounts;private final Map<String,Transfer> data=new ConcurrentHashMap<>();private final Map<String,String> keys=new ConcurrentHashMap<>();LedgerController(RestClient accounts){this.accounts=accounts;}
 @GetMapping Collection<Transfer> list(){return data.values();}
 @PostMapping @ResponseStatus(HttpStatus.CREATED) synchronized Transfer create(@RequestBody TransferCommand c,@RequestHeader("Idempotency-Key")String key){if(keys.containsKey(key))return data.get(keys.get(key));if(c.amount()==null||c.amount().signum()<=0||c.sourceAccountId().equals(c.destinationAccountId()))throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"invalid transfer");accounts.get().uri("/accounts/{id}",c.sourceAccountId()).retrieve().toBodilessEntity();accounts.get().uri("/accounts/{id}",c.destinationAccountId()).retrieve().toBodilessEntity();var t=new Transfer(UUID.randomUUID().toString(),c.sourceAccountId(),c.destinationAccountId(),c.amount(),c.currency(),"posted",Instant.now());data.put(t.id(),t);keys.put(key,t.id());return t;}
}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/gateway/src/main/java/com/example/banking/gateway/GatewayApplication.java' @'
package com.example.banking.gateway;
import java.util.Map;import org.springframework.beans.factory.annotation.Value;import org.springframework.boot.*;import org.springframework.boot.autoconfigure.*;import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import org.springframework.web.client.RestClient;
@SpringBootApplication public class GatewayApplication{public static void main(String[]a){SpringApplication.run(GatewayApplication.class,a);}}
@RestController class GatewayController{private final RestClient accounts,ledger;GatewayController(@Value("${ACCOUNTS_URL:http://accounts:8081}")String a,@Value("${LEDGER_URL:http://ledger:8082}")String l){accounts=RestClient.create(a);ledger=RestClient.create(l);}@GetMapping("/health")Map<String,String> health(){return Map.of("status","ok","service","gateway");}@GetMapping("/api/accounts")ResponseEntity<String> accounts(){return accounts.get().uri("/accounts").retrieve().toEntity(String.class);}@GetMapping("/api/transfers")ResponseEntity<String> transfers(){return ledger.get().uri("/transfers").retrieve().toEntity(String.class);}@PostMapping("/api/transfers")ResponseEntity<String> transfer(@RequestBody String body,@RequestHeader("Idempotency-Key")String key){return ledger.post().uri("/transfers").header("Idempotency-Key",key).contentType(MediaType.APPLICATION_JSON).body(body).retrieve().toEntity(String.class);}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/package.json' '{"name":"banking-vue","private":true,"version":"0.1.0","type":"module","scripts":{"build":"vite build"},"dependencies":{"@vitejs/plugin-vue":"6.0.8","vite":"8.1.0","vue":"3.5.40"}}' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import vue from"@vitejs/plugin-vue";export default defineConfig({plugins:[vue()],resolve:{alias:{vue:"vue/dist/vue.esm-bundler.js"}}});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/.dockerignore' "node_modules/`ndist/" -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<!doctype html><html><body><div id="app"></div><script type="module" src="/src/main.js"></script></body></html>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.js' @'
import{createApp,onMounted,ref}from"vue";import"./style.css";const App={setup(){const accounts=ref([]),message=ref("Loading");onMounted(async()=>{accounts.value=await(await fetch("/api/accounts")).json();message.value="Ready"});async function transfer(){const r=await fetch("/api/transfers",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({sourceAccountId:"acct-100",destinationAccountId:"acct-200",amount:1000,currency:"INR"})});message.value=JSON.stringify(await r.json())}return{accounts,message,transfer}},template:`<main><h1>Banking Platform</h1><p>{{message}}</p><article v-for="a in accounts" :key="a.id">{{a.owner}} - {{a.currency}} {{a.availableBalance}}</article><button @click="transfer">Transfer</button></main>`};createApp(App).mount("#app");
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' 'body{font-family:system-ui;background:#eef6f3}main{max-width:800px;margin:auto;padding:3rem}article{background:white;margin:.5rem;padding:1rem}button{padding:.7rem;background:#176b55;color:white;border:0}' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/nginx.conf' 'server { listen 8080; root /usr/share/nginx/html; location = /health { default_type application/json; return 200 ''{"status":"ok","service":"frontend"}''; } location /api/ { proxy_pass ${GATEWAY_URL}/api/; } location / { try_files $uri /index.html; } }' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /src
COPY package*.json .
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  accounts:
    image: ${REGISTRY:-local}/02-java-banking-microservices-accounts:${IMAGE_TAG:-dev}
    build: { context: ., dockerfile: services/accounts/Dockerfile }
    environment: { PORT: 8081 }
    healthcheck: { test: ["CMD","curl","-fsS","http://localhost:8081/actuator/health"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [backend]
  ledger:
    image: ${REGISTRY:-local}/02-java-banking-microservices-ledger:${IMAGE_TAG:-dev}
    build: { context: ., dockerfile: services/ledger/Dockerfile }
    environment: { PORT: 8082, ACCOUNTS_URL: http://accounts:8081 }
    depends_on: { accounts: { condition: service_healthy } }
    healthcheck: { test: ["CMD","curl","-fsS","http://localhost:8082/actuator/health"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [backend]
  gateway:
    image: ${REGISTRY:-local}/02-java-banking-microservices-gateway:${IMAGE_TAG:-dev}
    build: { context: ., dockerfile: services/gateway/Dockerfile }
    environment: { PORT: 8080, ACCOUNTS_URL: http://accounts:8081, LEDGER_URL: http://ledger:8082 }
    depends_on: { accounts: { condition: service_healthy }, ledger: { condition: service_healthy } }
    healthcheck: { test: ["CMD","curl","-fsS","http://localhost:8080/actuator/health"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [backend,edge]
  frontend:
    image: ${REGISTRY:-local}/02-java-banking-microservices-frontend:${IMAGE_TAG:-dev}
    build: { context: frontend }
    environment: { GATEWAY_URL: http://gateway:8080 }
    ports: ["${PUBLIC_PORT:-8082}:8080"]
    depends_on: { gateway: { condition: service_healthy } }
    networks: [edge]
networks: { edge: {}, backend: { internal: true } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD:/src" -w /src maven:3.9.9-eclipse-temurin-21 mvn -B -ntp test
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
