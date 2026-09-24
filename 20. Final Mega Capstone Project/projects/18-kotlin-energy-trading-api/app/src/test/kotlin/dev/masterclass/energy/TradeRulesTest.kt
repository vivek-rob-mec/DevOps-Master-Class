package dev.masterclass.energy
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import java.math.BigDecimal
class TradeRulesTest{@Test fun normalizesValidTrade(){val value=TradeRules.parse(TradeDraft(" desk-1 ","in",BigDecimal("12.5"),BigDecimal("70"),"buy"));assertEquals("DESK-1",value.portfolio);assertEquals("BUY",value.side)}@Test fun rejectsNegativeVolume(){val error=assertThrows(IllegalArgumentException::class.java){TradeRules.parse(TradeDraft("desk-1","IN",BigDecimal("-1"),BigDecimal("70"),"BUY"))};assertEquals("INVALID_VOLUME",error.message)}}
