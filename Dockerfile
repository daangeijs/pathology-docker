ARG UBUNTU_VERSION=22.04
ARG CUDA_VERSION=11.8
ARG CUDNN_VERSION=8
ARG PYTHON_VERSION=3.10

# === Base Python Environment Builder Stage ===
FROM python:${PYTHON_VERSION} as poetry-base
# Install Poetry
RUN pip install poetry==1.4.2
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache
COPY pyproject.toml poetry.lock* /pyenv/
WORKDIR /pyenv
# Install base dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --only main
# Setting up a clear environment path
ENV PYTHON_BASE_ENV=/pyenv/.venv
ENV PATH="$PYTHON_BASE_ENV/bin:$PATH"

# === CPU Environment Extension Stage ===
FROM poetry-base as poetry-cpu
# Install CPU-specific dependencies
RUN poetry install -E cpu --only main

# === GPU Environment Extension Stage ===
FROM poetry-base as poetry-gpu
# Install GPU-specific dependencies
RUN poetry install -E gpu --only main


# === Builder stage: Build ASAP and Pyvips from source ===
FROM ubuntu:${UBUNTU_VERSION} as builder

ARG VIPS_VERSION=8.14.2
ARG ASAP_URL=https://github.com/computationalpathologygroup/ASAP/releases/download/ASAP-2.1-(Nightly)/ASAP-2.1-Ubuntu2204.deb

ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Amsterdam

# Install system dependencies for building ASAP and Pyvips
RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server curl wget cmake libglib2.0-dev \
        gcc clang htop xz-utils ca-certificates \
        libopencv-dev python3-pip python3-dev python3-opencv \
        libqt5concurrent5 libqt5core5a libqt5gui5 libqt5widgets5 \
        man apt-transport-https sudo git subversion \
        g++ meson ninja-build pv bzip2 zip unzip dcmtk libboost-all-dev \
        libgomp1 libjpeg-turbo8 libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
        libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
        libexpat1-dev liblzma-dev tk-dev gcovr libffi-dev uuid-dev \
        libgtk2.0-dev libgsf-1-dev libtiff5-dev libopenslide-dev \
        libgl1-mesa-glx libgirepository1.0-dev libexif-dev librsvg2-dev orc-0.4-dev \
    && rm -rf /var/lib/apt/lists/*

# Install ASAP
RUN curl -L ${ASAP_URL} -o /tmp/ASAP.deb && apt-get install --assume-yes /tmp/ASAP.deb && \
    SITE_PACKAGES=`python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])"` && \
    printf "/opt/ASAP/bin/\n" > "${SITE_PACKAGES}/asap.pth" && apt-get clean

# Install VIPS
RUN wget https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz -P /tmp && \
    tar -xf /tmp/vips-${VIPS_VERSION}.tar.xz --directory /tmp/ && \
    rm -rf /tmp/vips-${VIPS_VERSION}.tar.xz && \
    cd /tmp/vips-${VIPS_VERSION} && \
    meson setup build --buildtype release --prefix=/usr/local && \
    cd build && meson compile && meson test && meson install && ldconfig


# === CPU Environment Extension Stage ===
FROM ubuntu:${UBUNTU_VERSION} as cpu
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Amsterdam
# Copy compiled ASAP and Pyvips from builder stage
COPY --from=builder /usr/local/bin/vips* /usr/local/bin/
COPY --from=builder /usr/local/include/vips /usr/local/include/vips
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/libvips.so* /usr/local/lib/x86_64-linux-gnu/
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/vips-modules-8.14 /usr/local/lib/x86_64-linux-gnu/vips-modules-8.14
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/pkgconfig/vips*.pc /usr/local/lib/x86_64-linux-gnu/pkgconfig/
COPY --from=builder /usr/local/lib/python3.10/dist-packages/asap.pth /usr/local/lib/python3.10/dist-packages/
COPY --from=builder /opt/ASAP /opt/ASAP
COPY --from=builder /usr/lib/x86_64-linux-gnu/libijg8.so.16 /usr/lib/x86_64-linux-gnu/
# Copy Python environment from poetry-base
COPY --from=poetry-base $PYTHON_BASE_ENV $PYTHON_BASE_ENV
ENV PATH="$PYTHON_BASE_ENV/bin:$PATH"
# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        nano vim git openssh-server libopencv-dev libgsf-1-dev libfftw3-dev \
        wget \
        libopenslide0 libtiff5 python3-opencv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# Add ASAP to Python path
ENV PYTHONPATH=/opt/ASAP/bin/:$PYTHONPATH
# Run stage specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py base-cpu

# === Pathology Pytorch Base Image with Pyvips and ASAP ===
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-runtime-ubuntu${UBUNTU_VERSION} as pytorch
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Amsterdam
# Copy Python environment from poetry-base
COPY --from=poetry-base $PYTHON_BASE_ENV $PYTHON_BASE_ENV
ENV PATH="$PYTHON_BASE_ENV/bin:$PATH"
# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        nano vim git openssh-server libopencv-dev libgsf-1-dev libfftw3-dev \
        wget \
        libopenslide0 python3-pip python3 python3-opencv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# Add ASAP to Python path
ENV PYTHONPATH=/opt/ASAP/bin/:$PYTHONPATH
# Set arguments for CUDA and PyTorch/Torchvision versions
ARG CUDA_VERSION=118
ARG TORCH_VERSION=2.0.1
ARG TORCHVISION_VERSION=0.15.2
# Install PyTorch and torchvision with the same CUDA version
COPY requirements-gpu.txt /tmp/
RUN pip3 install torch==${TORCH_VERSION}+cu${CUDA_VERSION} torchvision==${TORCHVISION_VERSION}+cu${CUDA_VERSION} -f https://download.pytorch.org/whl/torch_stable.html \
    && rm -rf /root/.cache/pip  # Clear pip cache
# Run stage-specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py pytorch
