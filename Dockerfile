FROM rocker/binder:4.4.1

ARG NB_USER=jovyan
ARG NB_UID=1000

ENV APP_HOME=/home/pawar

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

COPY install.R /tmp/install.R

RUN Rscript /tmp/install.R

RUN mkdir -p ${APP_HOME}

COPY . ${APP_HOME}

# Application location used by Shiny
RUN chown -R ${NB_UID}:users ${APP_HOME} \
    && chmod -R a+rX ${APP_HOME} \
    && chmod +x ${APP_HOME}/start

# Separate editable copy visible in the RStudio Files pane
RUN mkdir -p /home/rstudio/pawar \
    && cp -a ${APP_HOME}/. /home/rstudio/pawar/ \
    && chmod -R a+rwX /home/rstudio/pawar
RUN mkdir -p /home/${NB_USER}/.jupyter

COPY jupyter_server_config.py \
    /home/${NB_USER}/.jupyter/jupyter_server_config.py

RUN chown -R ${NB_UID}:users \
    /home/${NB_USER}/.jupyter
    
USER ${NB_USER}

WORKDIR ${APP_HOME}
