# === Builder stage: Build ASAP and Pyvips from source ===
FROM ubuntu:22.04 as builder

ARG VIPS_VERSION=8.14.2
ARG ASAP_URL=https://github.com/computationalpathologygroup/ASAP/releases/download/ASAP-2.1-(Nightly)/ASAP-2.1-Ubuntu2204.deb

ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Amsterdam

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server curl wget cmake libglib2.0-dev \
         gcc clang htop xz-utils ca-certificates \
        python3-pip python3-dev libopencv-dev python3-opencv \
        libqt5concurrent5 libqt5core5a libqt5gui5 libqt5widgets5 \
        man  apt-transport-https sudo git subversion \
        g++ meson ninja-build pv bzip2 zip unzip dcmtk libboost-all-dev \
        libgomp1 libjpeg-turbo8 libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
        libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
        libexpat1-dev liblzma-dev tk-dev gcovr libffi-dev uuid-dev \
        libgtk2.0-dev libgsf-1-dev libtiff5-dev libopenslide-dev \
        libgl1-mesa-glx libgirepository1.0-dev libexif-dev librsvg2-dev fftw3-dev orc-0.4-dev \
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

# === Pathology CPU Base Image with Pyvips and ASAP ===
FROM ubuntu:22.04 as base-cpu

ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Amsterdam

# Copy compiled binaries and libraries from the builder stage
COPY --from=builder /usr/local/bin/vips* /usr/local/bin/
COPY --from=builder /usr/local/include/vips /usr/local/include/vips
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/libvips.so* /usr/local/lib/x86_64-linux-gnu/
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/vips-modules-8.14 /usr/local/lib/x86_64-linux-gnu/vips-modules-8.14
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/pkgconfig/vips*.pc /usr/local/lib/x86_64-linux-gnu/pkgconfig/
COPY --from=builder /opt/ASAP /opt/ASAP
COPY --from=builder /usr/local/lib/python3.10/dist-packages/asap.pth /usr/local/lib/python3.10/dist-packages/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libijg8.so.16 /usr/lib/x86_64-linux-gnu/

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        nano vim git openssh-server libopencv-dev libgsf-1-dev libfftw3-dev \
        wget \
        libopenslide0 python3-pip python3 python3-opencv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add ASAP to Python path
ENV PYTHONPATH=/opt/ASAP/bin/:$PYTHONPATH

# Copy and install common Python Packages
COPY requirements-base.txt /tmp/
RUN pip install -r /tmp/requirements-base.txt

# Run stage specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py base-cpu


# === Pathology Pytorch Base Image with Pyvips and ASAP ===
FROM base-cpu as pytorch
# Set ARGs for CUDA version
ARG CUDA_VERSION=118
ARG TORCH_VERSION=2.0.1
ARG TORCHVISION_VERSION=0.15.2

# Install PyTorch and torchvision with the same CUDA version
RUN pip install torch==${TORCH_VERSION}+cu${CUDA_VERSION} torchvision==${TORCHVISION_VERSION}+cu${CUDA_VERSION} -f https://download.pytorch.org/whl/torch_stable.html

# Copy and install common Python Packages
COPY requirements-gpu.txt /tmp/
RUN pip install -r /tmp/requirements-gpu.txt

# Run stage specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py pytorch

# === TensorFlow Stage ===
FROM base-cpu as tensorflow

# Propagate build args
ARG TENSORFLOW_VERSION=2.12.0

# Install TensorFlow
RUN pip install tensorflow[and-cuda]==${TENSORFLOW_VERSION} -f https://download.pytorch.org/whl/torch_stable.html

# Set TensorFlow-specific environment variables
ENV FOR_DISABLE_CONSOLE_CTRL_HANDLER 1
ENV TF_CPP_MIN_LOG_LEVEL 3
RUN env | grep '^FOR_DISABLE_CONSOLE_CTRL_HANDLER=\|^TF_CPP_MIN_LOG_LEVEL=' >> /etc/environment

# Run stage specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py tensorflow

# === CPU Version ===
FROM base-cpu as cpu

# Copy and install common Python Packages
COPY requirements-cpu.txt /tmp/
RUN pip install -r /tmp/requirements-cpu.txt

# Run stage specific tests
COPY tests.py /tests/
RUN python3 /tests/tests.py base-cpu