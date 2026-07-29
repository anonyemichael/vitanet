FROM python:3.11-slim

WORKDIR /code

# Install postgres client and build dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/requirements.txt

# Using utf-16le because the requirements.txt was saved with utf-16le encoding
RUN cat /code/requirements.txt | iconv -f utf-16le -t utf-8 > /code/requirements_utf8.txt \
    && pip install --no-cache-dir --upgrade -r /code/requirements_utf8.txt \
    || pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./alembic.ini /code/alembic.ini
COPY ./alembic /code/alembic
COPY ./app /code/app

# Command to run the application (Runs migrations first, then starts the server)
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
