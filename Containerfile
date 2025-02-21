#FROM registry.access.redhat.com/ubi8/ubi:8.10
#FROM registry.redhat.io/rhel9/rhel-bootc:latest
FROM quay.io/fedora/fedora-bootc:41

# Install required packages
RUN dnf install -y dracut-fips openssh-clients openssh-server && \
  dnf clean all

# Enable FIPS mode
#RUN fips-mode-setup --enable

# Regenerate initramfs for FIPS support
#RUN dracut -f --no-kernel

# Ensure FIPS mode is enabled at boot
#RUN echo 'kernelopts=root=LABEL=bootc-root ro fips=1' > /etc/kernel/cmdline

## Enable fips=1 kernel argument: https://containers.github.io/bootc/building/kernel-arguments.html
COPY 01-fips.toml /usr/lib/bootc/kargs.d/
# Enable the FIPS crypto policy
RUN update-crypto-policies --no-reload --set FIPS
# And that's it. The other tasks are already handled:
# - FIPS dracut module is built-in to the base image
# - We default to a boot=UUID= karg in bootc install-to-filesystem


CMD ["/sbin/init"]
RUN bootc container lint