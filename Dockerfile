## Preperation
# 1. Place your id_rsa and id_rsa.pub on the same directory with this file.
# 2. How to build
#    Example:
#    docker build --build-arg DEV_USER=gaku -t manamanmana/ubuntu-std-dev-env:2016-10-06 .
# 3. How to run
#    Example:
#    docker run -d -p 10022:22 \
#               -v /Users/gaku/work/docker/docker-ubuntu-std-dev-env/some-project:/home/gaku/some-project \
#               -v /Users/gaku/work/docker/docker-ubuntu-std-dev-env/goland:/home/gaku/goland \
#               --name ubuntu-std-dev-env-container manamanmana/ubuntu-std-dev-env:2016-10-06
FROM ubuntu:latest
MAINTAINER manamanmana manamanmana@gmail.com

# @NOTE
# Build time args: need to pass through with docker build --build-arg
# or docker-compose build: args directive.
ARG DEV_USER

# ===================================================================
# Base environments and Database Clients
# ===================================================================

RUN apt-get update -y && chmod go+w,u+s /tmp

# "libreadline-dev libssl-dev openssl zlib1g-dev libbz2-dev" need to rbenv and pyenv
RUN apt-get install build-essential \
                    wget unzip curl tree grep bison telnet \
                    libreadline-dev libssl-dev openssl zlib1g-dev libbz2-dev \
                    sqlite3 libsqlite3-dev mysql-client redis-tools postgresql-client -y

# ===================================================================
# Setup users environment
# ===================================================================

# Root password 
# @NOTE Please change anything you like
RUN echo 'root:root' | chpasswd

# DEV_USER : set through build args
# @NOTE Please change DEV_USER password to anything you like
RUN useradd -m "${DEV_USER}" && echo "${DEV_USER}:${DEV_USER}" | chpasswd && \
    chsh -s /bin/bash "${DEV_USER}"

# sudo
RUN apt-get install sudo -y && echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# .ssh
RUN mkdir /home/"${DEV_USER}"/.ssh && chown "${DEV_USER}":"${DEV_USER}" /home/"${DEV_USER}"/.ssh && \
    chmod 700 /home/"${DEV_USER}"/.ssh
# @NOTE Please place id_rsa on the same dir with Dockerfile of Host
COPY id_rsa /home/"${DEV_USER}"/.ssh/
# @NOTE Please place id_rsa.pub on the same dir with Dockerfile of Host
COPY id_rsa.pub /home/"${DEV_USER}"/.ssh/
RUN chown "${DEV_USER}":"${DEV_USER}" /home/"${DEV_USER}"/.ssh/id_rsa && \
    chmod 600 /home/"${DEV_USER}"/.ssh/id_rsa && \
    chown "${DEV_USER}":"${DEV_USER}" /home/"${DEV_USER}"/.ssh/id_rsa.pub
RUN cp /home/"${DEV_USER}"/.ssh/id_rsa.pub /home/"${DEV_USER}"/.ssh/authorized_keys && \
    chmod 600 /home/"${DEV_USER}"/.ssh/authorized_keys && \
    chown "${DEV_USER}":"${DEV_USER}" /home/"${DEV_USER}"/.ssh/authorized_keys

# tmux and vim
RUN apt-get install ctags git tmux vim -y
USER "${DEV_USER}"
ENV HOME "/home/${DEV_USER}"
WORKDIR $HOME
# Install NeoBundle
RUN mkdir -p .vim/bundle && \
    git clone https://github.com/Shougo/neobundle.vim .vim/bundle/neobundle.vim
# For Jedi Python Vim Plugin
RUN cd .vim/bundle && git clone --recursive https://github.com/davidhalter/jedi-vim.git
# Copy .vimrc
COPY .vimrc /home/"${DEV_USER}"/
USER root
RUN chown "${DEV_USER}":"${DEV_USER}" /home/"${DEV_USER}"/.vimrc

# ===================================================================
# sshd
# ===================================================================
RUN apt-get install openssh-server -y && \
    sed -i 's/.*session.*required.*pam_loginuid.so.*/session optional pam_loginuid.so/g' /etc/pam.d/sshd && \
    mkdir /var/run/sshd

