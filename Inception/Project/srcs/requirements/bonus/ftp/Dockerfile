FROM alpine:3.23

RUN apk add --no-cache vsftpd shadow \
    && (groupmod -g 33 www-data 2>/dev/null || addgroup -g 33 -S www-data 2>/dev/null || true) \
    && mkdir -p /var/run/vsftpd/empty /var/www/html /etc/pam.d

COPY conf/vsftpd.conf.template /etc/vsftpd.conf.template
COPY conf/vsftpd.pam /etc/pam.d/vsftpd
COPY tools/init.sh /usr/local/bin/ftp-init

RUN chmod 755 /usr/local/bin/ftp-init

EXPOSE 21 21100-21110

ENTRYPOINT ["/usr/local/bin/ftp-init"]
CMD ["/usr/sbin/vsftpd", "/etc/vsftpd.conf"]
