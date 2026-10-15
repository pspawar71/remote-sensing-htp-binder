FROM rocker/binder:4.4.1

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV HOME=/home/${NB_USER}

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*

COPY install.R /tmp/install.R
RUN Rscript /tmp/install.R

COPY --chown=${NB_UID}:users . ${HOME}
RUN chown -R ${NB_UID}:users ${HOME}

USER ${NB_USER}
WORKDIR ${HOME}
