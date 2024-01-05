FROM rockylinux:9

# docker build -t vanessa/iperf3:usernetes .
RUN dnf update -y && dnf install -y iperf3 wget procps-ng && \
    wget --no-cache -O run_iperf.sh https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/iperf3/run_iperf3.sh && \
    chmod +x run_iperf.sh
