# ./hooks/build dev
# ./hooks/build dfw

ARG BASETAG=latest

FROM ubuntu:${BASETAG} as stage-ubuntu

LABEL \
    maintainer="https://github.com/ml3nsch0w" \
    vendor="ml3nsch0w"

### 'apt-get clean' runs automatically
RUN apt-get update && apt-get install -y \
        inetutils-ping \
        lsb-release \
        net-tools \
        sudo \
        unzip \
        vim \
        zip \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

### next ENTRYPOINT command supports development and should be overriden or disabled
### it allows running detached containers created from intermediate images, for example:
### docker build --target stage-vnc -t dev/ubuntu-vnc-xfce:stage-vnc .
### docker run -d --name test-stage-vnc dev/ubuntu-vnc-xfce:stage-vnc
### docker exec -it test-stage-vnc bash
# ENTRYPOINT ["tail", "-f", "/dev/null"]

FROM stage-ubuntu as stage-xfce

ENV \
    DEBIAN_FRONTEND=noninteractive \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

### 'apt-get clean' runs automatically
RUN apt-get update && apt-get install -y \
        mousepad \
        locales \
        supervisor \
        xfce4 \
        xfce4-terminal \
    && locale-gen en_US.UTF-8 \
    && apt-get purge -y \
        pm-utils \
        xscreensaver* \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

FROM stage-xfce as stage-vnc

### 'apt-get clean' runs automatically
### installed into '/usr/share/usr/local/share/vnc'
RUN apt-get update && apt-get install -y \
        wget \
        && wget -qO- https://dl.bintray.com/tigervnc/stable/tigervnc-1.9.0.x86_64.tar.gz | tar xz --strip 1 -C / \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

FROM stage-vnc as stage-tini

ADD https://github.com/krallin/tini/releases/download/v0.18.0/tini /tini
RUN chmod +x /tini

FROM stage-tini as stage-final

LABEL \
    any.ml3nsch0w.description="Headless Ubuntu/VNC container with Xfce desktop" \
    any.ml3nsch0w.display-name="Headless Ubuntu/VNC container with Xfce desktop" \
    any.ml3nsch0w.expose-services="5901:xvnc" \
    any.ml3nsch0w.tags="ubuntu, xfce, vnc"

### Arguments can be provided during build
ARG ARG_HOME
ARG ARG_VNC_BLACKLIST_THRESHOLD
ARG ARG_VNC_BLACKLIST_TIMEOUT
ARG ARG_VNC_PW
ARG ARG_VNC_RESOLUTION
ARG ARG_SUPPORT_USER_GROUP_OVERRIDE

ENV \
    DISPLAY=:1 \
    HOME=${ARG_HOME:-/home/headless} \
    STARTUPDIR=/dockerstartup \
    VNC_BLACKLIST_THRESHOLD=${ARG_VNC_BLACKLIST_THRESHOLD:-20} \
    VNC_BLACKLIST_TIMEOUT=${ARG_VNC_BLACKLIST_TIMEOUT:-0} \
    VNC_COL_DEPTH=24 \
    VNC_PORT="5901" \
    VNC_PW=${ARG_VNC_PW:-headless} \
    VNC_RESOLUTION=${ARG_VNC_RESOLUTION:-1024x768} \
    VNC_VIEW_ONLY=false \
    SUPPORT_USER_GROUP_OVERRIDE=${ARG_SUPPORT_USER_GROUP_OVERRIDE}

### Creates home folder
WORKDIR ${HOME}
SHELL ["/bin/bash", "-c"]

COPY [ "./src/startup", "${STARTUPDIR}/" ]

### Preconfigure Xfce
COPY [ "./src/home/Desktop", "${HOME}/Desktop/" ]
COPY [ "./src/home/config/xfce4", "${HOME}/.config/xfce4/" ]

### Create the default application user (non-root, but member of the group zero)
### and make '/etc/passwd' and '/etc/group' writable for the group.
### Providing the build argument ARG_SUPPORT_USER_GROUP_OVERRIDE (set to anything) makes both files
### writable for all users, adding support for user group override (like 'run --user x:y').
RUN \
    chmod 664 /etc/passwd /etc/group \
    && echo "headless:x:1001:0:Default:${HOME}:/bin/bash" >> /etc/passwd \
    && adduser gesinet sudo \
    && echo "gesinet:$VNC_PW" | chpasswd \
    && chmod +x \
        "${STARTUPDIR}/set_user_permissions.sh" \
        "${STARTUPDIR}/generate_container_user.sh" \
        "${STARTUPDIR}/vnc_startup.sh" \
        "${STARTUPDIR}/version_of.sh" \
        "${STARTUPDIR}/version_sticker.sh" \
    && ${ARG_SUPPORT_USER_GROUP_OVERRIDE/*/chmod a+w /etc/passwd /etc/group} \
    && gtk-update-icon-cache -f /usr/share/icons/hicolor

### Fix permissions
RUN "${STARTUPDIR}"/set_user_permissions.sh "${STARTUPDIR}" "${HOME}"

EXPOSE ${VNC_PORT}

### Switch to default application user (non-root)
USER 1001

ARG ARG_REFRESHED_AT
ARG ARG_VERSION_STICKER

ENV \
    REFRESHED_AT=${ARG_REFRESHED_AT} \
    VERSION_STICKER=${ARG_VERSION_STICKER}

ENTRYPOINT [ "/tini", "--", "/dockerstartup/vnc_startup.sh" ]
### tini argument '-w' means 'print a warning when processes are getting reaped'
# ENTRYPOINT [ "/tini", "-w", "--", "/dockerstartup/vnc_startup.sh" ]
### verbose argument '-v' can be repeated up to three times
### level 3 (TRACE) outputs 'No child to reap' every second
### level 2 (DEBUG) outputs also SIGCHLD signals
### level 1 (INFO) doesn't output SIGCHLD signals
# ENTRYPOINT ["/tini", "-w", "-v", "--", "/dockerstartup/vnc_startup.sh"]

### command can be provided also by 'docker run'
# CMD [ "--debug" ]
CMD [ "--wait" ]

Source Repository
Github
ml3nsch0w/xubuntu-vnc
Products
Product Overview
Offerings
Docker Enterprise
Docker Hub
Technologies
Developer Tools
Desktop
Container Runtime
Kubernetes
Image Registry
Container Management
Solutions
Use Cases
Traditional Apps
Microservices
