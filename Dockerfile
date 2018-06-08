FROM ubuntu:16.04

LABEL MAINTAINER="Geert Van Huychem <geert@iframeworx.be>"

SHELL ["/bin/bash", "-c"]

############################################## <BASE TOOLING
RUN set -eux && \
    apt-get update &&  \
    apt-get upgrade -y &&  \
    apt-get -y autoremove &&  \
    apt-get -y autoclean &&  \
    apt-get install -y htop build-essential git unzip gnupg2 graphviz \
      ca-certificates curl gnupg openssl wget unzip supervisor net-tools vim \
      sudo iputils-ping telnet git tar nodejs
############################################## </BASE TOOLING


############################################## <POWERLINE THEME
RUN mkdir -p /tmp/powerline && \
  cd /tmp/powerline && \
  git clone https://github.com/powerline/fonts.git && \
  cd fonts && \
  ./install.sh && \
  cd / && \
  rm -rf /tmp/powerline
############################################## </POWERLINE THEME


############################################## <BASH IT
RUN git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it && \
  ~/.bash_it/install.sh && \
  sed -i 's/\(^export BASH_IT_THEME.*$\)/#\ \1/' ~/.bashrc && \
  sed -i "/^.*export BASH_IT_THEME/a\export BASH_IT_THEME='powerline'" ~/.bashrc && \
  source ~/.bashrc && \
  bash-it enable completion awscli docker docker-compose gh git packer terraform vagrant vault
############################################## </BASH IT


############################################## <SUPERVISOR
RUN mkdir -p /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
############################################## </SUPERVISOR


############################################## <CONSUL
ENV HASHICORP_RELEASES "https://releases.hashicorp.com"

RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C

COPY scripts/start-consul.sh ./

RUN chmod +x start-consul.sh

RUN mkdir -p /tmp/build/consul

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
############################################## </CONSUL


############################################## <NOMAD
COPY scripts/start-nomad.sh ./

RUN chmod +x start-nomad.sh

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
############################################## </NOMAD


############################################## <JAVA
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
############################################## </JAVA


############################################## <ELASTICSEARCH
ENV ELASTICSEARCH_RELEASES "https://artifacts.elastic.co/downloads/elasticsearch/"

RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 46095ACC8548582C1A2699A9D27D666CD88E42B4

ENV ELASTIC_VERSION 6.2.4

COPY scripts/start-elastic.sh ./

RUN chmod +x start-elastic.sh

RUN addgroup --system elastic && \
  adduser --system --home /opt/elasticsearch --group elastic && \
  adduser elastic sudo && \
  usermod --shell /bin/bash elastic

RUN mkdir -p /var/lib/elasticsearch /tmp/build/elastic && \
  cd /tmp/build/elastic && \
  wget --progress=bar:force -O elasticsearch-${ELASTIC_VERSION}.tar.gz          ${ELASTICSEARCH_RELEASES}elasticsearch-${ELASTIC_VERSION}.tar.gz && \
  wget --progress=bar:force -O elasticsearch-${ELASTIC_VERSION}.tar.gz.asc      ${ELASTICSEARCH_RELEASES}elasticsearch-${ELASTIC_VERSION}.tar.gz.asc && \
  gpg --batch --verify elasticsearch-${ELASTIC_VERSION}.tar.gz.asc elasticsearch-${ELASTIC_VERSION}.tar.gz && \
  tar -zxf elasticsearch-${ELASTIC_VERSION}.tar.gz --strip-components=1 -C /opt/elasticsearch

COPY conf/elasticsearch/root/ /

EXPOSE 9200/tcp 9300/tcp
############################################## </ELASTICSEARCH


############################################## <KIBANA
# ENV KIBANA_RELEASES "https://artifacts.elastic.co/downloads/kibana/"

# ENV KIBANA_VERSION 6.2.4

# COPY scripts/start-kibana.sh ./

# RUN chmod +x start-kibana.sh

# RUN addgroup --system kibana && \
#   adduser --system --home /opt/kibana --group kibana && \
#   adduser kibana sudo && \
#   usermod --shell /bin/bash kibana

# RUN mkdir -p /tmp/build/kibana && \
#   cd /tmp/build/kibana && \
#   arch="$(uname -m)" && \
#   case "${arch}" in \
#       aarch64) arch='arm64' ;; \
#       armhf) arch='arm' ;; \
#       x86) arch='386' ;; \
#       x86_64) arch='x86_64' ;; \
#       *) echo >&2 "error: unsupported architecture: ${arch} (see ${KIBANA_RELEASES}/kibana/${KIBANA_VERSION}/)" && exit 1 ;; \
#   esac && \
#   wget --progress=bar:force -O kibana-${KIBANA_VERSION}.tar.gz          ${KIBANA_RELEASES}kibana-${KIBANA_VERSION}-linux-${arch}.tar.gz && \
#   wget --progress=bar:force -O kibana-${KIBANA_VERSION}.tar.gz.asc      ${KIBANA_RELEASES}kibana-${KIBANA_VERSION}-linux-${arch}.tar.gz.asc && \
#   gpg --batch --verify kibana-${KIBANA_VERSION}.tar.gz.asc kibana-${KIBANA_VERSION}.tar.gz && \
#   tar -zxf kibana-${KIBANA_VERSION}.tar.gz --strip-components=1 -C /opt/kibana

# COPY conf/kibana/root/ /

# EXPOSE 5601/tcp
############################################## </KIBANA

# CLEANUP
RUN cd /tmp/build && \
  rm -rf /tmp/build

VOLUME /var/lib/elasticsearch

CMD ["/usr/bin/supervisord"]