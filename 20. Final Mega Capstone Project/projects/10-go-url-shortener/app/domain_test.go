package main
import"testing"
func TestNormalizeURL(t *testing.T){value,err:=normalizeURL(" https://example.com/docs#part ");if err!=nil||value!="https://example.com/docs"{t.Fatalf("unexpected result %q %v",value,err)}}
func TestRejectsUnsafeScheme(t *testing.T){if _,err:=normalizeURL("javascript:alert(1)");err==nil{t.Fatal("unsafe scheme accepted")}}
func TestCodeIsStable(t *testing.T){if codeFor("same-key")!=codeFor("same-key"){t.Fatal("code is not stable")}}