# ===================================================================
# Each Language Environments
# ===================================================================

# anyenv
USER "${DEV_USER}"
ENV HOME "/home/${DEV_USER}"
WORKDIR $HOME
RUN git clone https://github.com/riywo/anyenv .anyenv && \
    echo 'export PATH="$HOME/.anyenv/bin:$PATH"' >> .bash_profile && \
    echo 'eval "$(anyenv init -)"' >> .bash_profile && \
    exec /bin/bash -l
# Ruby
# -- rbenv
RUN .anyenv/bin/anyenv install rbenv && exec /bin/bash -l
# -- ruby
# @NOTE Please install any ruby version you like
ENV RBENV_ROOT "/home/${DEV_USER}/.anyenv/envs/rbenv"
ENV PATH "/home/${DEV_USER}/.anyenv/envs/rbenv/bin:$PATH"
# Rubocop is for vim plugins
RUN .anyenv/envs/rbenv/bin/rbenv install 2.3.1 && \
    .anyenv/envs/rbenv/bin/rbenv rehash && \
    .anyenv/envs/rbenv/bin/rbenv global 2.3.1 && \
    .anyenv/envs/rbenv/shims/gem install bundler --no-ri --no-doc && \
    .anyenv/envs/rbenv/shims/gem install rubocop refe2 --no-ri --no-doc
# Python
# -- pyenv
RUN .anyenv/bin/anyenv install pyenv && exec /bin/bash -l
# -- python
# @NOTE Please install any python version you like
ENV PYENV_ROOT "/home/${DEV_USER}/.anyenv/envs/pyenv"
ENV PATH "/home/${DEV_USER}/.anyenv/envs/pyenv/bin:$PATH"
RUN .anyenv/envs/pyenv/bin/pyenv install 2.7.12 && \
    .anyenv/envs/pyenv/bin/pyenv install 3.5.2 && \
    .anyenv/envs/pyenv/bin/pyenv rehash && \
    .anyenv/envs/pyenv/bin/pyenv global 2.7.12 && \
    .anyenv/envs/pyenv/shims/pip install --upgrade pip && \
    .anyenv/envs/pyenv/shims/pip install virtualenv
# NodeJS
# -- ndenv
RUN .anyenv/bin/anyenv install ndenv && exec /bin/bash -l
# -- NodeJS
# @NOTE Please install any NodeJS version you like
ENV NDENV_ROOT "/home/${DEV_USER}/.anyenv/envs/ndenv"
ENV PATH "/home/${DEV_USER}/.anyenv/envs/ndenv/bin:$PATH"
# eslint is for vim plugins
RUN .anyenv/envs/ndenv/bin/ndenv install v4.6.0 && \
    .anyenv/envs/ndenv/bin/ndenv install v6.7.0 && \
    .anyenv/envs/ndenv/bin/ndenv rehash && \
    .anyenv/envs/ndenv/bin/ndenv global v4.6.0 && \
    .anyenv/envs/ndenv/shims/npm install -g eslint
# Golang
# -- goenv
RUN .anyenv/bin/anyenv install goenv && exec /bin/bash -l
# -- Go
# @NOTE Please install any go version you like
ENV GOENV_ROOT "/home/${DEV_USER}/.anyenv/envs/goenv"
ENV PATH "/home/${DEV_USER}/.anyenv/envs/goenv/bin:$PATH"
RUN .anyenv/envs/goenv/bin/goenv install 1.6.3 && \
    .anyenv/envs/goenv/bin/goenv install 1.7 && \
    .anyenv/envs/goenv/bin/goenv rehash && \
    .anyenv/envs/goenv/bin/goenv global 1.7
RUN echo 'export GOROOT=$(go env GOROOT)' >> .bash_profile && \
    echo 'export GOPATH=~/goland' >> .bash_profile && \
    echo 'export PATH=$PATH:$GOPATH/bin' >> .bash_profile && \
    exec /bin/bash -l

# ===================================================================
# Execute sshd
# ===================================================================
USER root
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]



