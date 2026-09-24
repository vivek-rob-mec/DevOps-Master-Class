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
