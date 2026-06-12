# srsRAN Project CU/DU with ZeroMQ enabled.
# Build: docker build -t open5gs-srsran-cudu-zmq:latest -f docker/srsran-cudu-zmq/Dockerfile docker/srsran-cudu-zmq

FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    git \
    libfftw3-dev \
    libmbedtls-dev \
    libsctp-dev \
    libyaml-cpp-dev \
    libgtest-dev \
    libzmq3-dev \
    pkg-config \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

ARG SRSRAN_PROJECT_REPO=https://github.com/srsran/srsRAN_Project.git
ARG SRSRAN_PROJECT_REF=release_25_04

WORKDIR /build

RUN git clone --depth 1 --branch "${SRSRAN_PROJECT_REF}" "${SRSRAN_PROJECT_REPO}" srsRAN_Project

WORKDIR /build/srsRAN_Project

RUN cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DDU_SPLIT_TYPE=SPLIT_8 \
    -DENABLE_EXPORT=ON \
    -DENABLE_ZEROMQ=ON \
    && cmake --build build --target install -j "$(nproc)" \
    && ldconfig

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    iproute2 \
    iputils-ping \
    libfftw3-double3 \
    libfftw3-single3 \
    libmbedtls14t64 \
    libsctp1 \
    libyaml-cpp0.8 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local

RUN ldconfig \
    && command -v srscu \
    && command -v srsdu \
    && command -v gnb

WORKDIR /config

CMD ["srscu", "--help"]
