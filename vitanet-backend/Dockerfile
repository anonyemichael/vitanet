FROM python:3.11-slim

WORKDIR /code

# Install postgres client and build dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install exactly what requirements.txt lists (the old hand-written list here had drifted: it still installed
# google-genai and lacked openai, PyYAML, httpx and python-multipart, so the current server could not start).
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./alembic.ini /code/alembic.ini
COPY ./alembic /code/alembic
COPY ./app /code/app

# Command to run the application (Runs migrations first, then starts the server)
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
