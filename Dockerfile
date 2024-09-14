FROM arm64v8/python:slim-bookworm as box64_m1

ENV DEBIAN_FRONTEND noninteractive

# Set SHELL option explicitly
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
        git \
		ca-certificates \
        build-essential \
        cmake \
		mold \
	&& git clone https://github.com/ptitSeb/box64.git \
    && mkdir /box64/build \
	&& cd /box64/build \
	&& cmake .. -D M1=1 -D CMAKE_BUILD_TYPE=RelWithDebInfo -D WITH_MOLD=1 \
	&& mold -run make -j$(nproc) \
	&& make install DESTDIR=/tmp/install

############################################################

FROM arm64v8/python:slim-bookworm as box64_rpi5

ENV DEBIAN_FRONTEND noninteractive

# Set SHELL option explicitly
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
        git \
		ca-certificates \
        build-essential \
        cmake \
		mold \
	&& git clone https://github.com/ptitSeb/box64.git \
    && mkdir /box64/build \
	&& cd /box64/build \
	&& cmake .. -D RPI5ARM64=1 -D CMAKE_BUILD_TYPE=RelWithDebInfo -D WITH_MOLD=1 \
	&& mold -run make -j$(nproc) \
	&& make install DESTDIR=/tmp/install

############################################################

FROM arm64v8/python:slim-bookworm as box64_adlink

ENV DEBIAN_FRONTEND noninteractive

# Set SHELL option explicitly
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		git \
		ca-certificates \
		build-essential \
		cmake \
		mold \
	&& git clone https://github.com/ptitSeb/box64.git \
	&& mkdir /box64/build \
	&& cd /box64/build \
	&& cmake .. -D ADLINK=1 -D CMAKE_BUILD_TYPE=RelWithDebInfo -D WITH_MOLD=1 \
	&& mold -run make -j$(nproc) \
	&& make install DESTDIR=/tmp/install

############################################################
# Dockerfile that contains SteamCMD and Box86/64
############################################################

FROM arm64v8/debian:bookworm-slim as build_stage

ARG PUID=1000

ENV USER container
ENV HOMEDIR "/mnt/server"
ENV STEAMCMDDIR "/mnt/server/steamcmd"

ENV DEBIAN_FRONTEND noninteractive

ENV DEBUGGER "/usr/local/bin/box86"

# Set SHELL option explicitly
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=box64_m1 /tmp/install/usr/local/bin/box64 /usr/local/bin/box64-m1
COPY --from=box64_rpi5 /tmp/install/usr/local/bin/box64 /usr/local/bin/box64-rpi5
COPY --from=box64_adlink /tmp/install/usr/local/bin/box64 /usr/local/bin/box64-adlink

# hadolint ignore=DL3008
RUN set -x \
	# Install, update & upgrade packages
	&& dpkg --add-architecture armhf \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
 	&& apt-get install -y --no-install-recommends --no-install-suggests \
		libc6:i386 \
		libc6:armhf \
		libcurl4 \
		libcurl4:i386 \
		libnuma1 \
		libnuma1:i386 \
		libglib2.0-0 \
		libglib2.0-0:i386 \
		openssl \
		ca-certificates \
		nano \
		curl \
		locales \
  		wget \
		gnupg \
	&& wget --progress=dot:giga https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list \
	&& (wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg) \
	&& wget --progress=dot:giga https://ryanfortner.github.io/box86-debs/box86.list -O /etc/apt/sources.list.d/box86.list \
	&& (wget -qO- https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86-debs-archive-keyring.gpg) \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		box64 \
		box86-generic-arm \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	# Create unprivileged user
	&& useradd -l -u "${PUID}" -m "${USER}" \
        # Download SteamCMD, execute as user
        && su "${USER}" -c \
		"mkdir -p \"${STEAMCMDDIR}\" \
                && curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C \"${STEAMCMDDIR}\" \
                && ${STEAMCMDDIR}/steamcmd.sh +quit \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${STEAMCMDDIR}/steamservice.so\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk32\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk64\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamclient.so\" \"${HOMEDIR}/.steam/sdk64/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamcmd\" \"${STEAMCMDDIR}/linux64/steam\" \
                && ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
	# Symlink steamclient.so; So misconfigured dedicated servers can find it
	&& mkdir -p /usr/lib/x86_64-linux-gnu \
 	&& ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
 	&& ln -s "${STEAMCMDDIR}/linux32/steamclient.so" "/usr/lib/i386-linux-gnu/steamclient.so" \
	&& rm -rf /var/lib/apt/lists/* \
	&& mv /usr/local/bin/box64 /usr/local/bin/box64-generic \
    && useradd -m -d /home/container container

COPY box64.sh /usr/local/bin/box64
RUN chmod +x /usr/local/bin/box64

FROM build_stage AS bookworm-root
WORKDIR ${STEAMCMDDIR}

FROM bookworm-root AS bookworm
# Switch to user
USER container


ENV         HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         ["/bin/bash", "/entrypoint.sh"]