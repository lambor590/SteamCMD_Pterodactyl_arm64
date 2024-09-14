FROM arm64v8/debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Set SHELL option explicitly
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
	&& apt-get upgrade -y \
    && useradd -m -d /home/container container

# Switch to user
USER container
ENV HOME=/home/container
WORKDIR /home/container

COPY ./box64.sh /box64.sh
RUN chmod +x /box64.sh && /box64.sh

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/box64", "/bin/bash", "-c", "box64 ./steamcmd/steamcmd.sh +quit && box64 /entrypoint.sh"]