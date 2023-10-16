FROM python:3.9-slim

RUN mkdir /app

WORKDIR /app

COPY poetry.lock pyproject.toml /app/

RUN pip install poetry==1.6.1 && \
    poetry export -f requirements.txt -o requirements.txt --without-hashes && \
    pip install -r requirements.txt && \
    rm -f requirements.txt

COPY python_app/ /app/

ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0"]