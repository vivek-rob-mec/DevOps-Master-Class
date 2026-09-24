package v1alpha1
import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
type EnvironmentSpec struct{Owner string `json:"owner"`;CPUQuota string `json:"cpuQuota"`;MemoryQuota string `json:"memoryQuota"`;DeleteNamespace bool `json:"deleteNamespace,omitempty"`}
type EnvironmentStatus struct{ObservedGeneration int64 `json:"observedGeneration,omitempty"`;Namespace string `json:"namespace,omitempty"`;Conditions []metav1.Condition `json:"conditions,omitempty"`}
// +kubebuilder:object:root=true
// +kubebuilder:resource:scope=Cluster,shortName=env
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Namespace",type=string,JSONPath=`.status.namespace`
// +kubebuilder:printcolumn:name="Ready",type=string,JSONPath=`.status.conditions[?(@.type=='Ready')].status`
type Environment struct{metav1.TypeMeta `json:",inline"`;metav1.ObjectMeta `json:"metadata,omitempty"`;Spec EnvironmentSpec `json:"spec,omitempty"`;Status EnvironmentStatus `json:"status,omitempty"`}
// +kubebuilder:object:root=true
type EnvironmentList struct{metav1.TypeMeta `json:",inline"`;metav1.ListMeta `json:"metadata,omitempty"`;Items []Environment `json:"items"`}
func init(){SchemeBuilder.Register(&Environment{},&EnvironmentList{})}
