import os
BASE_DIR=os.path.dirname(os.path.dirname(__file__))
SECRET_KEY=os.getenv("DJANGO_SECRET_KEY","local-development-only")
DEBUG=False
ALLOWED_HOSTS=["*"]
ROOT_URLCONF="config.urls"
WSGI_APPLICATION="config.wsgi.application"
INSTALLED_APPS=["django.contrib.contenttypes","django.contrib.staticfiles","shipments"]
MIDDLEWARE=["django.middleware.security.SecurityMiddleware","django.middleware.common.CommonMiddleware"]
DATABASES={"default":{"ENGINE":"django.db.backends.postgresql","NAME":os.getenv("POSTGRES_DB","app"),"USER":os.getenv("POSTGRES_USER","app"),"PASSWORD":os.getenv("POSTGRES_PASSWORD","local-development-only"),"HOST":os.getenv("POSTGRES_HOST","postgres"),"PORT":"5432","CONN_MAX_AGE":60}}
STATIC_URL="static/"
STATIC_ROOT=os.path.join(BASE_DIR,"staticfiles")
DEFAULT_AUTO_FIELD="django.db.models.BigAutoField"
CELERY_BROKER_URL=os.getenv("REDIS_URL","redis://redis:6379/0")
CELERY_TASK_ACKS_LATE=True
CELERY_TASK_REJECT_ON_WORKER_LOST=True
CELERY_WORKER_PREFETCH_MULTIPLIER=1
