FROM ubuntu:jammy
MAINTAINER Bradley Burgess <bradleyburgess@gmail.com>
ENV DEBIAN_FRONTEND noninteractive

# Following 'How do I add or remove Dropbox from my Linux repository?' - https://www.dropbox.com/en/help/246
RUN apt-get -qqy update \
	&& apt-get -qqy install \
	ca-certificates \
	libglapi-mesa \
	libglib2.0-0 \
	libxcb-dri2-0 \
	libxcb-dri3-0 \
	libxcb-glx0 \
	libxcb-present0 \
	libxcb-sync1 \
	libxdamage1 \
	libxext6 \
	libxshmfence1 \
	libxxf86vm1 \
	wget \
	&& cd /tmp \
	&& wget -O dropbox.deb https://linux.dropbox.com/packages/ubuntu/dropbox_2020.03.04_amd64.deb \
	&& apt-get -qqy install ./dropbox.deb \
	# Perform image clean up.
	&& apt-get -qqy clean \
	&& apt-get -qqy autoclean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
	# Create service account and set permissions.
	&& groupadd dropbox \
	&& useradd -m -d /dbox -c "Dropbox Daemon Account" -s /usr/sbin/nologin -g dropbox dropbox

# Dropbox is weird: it insists on downloading its binaries itself via 'dropbox
# start -i'. So we switch to 'dropbox' user temporarily and let it do its thing.
USER dropbox
RUN mkdir -p /dbox/.dropbox /dbox/.dropbox-dist /dbox/Dropbox /dbox/base \
	&& echo y | dropbox start -i

# Switch back to root, since the run script needs root privs to chmod to the user's preferrred UID
USER root

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /dbox and /tmp. The auto-update routine
# also tries to restart the dockerd process (PID 1) which causes the container to be terminated.
RUN mkdir -p /opt/dropbox \
	# Prevent dropbox to overwrite its binary
	&& mv /dbox/.dropbox-dist/dropbox-lnx* /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/dropboxd /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/VERSION /opt/dropbox/ \
	&& rm -rf /dbox/.dropbox-dist \
	&& install -dm0 /dbox/.dropbox-dist \
	# Prevent dropbox to write update files
	&& chmod u-w /dbox \
	&& chmod o-w /tmp \
	&& chmod g-w /tmp \
	# Prepare for command line wrapper
	&& mv /usr/bin/dropbox /usr/bin/dropbox-cli \
	# Suppress deprecation warning
	&& sed -i 's/isSet/is_set/g' /bin/dropbox-cli

# Install init script and dropbox command line wrapper
COPY run /root/
COPY dropbox /usr/bin/dropbox

WORKDIR /dbox/Dropbox
EXPOSE 17500
VOLUME ["/dbox/.dropbox", "/dbox/Dropbox"]
ENTRYPOINT ["/root/run"]
HEALTHCHECK --interval=30s \
	--timeout=30s \
	--start-period=5s \
	--retries=3 \
	CMD dropbox status || exit 1
