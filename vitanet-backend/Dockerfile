FROM python:3.11-slim

WORKDIR /code

# Install postgres client and build dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Write requirements directly to avoid encoding issues
RUN echo "alembic==1.18.5" > /code/requirements.txt && \
    echo "annotated-types==0.8.0" >> /code/requirements.txt && \
    echo "anyio==4.14.2" >> /code/requirements.txt && \
    echo "click==8.4.2" >> /code/requirements.txt && \
    echo "colorama==0.4.6" >> /code/requirements.txt && \
    echo "dnspython==2.8.0" >> /code/requirements.txt && \
    echo "email-validator==2.3.0" >> /code/requirements.txt && \
    echo "fastapi==0.140.0" >> /code/requirements.txt && \
    echo "firebase-admin==6.6.0" >> /code/requirements.txt && \
    echo "google-genai==1.19.0" >> /code/requirements.txt && \
    echo "greenlet==3.5.4" >> /code/requirements.txt && \
    echo "h11==0.16.0" >> /code/requirements.txt && \
    echo "idna==3.18" >> /code/requirements.txt && \
    echo "Mako==1.3.12" >> /code/requirements.txt && \
    echo "MarkupSafe==3.0.3" >> /code/requirements.txt && \
    echo "phonenumbers==9.0.35" >> /code/requirements.txt && \
    echo "psycopg2-binary==2.9.12" >> /code/requirements.txt && \
    echo "pydantic==2.13.4" >> /code/requirements.txt && \
    echo "pydantic-settings==2.14.2" >> /code/requirements.txt && \
    echo "pydantic_core==2.46.4" >> /code/requirements.txt && \
    echo "python-dotenv==1.2.2" >> /code/requirements.txt && \
    echo "resend==2.10.0" >> /code/requirements.txt && \
    echo "SQLAlchemy==2.0.51" >> /code/requirements.txt && \
    echo "starlette==1.3.1" >> /code/requirements.txt && \
    echo "typing_extensions==4.16.0" >> /code/requirements.txt && \
    echo "uvicorn==0.51.0" >> /code/requirements.txt

RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./alembic.ini /code/alembic.ini
COPY ./alembic /code/alembic
COPY ./app /code/app

# Command to run the application (Runs migrations first, then starts the server)
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
