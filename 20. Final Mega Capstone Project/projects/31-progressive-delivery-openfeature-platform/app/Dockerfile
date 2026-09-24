FROM python:3.14.1-slim
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY --chown=10001:10001 app app
COPY --chown=10001:10001 delivery delivery
COPY --chown=10001:10001 flags /flags
USER 10001:10001
EXPOSE 8080
CMD ["python", "-m", "app.main"]
