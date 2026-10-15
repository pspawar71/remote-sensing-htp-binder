FROM rocker/binder:4.4.1

ARG NB_USER=jovyan
ARG NB_UID=1000

ENV APP_HOME=/home/pawar

USER root

# System libraries required by terra, sf, and leaflet dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
COPY install.R /tmp/install.R

RUN Rscript /tmp/install.R \
    && rm -f /tmp/install.R

# Create the application directory
RUN mkdir -p ${APP_HOME}

# Copy the repository to /home/pawar
COPY . ${APP_HOME}

# Set permissions and make the Binder startup hook executable
RUN chown -R ${NB_UID}:users ${APP_HOME} \
    && chmod -R a+rX ${APP_HOME} \
    && chmod +x ${APP_HOME}/start

# Create a shortcut visible from the RStudio home directory
RUN mkdir -p /home/rstudio \
    && ln -sfn ${APP_HOME} /home/rstudio/pawar

USER ${NB_USER}

WORKDIR ${APP_HOME}
