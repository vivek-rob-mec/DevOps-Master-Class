package v1alpha1
import (
 metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
 "k8s.io/apimachinery/pkg/runtime"
)
func(in *Environment)DeepCopyInto(out *Environment){*out=*in;in.ObjectMeta.DeepCopyInto(&out.ObjectMeta);if in.Status.Conditions!=nil{out.Status.Conditions=make([]metav1.Condition,len(in.Status.Conditions));copy(out.Status.Conditions,in.Status.Conditions)}}
func(in *Environment)DeepCopy()*Environment{if in==nil{return nil};out:=new(Environment);in.DeepCopyInto(out);return out}
func(in *Environment)DeepCopyObject()runtime.Object{return in.DeepCopy()}
func(in *EnvironmentList)DeepCopyInto(out *EnvironmentList){*out=*in;in.ListMeta.DeepCopyInto(&out.ListMeta);if in.Items!=nil{out.Items=make([]Environment,len(in.Items));for i:=range in.Items{in.Items[i].DeepCopyInto(&out.Items[i])}}}
func(in *EnvironmentList)DeepCopy()*EnvironmentList{if in==nil{return nil};out:=new(EnvironmentList);in.DeepCopyInto(out);return out}
func(in *EnvironmentList)DeepCopyObject()runtime.Object{return in.DeepCopy()}
