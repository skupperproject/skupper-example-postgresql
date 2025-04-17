FROM fedora:41

RUN \
  dnf clean all && \
  dnf install postgresql -y

CMD ["/bin/bash"]
