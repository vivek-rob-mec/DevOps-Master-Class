from django.urls import path
from shipments import views

urlpatterns = [
    path("", views.index),
    path("health", views.health),
    path("metrics", views.metrics),
    path("api/shipments", views.shipments),
]
