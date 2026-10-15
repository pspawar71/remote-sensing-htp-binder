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

# Install required R packages
COPY install.R /tmp/install.R

RUN Rscript /tmp/install.R

# Create the application directory
RUN mkdir -p ${APP_HOME}

# Copy the GitHub repository to /home/pawar
COPY --chown=${NB_UID}:users . ${APP_HOME}

# Make the project available from the RStudio home directory
RUN mkdir -p /home/rstudio \
    && ln -sfn ${APP_HOME} /home/rstudio/pawar \
    && chown -R ${NB_UID}:users ${APP_HOME} \
    && chown -h rstudio:rstudio /home/rstudio/pawar \
    && chmod +x ${APP_HOME}/start

# Automatically open /home/pawar when RStudio starts
RUN printf 'setwd(\"/home/pawar\")\n' > /home/rstudio/.Rprofile \
    && chown rstudio:rstudio /home/rstudio/.Rprofile

USER ${NB_USER}

WORKDIR ${APP_HOME}
