FROM python:3.14.1-slim
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app gateway/ gateway/
COPY --chown=app:app llmops/ llmops/
USER 10001:10001
ENV PYTHONPATH=/app
EXPOSE 8080
CMD ["uvicorn","gateway.main:app","--host","0.0.0.0","--port","8080"]
