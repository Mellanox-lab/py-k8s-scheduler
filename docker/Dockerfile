FROM harbor.mellanox.com/swx-storage/x86_64/python3-kubernetes:12.0
LABEL maintainer="yuriis@nvidia.com"
COPY pod_thr_sched2.py /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -q update && apt-get -y install git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
