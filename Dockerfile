FROM debian:buster AS build

# make a pipe fail on the first failure
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /squid
WORKDIR /squid
RUN echo "deb-src http://deb.debian.org/debian buster main " >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install --yes net-tools openssl devscripts build-essential fakeroot libdbi-perl libssl-dev libssl-dev dpkg-dev patchelf

RUN apt-get source squid \
  && apt-get build-dep --yes squid \
  && mv squid-*/ squid/

WORKDIR /squid/squid/

RUN sed -i 's/--with-gnutls/--with-gnutls --with-default-user=nonroot --enable-ssl --enable-ssl-crtd --with-openssl --disable-ipv6/' debian/rules \
  && debuild -us -uc \
  && mkdir -p /static/ \
  && cp ./debian/squid/usr/sbin/squid /static/ \
  && ldd "/static/squid" | tr -s ' ' | grep '=> /' | awk '{print $3}' | xargs cp --parents -t /static/

RUN cat debian/rules | grep openssl ; exit 1

#
# ---
#

FROM gcr.io/distroless/base-debian10:nonroot

COPY --from=build --chown=nonroot /static/ /
COPY --chown=nonroot docker/squid.conf /etc/squid/squid.conf

USER nonroot
EXPOSE 3128 3129
ENTRYPOINT ["/squid"]
CMD ["--foreground"]
