param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='04-php-inventory-monolith';Title='PHP Inventory Management Modular Monolith';Type='Modular monolith';Backend='PHP 8.3 / Slim / PostgreSQL';Frontend='Vue 3 / Vite';Domain='inventory';Namespace='inventory-php';PublicPort=8084;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    User --> UI["Vue inventory workspace"]
    UI --> HTTP["Slim HTTP adapters"]
    HTTP --> Catalog["Catalog module"]
    HTTP --> Stock["Stock movement module"]
    Catalog --> Domain["Domain rules and ports"]
    Stock --> Domain
    Domain --> Repo["PDO repository adapters"]
    Repo --> DB[(PostgreSQL)]
    HTTP --> Observe["Logs and Prometheus metrics"]
'@
 Workloads=@(
  @{Name='app';Port=8080;Health='/health';Responsibility='Vue UI, HTTP API, inventory domain, and persistence adapters in one deployable unit'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/composer.json' @'
{
  "name": "devops-masterclass/inventory-monolith",
  "description": "Production-shaped PHP inventory modular monolith",
  "type": "project",
  "require": {
    "php": "^8.3",
    "slim/psr7": "^1.7",
    "slim/slim": "^4.14"
  },
  "autoload": { "psr-4": { "Inventory\\": "src/" } },
  "config": { "sort-packages": true, "allow-plugins": false }
}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/src/Infrastructure/Database.php' @'
<?php
declare(strict_types=1);

namespace Inventory\Infrastructure;

use PDO;

final class Database
{
    public static function connect(): PDO
    {
        $url = getenv('DATABASE_URL') ?: 'postgresql://app:local-development-only@postgres:5432/app';
        $parts = parse_url($url);
        if ($parts === false || !isset($parts['host'], $parts['path'])) {
            throw new \RuntimeException('DATABASE_URL must be a valid PostgreSQL URL');
        }
        $port = (int) ($parts['port'] ?? 5432);
        $database = ltrim((string) $parts['path'], '/');
        $dsn = sprintf('pgsql:host=%s;port=%d;dbname=%s', $parts['host'], $port, $database);
        $pdo = new PDO($dsn, urldecode((string) ($parts['user'] ?? 'app')), urldecode((string) ($parts['pass'] ?? '')), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $pdo->exec('CREATE TABLE IF NOT EXISTS inventory_items (
            id UUID PRIMARY KEY,
            sku VARCHAR(64) NOT NULL UNIQUE,
            name VARCHAR(160) NOT NULL,
            quantity INTEGER NOT NULL CHECK (quantity >= 0),
            idempotency_key VARCHAR(128) UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )');
        return $pdo;
    }
}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/src/Domain/InventoryService.php' @'
<?php
declare(strict_types=1);

namespace Inventory\Domain;

use PDO;

final class InventoryService
{
    public function __construct(private readonly PDO $database) {}

    /** @return array<int,array<string,mixed>> */
    public function list(): array
    {
        return $this->database->query('SELECT id, sku, name, quantity, created_at FROM inventory_items ORDER BY created_at DESC')->fetchAll();
    }

    /** @param array<string,mixed> $input @return array<string,mixed> */
    public function create(array $input, string $idempotencyKey): array
    {
        $sku = strtoupper(trim((string) ($input['sku'] ?? '')));
        $name = trim((string) ($input['name'] ?? ''));
        $quantity = filter_var($input['quantity'] ?? null, FILTER_VALIDATE_INT);
        if ($sku === '' || $name === '' || $quantity === false || $quantity < 0) {
            throw new \InvalidArgumentException('sku, name, and a non-negative integer quantity are required');
        }
        $existing = $this->database->prepare('SELECT id, sku, name, quantity, created_at FROM inventory_items WHERE idempotency_key = :key');
        $existing->execute(['key' => $idempotencyKey]);
        $row = $existing->fetch();
        if ($row !== false) {
            return $row;
        }
        $id = $this->uuid();
        $statement = $this->database->prepare('INSERT INTO inventory_items(id, sku, name, quantity, idempotency_key) VALUES (:id, :sku, :name, :quantity, :key) RETURNING id, sku, name, quantity, created_at');
        $statement->execute(['id' => $id, 'sku' => $sku, 'name' => $name, 'quantity' => $quantity, 'key' => $idempotencyKey]);
        return $statement->fetch() ?: throw new \RuntimeException('Insert did not return an item');
    }

    private function uuid(): string
    {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));
    }
}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/public/index.php' @'
<?php
declare(strict_types=1);

use Inventory\Domain\InventoryService;
use Inventory\Infrastructure\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Factory\AppFactory;

require dirname(__DIR__) . '/vendor/autoload.php';

$app = AppFactory::create();
$app->addBodyParsingMiddleware();
$app->addRoutingMiddleware();
$app->add(function (Request $request, $handler): Response {
    $requestId = $request->getHeaderLine('X-Request-ID') ?: bin2hex(random_bytes(12));
    $started = microtime(true);
    try {
        $response = $handler->handle($request);
    } catch (InvalidArgumentException $error) {
        $response = new \Slim\Psr7\Response(422);
        $response->getBody()->write(json_encode(['code' => 'VALIDATION_FAILED', 'message' => $error->getMessage(), 'requestId' => $requestId], JSON_THROW_ON_ERROR));
        $response = $response->withHeader('Content-Type', 'application/json');
    } catch (Throwable $error) {
        error_log(json_encode(['level' => 'error', 'requestId' => $requestId, 'message' => $error->getMessage()]));
        $response = new \Slim\Psr7\Response(500);
        $response->getBody()->write(json_encode(['code' => 'INTERNAL_ERROR', 'message' => 'Request failed', 'requestId' => $requestId], JSON_THROW_ON_ERROR));
        $response = $response->withHeader('Content-Type', 'application/json');
    }
    error_log(json_encode(['level' => 'info', 'requestId' => $requestId, 'method' => $request->getMethod(), 'path' => $request->getUri()->getPath(), 'status' => $response->getStatusCode(), 'durationMs' => round((microtime(true) - $started) * 1000, 2)]));
    return $response->withHeader('X-Request-ID', $requestId);
});

$json = static function (Response $response, mixed $payload, int $status = 200): Response {
    $response->getBody()->write(json_encode($payload, JSON_THROW_ON_ERROR));
    return $response->withStatus($status)->withHeader('Content-Type', 'application/json');
};

$app->get('/health', function (Request $_request, Response $response) use ($json): Response {
    Database::connect()->query('SELECT 1');
    return $json($response, ['status' => 'ok', 'service' => 'inventory-app']);
});
$app->get('/metrics', function (Request $_request, Response $response): Response {
    $response->getBody()->write("# HELP inventory_up Whether the application is serving\n# TYPE inventory_up gauge\ninventory_up 1\n");
    return $response->withHeader('Content-Type', 'text/plain; version=0.0.4');
});
$app->get('/api/items', function (Request $_request, Response $response) use ($json): Response {
    return $json($response, (new InventoryService(Database::connect()))->list());
});
$app->post('/api/items', function (Request $request, Response $response) use ($json): Response {
    $key = trim($request->getHeaderLine('Idempotency-Key'));
    if ($key === '') {
        return $json($response, ['code' => 'IDEMPOTENCY_KEY_REQUIRED'], 400);
    }
    $body = $request->getParsedBody();
    return $json($response, (new InventoryService(Database::connect()))->create(is_array($body) ? $body : [], $key), 201);
});
$app->run();
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/public/.htaccess' @'
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/apache-vhost.conf' @'
Listen 8080
<VirtualHost *:8080>
    DocumentRoot /var/www/html/public
    DirectoryIndex index.html index.php
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
        FallbackResource /index.php
    </Directory>
    ErrorLog /proc/self/fd/2
    CustomLog /proc/self/fd/1 combined
</VirtualHost>
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'frontend/package.json' @'
{"name":"inventory-vue","private":true,"version":"0.1.0","type":"module","scripts":{"build":"vite build"},"dependencies":{"@vitejs/plugin-vue":"6.0.8","vite":"8.1.0","vue":"3.5.40"},"devDependencies":{}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import vue from"@vitejs/plugin-vue";export default defineConfig({plugins:[vue()],resolve:{alias:{vue:"vue/dist/vue.esm-bundler.js"}}});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<div id="app"></div><script type="module" src="/src/main.js"></script>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.js' @'
import {createApp,ref,onMounted} from "vue";import"./style.css";
const App={setup(){const items=ref([]),message=ref("Ready");async function load(){items.value=await(await fetch("/api/items")).json()}async function create(event){const form=new FormData(event.target),response=await fetch("/api/items",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({sku:form.get("sku"),name:form.get("name"),quantity:Number(form.get("quantity"))})});message.value=JSON.stringify(await response.json());if(response.ok)await load()}onMounted(()=>load().catch(error=>message.value=error.message));return{items,message,create}},template:`<main><h1>Inventory Control</h1><p>{{message}}</p><form @submit.prevent="create"><input name="sku" value="SKU-100"><input name="name" value="Safety Gloves"><input name="quantity" type="number" value="25"><button>Add item</button></form><table><thead><tr><th>SKU</th><th>Name</th><th>Quantity</th></tr></thead><tbody><tr v-for="item in items" :key="item.id"><td>{{item.sku}}</td><td>{{item.name}}</td><td>{{item.quantity}}</td></tr></tbody></table></main>`};createApp(App).mount("#app");
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' @'
:root{font-family:Inter,system-ui;color:#172033;background:#f3f6fb}body{margin:0}main{max-width:900px;margin:4rem auto;background:white;padding:2rem;border-radius:16px;box-shadow:0 12px 40px #19375b20}form{display:flex;gap:.7rem;flex-wrap:wrap}input,button{padding:.75rem;border:1px solid #b9c5d6;border-radius:8px}button{background:#3157d5;color:white}table{width:100%;margin-top:2rem;border-collapse:collapse}th,td{text-align:left;padding:.7rem;border-bottom:1px solid #e5eaf1}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM composer:2.8 AS vendor
WORKDIR /app
COPY app/composer.json ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --classmap-authoritative

FROM php:8.3-apache
RUN apt-get update && apt-get install -y --no-install-recommends curl libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*
COPY app/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY app/ /var/www/html/
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --from=frontend /src/dist /var/www/html/public
RUN chown -R www-data:www-data /var/www/html /var/run/apache2 /var/lock/apache2
USER www-data
ENV APACHE_RUN_DIR=/tmp/apache2 APACHE_LOCK_DIR=/tmp/apache2 APACHE_PID_FILE=/tmp/apache2/apache2.pid APACHE_LOG_DIR=/tmp/apache2
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost:8080/health || exit 1
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-app}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-local-development-only}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 20 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/04-php-inventory-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}
      APP_ENV: local
    ports: ["${PUBLIC_PORT:-8084}:8080"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'k8s/overlays/dev/postgres.yaml' @'
apiVersion: apps/v1
kind: Deployment
metadata: { name: postgres, namespace: inventory-php }
spec:
  replicas: 1
  selector: { matchLabels: { app.kubernetes.io/name: postgres } }
  template:
    metadata: { labels: { app.kubernetes.io/name: postgres } }
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          envFrom: [{ secretRef: { name: inventory-runtime } }]
          ports: [{ name: postgres, containerPort: 5432 }]
          readinessProbe: { exec: { command: ["pg_isready","-U","app","-d","app"] }, periodSeconds: 5 }
          resources: { requests: { cpu: 50m, memory: 128Mi }, limits: { cpu: 250m, memory: 256Mi } }
          volumeMounts: [{ name: data, mountPath: /var/lib/postgresql/data }]
          securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 70, capabilities: { drop: ["ALL"] } }
      volumes: [{ name: data, emptyDir: {} }]
---
apiVersion: v1
kind: Service
metadata: { name: postgres, namespace: inventory-php }
spec:
  selector: { app.kubernetes.io/name: postgres }
  ports: [{ name: postgres, port: 5432, targetPort: postgres }]
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'k8s/overlays/dev/kustomization.yaml' @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: inventory-php
resources:
  - ../../base
  - secret.local.yaml
  - postgres.yaml
nameSuffix: -dev
patches:
  - target: { kind: Deployment, labelSelector: app.kubernetes.io/part-of=inventory }
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
images:
  - name: ghcr.io/replace-me/04-php-inventory-monolith-app
    newTag: dev
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/app" -w /app php:8.3-cli sh -c 'find . -name "*.php" -print0 | xargs -0 -n1 php -l'
docker run --rm -v "$PWD/app:/app" -w /app composer:2.8 validate --strict
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
