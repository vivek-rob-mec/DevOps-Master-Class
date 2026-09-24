package main
import (
 "flag"
 "os"
 clientgoscheme "k8s.io/client-go/kubernetes/scheme"
 "k8s.io/apimachinery/pkg/runtime"
 utilruntime "k8s.io/apimachinery/pkg/util/runtime"
 ctrl "sigs.k8s.io/controller-runtime"
 "sigs.k8s.io/controller-runtime/pkg/healthz"
 "sigs.k8s.io/controller-runtime/pkg/log/zap"
 metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
 platformv1alpha1 "example.com/environment-operator/api/v1alpha1"
 "example.com/environment-operator/internal/controller"
)
var scheme=runtime.NewScheme()
func init(){utilruntime.Must(clientgoscheme.AddToScheme(scheme));utilruntime.Must(platformv1alpha1.AddToScheme(scheme))}
func main(){var metricsAddress,probeAddress string;flag.StringVar(&metricsAddress,"metrics-bind-address",":8080","metrics address");flag.StringVar(&probeAddress,"health-probe-bind-address",":8081","probe address");options:=zap.Options{Development:false};options.BindFlags(flag.CommandLine);flag.Parse();ctrl.SetLogger(zap.New(zap.UseFlagOptions(&options)));manager,error:=ctrl.NewManager(ctrl.GetConfigOrDie(),ctrl.Options{Scheme:scheme,Metrics:metricsserver.Options{BindAddress:metricsAddress},HealthProbeBindAddress:probeAddress,LeaderElection:true,LeaderElectionID:"environment-operator.platform.masterclass.io"});if error!=nil{os.Exit(1)};if error=(&controller.EnvironmentReconciler{Client:manager.GetClient(),Scheme:manager.GetScheme()}).SetupWithManager(manager);error!=nil{os.Exit(1)};_ = manager.AddHealthzCheck("healthz",healthz.Ping);_ = manager.AddReadyzCheck("readyz",healthz.Ping);if error=manager.Start(ctrl.SetupSignalHandler());error!=nil{os.Exit(1)}}
