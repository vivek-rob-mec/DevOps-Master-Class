package com.example.banking.accounts;
import java.math.BigDecimal;import java.util.*;import java.util.concurrent.ConcurrentHashMap;import org.springframework.boot.*;import org.springframework.boot.autoconfigure.*;import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import org.springframework.web.server.ResponseStatusException;
@SpringBootApplication public class AccountsApplication{public static void main(String[]a){SpringApplication.run(AccountsApplication.class,a);}}
record Account(String id,String owner,String currency,BigDecimal availableBalance){}
@RestController @RequestMapping("/accounts") class AccountController{
 private final Map<String,Account> data=new ConcurrentHashMap<>(Map.of("acct-100",new Account("acct-100","Asha","INR",new BigDecimal("250000.00")),"acct-200",new Account("acct-200","Vikram","INR",new BigDecimal("175000.00"))));
 @GetMapping Collection<Account> list(){return data.values();}
 @GetMapping("/{id}") Account get(@PathVariable String id){var value=data.get(id);if(value==null)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"account not found");return value;}
}
