# Replace this release tag with a verified registry digest in a production fork.
FROM python:3.14.1-slim
ARG REVISION=unknown
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY --chown=app:app main.py .
USER 10001:10001
ENV REVISION=$REVISION PYTHONDONTWRITEBYTECODE=1
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=2s --retries=5 CMD ["python","-c","import urllib.request;urllib.request.urlopen('http://localhost:8080/health')"]
CMD ["python","main.py"]
