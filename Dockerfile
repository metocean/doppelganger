# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM metocean/baseimage-nodejs:latest
MAINTAINER Thomas Coats <thomas@metocean.co.nz>

ENV HOME /root
CMD ["/sbin/my_init", "--quiet"]

# Run build script
ADD docker /build
WORKDIR /build
RUN nodejs /build/install.js