FROM python:3.14.1-slim
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=10001:10001 workflow workflow
COPY --chown=10001:10001 worker.py starter.py ./
USER 10001:10001
CMD ["python", "worker.py"]
