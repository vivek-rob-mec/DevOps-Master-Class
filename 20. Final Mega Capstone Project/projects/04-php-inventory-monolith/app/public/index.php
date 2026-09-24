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
