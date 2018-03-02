FROM alpine

LABEL maintainer "Pavel Serikov <pavelsr@cpan.org>"

COPY cpanfile /
ENV EV_EXTRA_DEFS -DEV_NO_ATFORK

RUN apk update && \
  apk add perl perl-io-socket-ssl perl-dbd-pg perl-dev g++ make wget curl docker && \
  curl -L https://cpanmin.us | perl - App::cpanminus && \
  cpanm --installdeps . -M https://cpan.metacpan.org && \
  apk del perl-dev g++ make wget curl && \
  rm -rf /root/.cpanm/* /usr/local/share/man/*

WORKDIR /app
COPY lib ./lib
COPY manage.pl .

# RUN touch config.yaml nginx.conf
# RUN echo '* * * * * perl /app/manage.pl -s 2>&1' > /etc/crontabs/root

CMD ["perl", "manage.pl", "-f"]
