# Debian 12.6
FROM debian:bookworm-20240812

ARG user_name=developer
ARG user_id
ARG group_id
ARG dotfiles_repository="https://github.com/uraitakahito/dotfiles.git"
ARG features_repository="https://github.com/uraitakahito/features.git"
# TODO: SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data
ARG datadog_api_key
ARG instance_id

# Avoid warnings by switching to noninteractive for the build process
ENV DEBIAN_FRONTEND=noninteractive

#
# Install packages
#
RUN apt-get update -qq && \
  apt-get install -y -qq --no-install-recommends \
    # Basic
    ca-certificates \
    git \
    iputils-ping \
    # Editor
    vim \
    # Utility
    tmux \
    # fzf needs PAGER(less or something)
    fzf \
    trash-cli && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/

RUN git config --system --add safe.directory /app

RUN apt-get update -qq && \
  # Set up apt so that it can download through https and install curl and gnupg:
  apt-get install -y -qq \
    apt-transport-https \
    curl \
    gnupg && \
  # Set up the Datadog deb repo on your system and create a Datadog archive keyring:
  sh -c "echo 'deb [signed-by=/usr/share/keyrings/datadog-archive-keyring.gpg] https://apt.datadoghq.com/ stable 7' > /etc/apt/sources.list.d/datadog.list" && \
  touch /usr/share/keyrings/datadog-archive-keyring.gpg && \
  chmod a+r /usr/share/keyrings/datadog-archive-keyring.gpg && \
  curl https://keys.datadoghq.com/DATADOG_APT_KEY_CURRENT.public | gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch && \
  curl https://keys.datadoghq.com/DATADOG_APT_KEY_C0962C7D.public | gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch && \
  curl https://keys.datadoghq.com/DATADOG_APT_KEY_F14F620E.public | gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch && \
  curl https://keys.datadoghq.com/DATADOG_APT_KEY_382E94DE.public | gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch && \
  # Update your local apt repo and install the Agent:
  apt-get update -qq && \
  apt-get install datadog-agent datadog-signing-keys && \
  # Alternatively, copy the example config into place and plug in your API key:
  sh -c "sed 's/api_key:.*/api_key: ${datadog_api_key}/' /etc/datadog-agent/datadog.yaml.example > /etc/datadog-agent/datadog.yaml" && \
  # Configure your hostname:
  # https://github.com/DataDog/datadog-agent/blob/3c0e03762c44159f864bbfeb215ad88e745111fb/pkg/config/config_template.yaml#L90-L97
  sh -c "sed -i 's/# hostname_file:.*/hostname_file: \/var\/lib\/cloud\/data\/instance-id/' /etc/datadog-agent/datadog.yaml" && \
  mkdir -p /var/lib/cloud/data && \
  echo ${instance_id} > /var/lib/cloud/data/instance-id && \
  # Configure your Datadog region:
  sh -c "sed -i 's/# site:.*/site: ap1.datadoghq.com/' /etc/datadog-agent/datadog.yaml" && \
  # Configure your security-agent:
  cp -p /etc/datadog-agent/security-agent.yaml.example /etc/datadog-agent/security-agent.yaml && \
  # Ensure permissions are correct:
  sh -c "chown dd-agent:dd-agent /etc/datadog-agent/datadog.yaml && chmod 640 /etc/datadog-agent/datadog.yaml" && \
  # echo $DD_HOSTNAME > /var/lib/cloud/data/instance-id
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

#
# Add user and install basic tools.
# https://github.com/devcontainers/features/blob/main/src/common-utils/README.md
#
RUN cd /usr/src && \
  git clone --depth 1 ${features_repository} && \
  USERNAME=${user_name} \
  USERUID=${user_id} \
  USERGID=${group_id} \
  CONFIGUREZSHASDEFAULTSHELL=true \
  UPGRADEPACKAGES=false \
    /usr/src/features/src/common-utils/install.sh
USER ${user_name}

#
# dotfiles
#
RUN cd /home/${user_name} && \
  git clone --depth 1 ${dotfiles_repository} && \
  dotfiles/install.sh

WORKDIR /app
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["tail", "-F", "/dev/null"]
