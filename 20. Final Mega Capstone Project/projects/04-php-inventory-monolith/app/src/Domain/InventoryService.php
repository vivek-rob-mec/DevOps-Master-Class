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
