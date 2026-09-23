FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir --requirement requirements.txt

COPY --chown=65532:65532 app.py ./

ENV PYTHONUNBUFFERED=1

USER 65532:65532

CMD ["python", "app.py"]
