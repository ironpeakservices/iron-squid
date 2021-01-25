FROM debian:buster AS build

# make a pipe fail on the first failure
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /squid
WORKDIR /squid
RUN echo "deb-src http://deb.debian.org/debian buster main " >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install --yes net-tools openssl devscripts build-essential fakeroot libdbi-perl libssl-dev libssl-dev dpkg-dev patchelf

RUN apt-get source squid

RUN apt-get build-dep --yes squid

RUN mv squid-*/ squid/

WORKDIR /squid/squid/

RUN sed 's/--with-gnutls/--with-gnutls --with-default-user=squid --enable-ssl --enable-ssl-crtd --with-openssl --disable-ipv6/' debian/rules

RUN debuild -us -uc

RUN mkdir -p /static/ \
  && cp ./debian/squid/usr/sbin/squid /static/ \
  && ldd "/static/squid" | tr -s ' ' | grep '=> /' | awk '{print $3}' | xargs cp --parents -t /static/

#
# ---
#

FROM gcr.io/distroless/base-debian10:nonroot

COPY --from=build --chown=nonroot /static/ /

USER nonroot
EXPOSE 3128
ENTRYPOINT ["/squid"]
