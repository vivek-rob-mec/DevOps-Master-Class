package rules
import "testing"
func TestValidate(t *testing.T){tests:=[]struct{name,owner,cpu,memory string;valid bool}{{"valid","payments-team","4","8Gi",true},{"owner","Payments","4","8Gi",false},{"cpu","payments-team","zero","8Gi",false},{"memory","payments-team","4","0",false}};for _,test:=range tests{t.Run(test.name,func(t *testing.T){error:=Validate(test.owner,test.cpu,test.memory);if (error==nil)!=test.valid{t.Fatalf("valid=%v error=%v",test.valid,error)}})}}
