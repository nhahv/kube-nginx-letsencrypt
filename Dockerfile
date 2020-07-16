FROM fedora
MAINTAINER Seth Jennings <sethdjennings@gmail.com>
MAINTAINER Nha.HV <nhahv.viss@gmail.com>

RUN dnf install certbot -y && dnf clean all
#RUN mkdir /etc/letsencrypt



COPY secret-patch-template.json /
COPY deployment-patch-template.json /
COPY entrypoint.sh /

CMD ["/entrypoint.sh"]
#CMD ["sh", "-c", "tail -f /dev/null"]