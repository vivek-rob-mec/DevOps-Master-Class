package rules

import (
 "fmt"
 "regexp"
 "strings"
 "k8s.io/apimachinery/pkg/api/resource"
)
var ownerPattern=regexp.MustCompile(`^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$`)
func Validate(owner,cpu,memory string) error{
 owner=strings.TrimSpace(owner)
 if !ownerPattern.MatchString(owner){return fmt.Errorf("owner must be a lowercase DNS label")}
 cpuValue,error:=resource.ParseQuantity(cpu);if error!=nil||cpuValue.Sign()<=0{return fmt.Errorf("cpu quota must be a positive quantity")}
 memoryValue,error:=resource.ParseQuantity(memory);if error!=nil||memoryValue.Sign()<=0{return fmt.Errorf("memory quota must be a positive quantity")}
 return nil
}
