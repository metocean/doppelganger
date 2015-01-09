# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.15

# Install programs
RUN apt-get -y update\
  && apt-get -y upgrade\
  && apt-get -y --force-yes install\
  nodejs\
  npm\
  && apt-get clean\
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV HOME /root
CMD ["/sbin/my_init", "--quiet"]

# Run build script
ADD build /build
WORKDIR /build
RUN nodejs /build/install.js