FROM python:3.12-slim

WORKDIR /app
COPY app.py ./

ENV PYTHONUNBUFFERED=1

USER 65532:65532

CMD ["python", "app.py"]
