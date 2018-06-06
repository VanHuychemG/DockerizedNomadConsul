FROM ubuntu:16.04

LABEL MAINTAINER="Geert Van Huychem <geert@iframeworx.be>"

SHELL ["/bin/bash", "-c"]

# set up certificates, base tools
RUN set -eux && \
    apt-get update &&  \
    apt-get upgrade -y &&  \
    apt-get -y autoremove &&  \
    apt-get -y autoclean &&  \
    apt-get install -y htop build-essential git unzip gnupg2 graphviz \
      ca-certificates curl gnupg openssl wget unzip supervisor net-tools vim \
      sudo iputils-ping telnet

# powerline fonts
RUN mkdir -p /tmp/powerline && \
  cd /tmp/powerline && \
  git clone https://github.com/powerline/fonts.git && \
  cd fonts && \
  ./install.sh && \
  cd / && \
  rm -rf /tmp/powerline

# bash it
RUN git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it && \
  ~/.bash_it/install.sh && \
  sed -i 's/\(^export BASH_IT_THEME.*$\)/#\ \1/' ~/.bashrc && \
  sed -i "/^.*export BASH_IT_THEME/a\export BASH_IT_THEME='powerline'" ~/.bashrc && \
  source ~/.bashrc && \
  bash-it enable completion awscli docker docker-compose gh git packer terraform vagrant vault

# prepping
RUN mkdir -p /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY scripts/start-consul.sh scripts/start-nomad.sh ./

RUN chmod +x start-consul.sh start-nomad.sh

# This is the location of the releases.
ENV HASHICORP_RELEASES=https://releases.hashicorp.com

# trusted key
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C

RUN mkdir -p /tmp/build/consul
RUN mkdir -p /tmp/build/nomad

# consul
RUN addgroup --system consul && \
  adduser --system --group consul

ENV CONSUL_VERSION=1.1.0

RUN cd /tmp/build/consul && \
  arch="$(uname -m)" && \
  case "${arch}" in \
      aarch64) arch='arm64' ;; \
      armhf) arch='arm' ;; \
      x86) arch='386' ;; \
      x86_64) arch='amd64' ;; \
      *) echo >&2 "error: unsupported architecture: ${arch} (see ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/)" && exit 1 ;; \
  esac && \
  wget ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${arch}.zip && \
  wget ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS && \
  wget ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig && \
  gpg --batch --verify consul_${CONSUL_VERSION}_SHA256SUMS.sig consul_${CONSUL_VERSION}_SHA256SUMS && \
  grep consul_${CONSUL_VERSION}_linux_${arch}.zip consul_${CONSUL_VERSION}_SHA256SUMS | sha256sum -c && \
  unzip -d /bin consul_${CONSUL_VERSION}_linux_${arch}.zip && \
  # smoke test
  consul version

RUN mkdir -p /consul/data && \
  mkdir -p /consul/config && \
  chown -R consul:consul /consul

EXPOSE 8300 8301 8301/udp 8302 8302/udp 8500 8600 8600/udp

# nomad
RUN addgroup --system nomad && \
  adduser --system --group nomad

ENV NOMAD_VERSION 0.8.3

RUN cd /tmp/build/nomad && \
  arch="$(uname -m)" && \
  case "${arch}" in \
      aarch64) arch='arm64' ;; \
      armhf) arch='arm' ;; \
      x86) arch='386' ;; \
      x86_64) arch='amd64' ;; \
      *) echo >&2 "error: unsupported architecture: ${arch} (see ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/)" && exit 1 ;; \
  esac && \
  echo ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${arch}.zip && \
  curl -L -o nomad_${NOMAD_VERSION}_linux_amd64.zip ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${arch}.zip && \
  curl -L -o nomad_${NOMAD_VERSION}_SHA256SUMS      ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS && \
  curl -L -o nomad_${NOMAD_VERSION}_SHA256SUMS.sig  ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS.sig && \
  gpg --batch --verify nomad_${NOMAD_VERSION}_SHA256SUMS.sig nomad_${NOMAD_VERSION}_SHA256SUMS && \
  grep nomad_${NOMAD_VERSION}_linux_amd64.zip nomad_${NOMAD_VERSION}_SHA256SUMS | sha256sum -c && \
  unzip -d /bin nomad_${NOMAD_VERSION}_linux_${arch}.zip && \
  # smoke test
  nomad version

# docker

# cleanup
RUN cd /tmp/build && \
  rm -rf /tmp/build

RUN mkdir -p /nomad/data && \
  mkdir -p /etc/nomad && \
  chown -R nomad:nomad /nomad

COPY conf/nomad/local.json /etc/nomad/local.json

EXPOSE 4646 4647 4648 4648/udp

CMD ["/usr/bin/supervisord"]