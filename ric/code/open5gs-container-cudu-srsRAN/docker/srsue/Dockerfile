# srsRAN 4G srsUE - 5G SA NR com ZMQ (no-RF)
# Ref: https://github.com/s5uishida/build_srsran_4g_zmq_disable_rf_plugins
# Ref: https://docs.srsran.com/projects/4g/en/latest/app_notes/source/5g_sa_E2E/
#
# Build: docker build -t srsue:latest -f docker/srsue/Dockerfile .
# Run:  docker run --rm -it --privileged -v $(pwd)/configs/srsRAN:/config srsue:latest

FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Dependências para build srsRAN 4G (ZMQ, sem UHD/SDR)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    git \
    libzmq3-dev \
    libconfig++-dev \
    libsctp-dev \
    libmbedtls-dev \
    libboost-program-options-dev \
    libfftw3-dev \
    libvolk-dev \
    && rm -rf /var/lib/apt/lists/*

# Commit testado (srsRAN 4G 23.11+)
ARG SRSRAN_COMMIT=ec29b0c1ff79cebcbe66caa6d6b90778261c42b8

WORKDIR /build

RUN git clone https://github.com/srsran/srsRAN_4G.git \
    && cd srsRAN_4G \
    && git checkout ${SRSRAN_COMMIT}

WORKDIR /build/srsRAN_4G/build

# ENABLE_RF_PLUGINS=OFF: linka ZMQ diretamente, sem UHD/bladeRF
RUN cmake .. -DENABLE_RF_PLUGINS=OFF -DCMAKE_CXX_FLAGS="-Wno-error=array-bounds" \
    && make -j$(nproc) srsue \
    && make install

# Imagem final (menor)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Pacotes runtime (usar nomes genéricos para compatibilidade Ubuntu 24.04)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libzmq5 \
    libconfig++9v5 \
    libsctp1 \
    libmbedtls14t64 \
    libboost-program-options1.83.0 \
    libfftw3-double3 \
    libfftw3-single3 \
    libvolk3.1t64 \
    iproute2 \
    iputils-ping \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# srsRAN 4G instala em /usr/local por padrão
COPY --from=builder /usr/local/bin/srsue /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
RUN ldconfig

# srsUE cria interface TUN → precisa de /dev/net/tun e NET_ADMIN
# Não roda como root quando possível; srsUE exige root para TUN
WORKDIR /config

ENTRYPOINT ["/usr/local/bin/srsue"]
CMD ["--ue.phy", "nr", "/config/ue.conf"]
