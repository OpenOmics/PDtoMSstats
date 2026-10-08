# syntax=docker/dockerfile:1

ARG R_VERSION=4.5.2
FROM rocker/r-ver:${R_VERSION}

ARG QUARTO_VERSION=1.8.26
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    BIOCONDUCTOR_VERSION=3.21 \
    PDTOMSTATS_INSTALL_CORES=2 \
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    RENV_CONFIG_CACHE_ENABLED=FALSE

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      git \
      libbz2-dev \
      libcairo2-dev \
      libcurl4-openssl-dev \
      libfontconfig1-dev \
      libfreetype6-dev \
      libfribidi-dev \
      libgit2-dev \
      libglpk-dev \
      libgsl-dev \
      libharfbuzz-dev \
      libicu-dev \
      libjpeg-dev \
      liblzma-dev \
      libnlopt-dev \
      libpng-dev \
      libssl-dev \
      libtiff-dev \
      libuv1-dev \
      libx11-dev \
      libxml2-dev \
      libxt-dev \
      libzstd-dev \
      locales \
      make \
      pandoc \
      tcl8.6-dev \
      tk8.6-dev \
      unzip \
      zlib1g-dev \
    && case "${TARGETARCH}" in \
         amd64) quarto_arch="amd64" ;; \
         arm64) quarto_arch="arm64" ;; \
         *) echo "Unsupported Docker architecture: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${quarto_arch}.deb" \
      -o /tmp/quarto.deb \
    && apt-get install -y --no-install-recommends /tmp/quarto.deb \
    && rm -f /tmp/quarto.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/PDtoMSstats

# The dependency manifest is copied first so package installation remains
# cached when only analysis code or documentation changes.
COPY R/dependencies.R R/dependencies.R
COPY scripts/install_dependencies.R scripts/install_dependencies.R
RUN --mount=type=secret,id=corporate_ca,required=false \
    if [ -s /run/secrets/corporate_ca ]; then \
      cp /run/secrets/corporate_ca /usr/local/share/ca-certificates/pdtomsstats-build-ca.crt; \
      update-ca-certificates; \
    fi \
    && Rscript scripts/install_dependencies.R --cran-only \
    && if [ -s /run/secrets/corporate_ca ]; then \
      rm -f /usr/local/share/ca-certificates/pdtomsstats-build-ca.crt; \
      update-ca-certificates --fresh; \
    fi

RUN --mount=type=secret,id=corporate_ca,required=false \
    if [ -s /run/secrets/corporate_ca ]; then \
      cp /run/secrets/corporate_ca /usr/local/share/ca-certificates/pdtomsstats-build-ca.crt; \
      update-ca-certificates; \
    fi \
    && Rscript scripts/install_dependencies.R --bioc-only \
    && if [ -s /run/secrets/corporate_ca ]; then \
      rm -f /usr/local/share/ca-certificates/pdtomsstats-build-ca.crt; \
      update-ca-certificates --fresh; \
    fi

COPY . .

RUN Rscript scripts/check_environment.R \
    && Rscript tests/test_structure.R \
    && Rscript tests/test_example_data.R \
    && Rscript tests/test_input_functions.R \
    && Rscript tests/test_contrast_functions.R

CMD ["Rscript", "scripts/check_environment.R"]
