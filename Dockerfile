FROM fedora:30

RUN \
  dnf clean all && \
  dnf install postgresql -y

CMD ["/bin/bash"]
