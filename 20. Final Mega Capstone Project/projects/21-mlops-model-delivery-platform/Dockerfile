FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app api/ api/
COPY --chown=app:app trainer/ trainer/
COPY --chown=app:app platform_lib/ platform_lib/
USER 10001:10001
ENV PYTHONPATH=/app
EXPOSE 8080
CMD ["uvicorn","api.main:app","--host","0.0.0.0","--port","8080","--workers","2"]
