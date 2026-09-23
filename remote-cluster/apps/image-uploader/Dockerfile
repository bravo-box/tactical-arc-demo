FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --gid 65532 app && \
    useradd --uid 65532 --gid app --no-create-home app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py device_info_client.py location_client.py ./
USER 65532:65532
ENTRYPOINT ["python", "app.py"]
