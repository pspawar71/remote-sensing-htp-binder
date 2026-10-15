FROM rocker/binder:4.4.1
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV APP_HOME=/home/pawar
USER root
RUN apt-get update && apt-get install -y --no-install-recommends libgdal-dev libgeos-dev libproj-dev libudunits2-dev libtiff-dev libjpeg-dev libpng-dev && rm -rf /var/lib/apt/lists/*
COPY install.R /tmp/install.R
RUN Rscript /tmp/install.R
RUN mkdir -p ${APP_HOME}
COPY --chown=${NB_UID}:users . ${APP_HOME}
RUN chown -R ${NB_UID}:users ${APP_HOME} && chmod +x ${APP_HOME}/start
USER ${NB_USER}
WORKDIR ${APP_HOME}
