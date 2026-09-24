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
