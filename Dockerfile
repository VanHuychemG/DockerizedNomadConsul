FROM ubuntu:16.04

LABEL MAINTAINER="Geert Van Huychem <geert@iframeworx.be>"

SHELL ["/bin/bash", "-c"]

# CERTIFICATES, BASE TOOLING
RUN set -eux && \
    apt-get update &&  \
    apt-get upgrade -y &&  \
    apt-get -y autoremove &&  \
    apt-get -y autoclean &&  \
    apt-get install -y htop build-essential git unzip gnupg2 graphviz \
      ca-certificates curl gnupg openssl wget unzip supervisor net-tools vim \
      sudo iputils-ping telnet

# POWERLINE THEME
RUN mkdir -p /tmp/powerline && \
  cd /tmp/powerline && \
  git clone https://github.com/powerline/fonts.git && \
  cd fonts && \
  ./install.sh && \
  cd / && \
  rm -rf /tmp/powerline

# BASH IT
RUN git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it && \
  ~/.bash_it/install.sh && \
  sed -i 's/\(^export BASH_IT_THEME.*$\)/#\ \1/' ~/.bashrc && \
  sed -i "/^.*export BASH_IT_THEME/a\export BASH_IT_THEME='powerline'" ~/.bashrc && \
  source ~/.bashrc && \
  bash-it enable completion awscli docker docker-compose gh git packer terraform vagrant vault

# PREPPING
RUN mkdir -p /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY scripts/start-consul.sh scripts/start-nomad.sh scripts/start-elastic.sh ./

RUN chmod +x start-consul.sh start-nomad.sh start-elastic.sh

ENV HASHICORP_RELEASES=https://releases.hashicorp.com

ENV ELASTIC_RELEASES "https://artifacts.elastic.co/downloads/elasticsearch"

# hashicorp - 91A6E7F85D05C65630BEF18951852D87348FFC4C
# elastic - 46095ACC8548582C1A2699A9D27D666CD88E42B4
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C 46095ACC8548582C1A2699A9D27D666CD88E42B4

# CONSUL
RUN mkdir -p /tmp/build/consul

#RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

RUN addgroup --system consul && \
  adduser --system --group consul && \
  adduser consul sudo

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
  wget --progress=bar:force ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${arch}.zip && \
  wget --progress=bar:force ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS && \
  wget --progress=bar:force ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig && \
  gpg --batch --verify consul_${CONSUL_VERSION}_SHA256SUMS.sig consul_${CONSUL_VERSION}_SHA256SUMS && \
  grep consul_${CONSUL_VERSION}_linux_${arch}.zip consul_${CONSUL_VERSION}_SHA256SUMS | sha256sum -c && \
  unzip -d /bin consul_${CONSUL_VERSION}_linux_${arch}.zip && \
  # smoke test
  consul version

RUN mkdir -p /consul/data && \
  mkdir -p /consul/config && \
  chown -R consul:consul /consul

EXPOSE 8300 8301 8301/udp 8302 8302/udp 8500 8600 8600/udp

# NOMAD
RUN mkdir -p /tmp/build/nomad

RUN addgroup --system nomad && \
  adduser --system --group nomad && \
  adduser nomad sudo

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
  wget --progress=bar:force -O nomad_${NOMAD_VERSION}_linux_amd64.zip ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${arch}.zip && \
  wget --progress=bar:force -O nomad_${NOMAD_VERSION}_SHA256SUMS      ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS && \
  wget --progress=bar:force -O nomad_${NOMAD_VERSION}_SHA256SUMS.sig  ${HASHICORP_RELEASES}/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_SHA256SUMS.sig && \
  gpg --batch --verify nomad_${NOMAD_VERSION}_SHA256SUMS.sig nomad_${NOMAD_VERSION}_SHA256SUMS && \
  grep nomad_${NOMAD_VERSION}_linux_amd64.zip nomad_${NOMAD_VERSION}_SHA256SUMS | sha256sum -c && \
  unzip -d /bin nomad_${NOMAD_VERSION}_linux_${arch}.zip && \
  # smoke test
  nomad version

RUN mkdir -p /nomad/data && \
  mkdir -p /etc/nomad && \
  chown -R nomad:nomad /nomad

COPY conf/nomad/local.json /etc/nomad/local.json

EXPOSE 4646 4647 4648 4648/udp

# JAVA
RUN apt-get update && \
	apt-get install -y openjdk-8-jdk && \
	apt-get install -y ant && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /var/cache/oracle-jdk8-installer;

RUN apt-get update && \
	apt-get install -y ca-certificates-java && \
	apt-get clean && \
	update-ca-certificates -f && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /var/cache/oracle-jdk8-installer;

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/

RUN export JAVA_HOME

# ELASTICSEARCH
RUN mkdir -p /tmp/build/elastic

RUN addgroup --system elastic && \
  adduser --system \
    --group \
    --home /usr/share/elasticsearch \
    --shell /bin/bash elastic

RUN usermod -aG sudo elastic

ENV ELASTIC_VERSION 6.2.4

RUN cd /tmp/build/elastic && \
  echo ${ELASTIC_RELEASES}/elasticsearch-${ELASTIC_VERSION}.zip && \
  wget --progress=bar:force -O elasticsearch-${ELASTIC_VERSION}.zip          ${ELASTIC_RELEASES}/elasticsearch-${ELASTIC_VERSION}.zip && \
  wget --progress=bar:force -O elasticsearch-${ELASTIC_VERSION}.zip.asc      ${ELASTIC_RELEASES}/elasticsearch-${ELASTIC_VERSION}.zip.asc && \
  wget --progress=bar:force -O elasticsearch-${ELASTIC_VERSION}.zip.sha512   ${ELASTIC_RELEASES}/elasticsearch-${ELASTIC_VERSION}.zip.sha512 && \
  gpg --batch --verify elasticsearch-${ELASTIC_VERSION}.zip.asc elasticsearch-${ELASTIC_VERSION}.zip && \
  grep elasticsearch-${ELASTIC_VERSION}.zip elasticsearch-${ELASTIC_VERSION}.zip.sha512 | shasum -a 512 -c && \
  unzip elasticsearch-${ELASTIC_VERSION}.zip && \
  mv elasticsearch-${ELASTIC_VERSION}/* /usr/share/elasticsearch

RUN for path in \
  /usr/share/elasticsearch/data \
  /usr/share/elasticsearch/logs \
  /usr/share/elasticsearch/config \
  /usr/share/elasticsearch/config/scripts \
  /usr/share/elasticsearch/tmp \
  /usr/share/elasticsearch/plugins \
  ; do \
  mkdir -p "$path"; \
  chown -R elastic:elastic "$path"; \
  done

COPY conf/elasticsearch/elasticsearch.yml /usr/share/elasticsearch/config
COPY conf/elasticsearch/log4j2.properties /usr/share/elasticsearch/config
COPY conf/elasticsearch/logrotate /etc/logrotate.d/elasticsearch

ENV PATH /usr/share/elasticsearch/bin:$PATH

VOLUME ["/usr/share/elasticsearch/data"]

EXPOSE 9200 9300

# CLEANUP
RUN cd /tmp/build && \
  rm -rf /tmp/build

CMD ["/usr/bin/supervisord"]