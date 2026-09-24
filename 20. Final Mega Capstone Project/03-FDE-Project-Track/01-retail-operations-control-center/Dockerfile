FROM python:3.14-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 STATE_DIR=/app/state
WORKDIR /app
COPY requirements.lock ./
RUN pip install --no-cache-dir -r requirements.lock && useradd --uid 10001 --create-home learner
COPY app.py ./
COPY frontend ./frontend
COPY data ./data
RUN mkdir -p /app/state && chown -R 10001:10001 /app
USER 10001:10001
EXPOSE 8216
CMD ["python", "app.py", "serve", "--host", "0.0.0.0"]
