FROM rocker/binder:4.4.1

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*
USER ${NB_USER}

COPY --chown=${NB_USER}:users install.R ${HOME}/install.R
RUN Rscript ${HOME}/install.R

COPY --chown=${NB_USER}:users . ${HOME}
WORKDIR ${HOME}
