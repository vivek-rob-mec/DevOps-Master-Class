FROM python:3.14-slim
WORKDIR /workspace
COPY requirements.lock .
RUN pip install --no-cache-dir -r requirements.lock
COPY mlops_common/ mlops_common/
COPY 04-aiops-incident-triage/ 04-aiops-incident-triage/
RUN mkdir -p /state /telemetry && chown -R 10001:10001 /state /telemetry
ENV STATE_DIR=/state TELEMETRY_DB=/telemetry/telemetry.db PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
USER 10001:10001
EXPOSE 8080
CMD ["python", "04-aiops-incident-triage/run.py", "serve", "--host", "0.0.0.0", "--port", "8080"]
