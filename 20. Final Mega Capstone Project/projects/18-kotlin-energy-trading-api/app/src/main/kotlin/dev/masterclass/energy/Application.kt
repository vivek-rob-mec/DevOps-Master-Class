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
