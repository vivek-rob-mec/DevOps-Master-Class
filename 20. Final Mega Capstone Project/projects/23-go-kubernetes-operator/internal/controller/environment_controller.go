package controller
import (
 "context"
 "fmt"
 corev1 "k8s.io/api/core/v1"
 networkingv1 "k8s.io/api/networking/v1"
 apierrors "k8s.io/apimachinery/pkg/api/errors"
 "k8s.io/apimachinery/pkg/api/meta"
 "k8s.io/apimachinery/pkg/api/resource"
 metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
 "k8s.io/apimachinery/pkg/types"
 "k8s.io/apimachinery/pkg/runtime"
 ctrl "sigs.k8s.io/controller-runtime"
 "sigs.k8s.io/controller-runtime/pkg/client"
 "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
 platformv1alpha1 "example.com/environment-operator/api/v1alpha1"
 "example.com/environment-operator/internal/rules"
)
const finalizer="platform.masterclass.io/environment-cleanup"
type EnvironmentReconciler struct{client.Client;Scheme *runtime.Scheme}
func(r *EnvironmentReconciler)Reconcile(ctx context.Context,request ctrl.Request)(ctrl.Result,error){
 environment:=&platformv1alpha1.Environment{};if error:=r.Get(ctx,request.NamespacedName,environment);error!=nil{return ctrl.Result{},client.IgnoreNotFound(error)}
 namespaceName:="tenant-"+environment.Name
 if !environment.DeletionTimestamp.IsZero(){return r.finalize(ctx,environment,namespaceName)}
 if !controllerutil.ContainsFinalizer(environment,finalizer){controllerutil.AddFinalizer(environment,finalizer);if error:=r.Update(ctx,environment);error!=nil{return ctrl.Result{},error}}
 if error:=rules.Validate(environment.Spec.Owner,environment.Spec.CPUQuota,environment.Spec.MemoryQuota);error!=nil{return ctrl.Result{},r.setCondition(ctx,environment,metav1.ConditionFalse,"InvalidSpec",error.Error())}
 labels:=map[string]string{"platform.masterclass.io/environment":environment.Name,"platform.masterclass.io/owner":environment.Spec.Owner}
 namespace:=&corev1.Namespace{ObjectMeta:metav1.ObjectMeta{Name:namespaceName}}
 if _,error:=controllerutil.CreateOrUpdate(ctx,r.Client,namespace,func()error{namespace.Labels=labels;return controllerutil.SetControllerReference(environment,namespace,r.Scheme)});error!=nil{return ctrl.Result{},error}
 quota:=&corev1.ResourceQuota{ObjectMeta:metav1.ObjectMeta{Name:"tenant-quota",Namespace:namespaceName}}
 if _,error:=controllerutil.CreateOrUpdate(ctx,r.Client,quota,func()error{quota.Spec.Hard=corev1.ResourceList{corev1.ResourceRequestsCPU:resource.MustParse(environment.Spec.CPUQuota),corev1.ResourceRequestsMemory:resource.MustParse(environment.Spec.MemoryQuota),corev1.ResourceLimitsCPU:resource.MustParse(environment.Spec.CPUQuota),corev1.ResourceLimitsMemory:resource.MustParse(environment.Spec.MemoryQuota)};return controllerutil.SetControllerReference(environment,quota,r.Scheme)});error!=nil{return ctrl.Result{},error}
 limits:=&corev1.LimitRange{ObjectMeta:metav1.ObjectMeta{Name:"tenant-defaults",Namespace:namespaceName}}
 if _,error:=controllerutil.CreateOrUpdate(ctx,r.Client,limits,func()error{limits.Spec.Limits=[]corev1.LimitRangeItem{{Type:corev1.LimitTypeContainer,DefaultRequest:corev1.ResourceList{corev1.ResourceCPU:resource.MustParse("50m"),corev1.ResourceMemory:resource.MustParse("64Mi")},Default:corev1.ResourceList{corev1.ResourceCPU:resource.MustParse("500m"),corev1.ResourceMemory:resource.MustParse("512Mi")}}};return controllerutil.SetControllerReference(environment,limits,r.Scheme)});error!=nil{return ctrl.Result{},error}
 policy:=&networkingv1.NetworkPolicy{ObjectMeta:metav1.ObjectMeta{Name:"default-deny",Namespace:namespaceName}}
 if _,error:=controllerutil.CreateOrUpdate(ctx,r.Client,policy,func()error{policy.Spec.PodSelector=metav1.LabelSelector{};policy.Spec.PolicyTypes=[]networkingv1.PolicyType{networkingv1.PolicyTypeIngress,networkingv1.PolicyTypeEgress};return controllerutil.SetControllerReference(environment,policy,r.Scheme)});error!=nil{return ctrl.Result{},error}
 environment.Status.Namespace=namespaceName;return ctrl.Result{},r.setCondition(ctx,environment,metav1.ConditionTrue,"Reconciled","tenant controls match desired state")
}
func(r *EnvironmentReconciler)finalize(ctx context.Context,environment *platformv1alpha1.Environment,namespace string)(ctrl.Result,error){if !controllerutil.ContainsFinalizer(environment,finalizer){return ctrl.Result{},nil};if environment.Spec.DeleteNamespace{target:=&corev1.Namespace{};error:=r.Get(ctx,types.NamespacedName{Name:namespace},target);if error==nil{if error=r.Delete(ctx,target);error!=nil{return ctrl.Result{},error};return ctrl.Result{RequeueAfter:2e9},nil};if !apierrors.IsNotFound(error){return ctrl.Result{},error}};controllerutil.RemoveFinalizer(environment,finalizer);return ctrl.Result{},r.Update(ctx,environment)}
func(r *EnvironmentReconciler)setCondition(ctx context.Context,environment *platformv1alpha1.Environment,status metav1.ConditionStatus,reason,message string)error{environment.Status.ObservedGeneration=environment.Generation;meta.SetStatusCondition(&environment.Status.Conditions,metav1.Condition{Type:"Ready",Status:status,Reason:reason,Message:message,ObservedGeneration:environment.Generation});if error:=r.Status().Update(ctx,environment);error!=nil{return fmt.Errorf("update status: %w",error)};return nil}
func(r *EnvironmentReconciler)SetupWithManager(manager ctrl.Manager)error{return ctrl.NewControllerManagedBy(manager).For(&platformv1alpha1.Environment{}).Owns(&corev1.Namespace{}).Complete(r)}
