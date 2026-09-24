FROM python:3.14-slim
WORKDIR /app
COPY requirements.lock .
RUN pip install --no-cache-dir -r requirements.lock
COPY app.py .
COPY frontend/ frontend/
RUN mkdir /state && chown 10001:10001 /state
ENV STATE_DIR=/state PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER 10001:10001
EXPOSE 8080
CMD ["python","app.py","serve","--host","0.0.0.0","--port","8080"]
