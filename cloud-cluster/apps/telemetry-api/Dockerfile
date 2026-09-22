FROM python:3.12-slim

WORKDIR /app
COPY app.py ./

ENV PORT=8080 \
    PYTHONUNBUFFERED=1

USER 65532:65532
EXPOSE 8080

CMD ["python", "app.py"]
