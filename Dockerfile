# ----- installe les dépendances ----------
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Environnement virtuel isolé, copié tel quel dans l'image finale
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt


# ---------- image finale (exécution uniquement) ----------
FROM python:3.12-slim
# Applique les correctifs de sécurité Debian publiés depuis la construction de l'image de base
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    TASKFLOW_DB=/data/taskflow.db

# Utilisateur dédié, sans shell de connexion
RUN groupadd --system --gid 10001 taskflow \
 && useradd --system --uid 10001 --gid taskflow --no-create-home --shell /usr/sbin/nologin taskflow \
 && mkdir /data \
 && chown taskflow:taskflow /data

WORKDIR /app

# Seuls les paquets installés et le code de l'application sont copiés
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/

USER 10001

EXPOSE 8085
CMD ["python", "-m", "app.app"]
