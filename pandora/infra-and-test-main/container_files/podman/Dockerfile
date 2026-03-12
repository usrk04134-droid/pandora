FROM docker.io/mgoltzsche/podman:5.7.0-minimal

# Bump image version for any changes
LABEL version="1.0.2"

RUN apk add --no-cache \
    bash="5.2.37-r0"\
    coreutils="9.7-r1" \
    curl="8.14.1-r2" \
    jq="1.8.1-r0" \
    shadow="4.17.3-r0" \
    xz="5.8.1-r0"

# Install nix separately to get a version that includes the fix
# in https://github.com/NixOS/nix/pull/11171. The fix is included
# in Nix >=2.24
# We can remove this and do the installation of Nix with the rest of
# the packages if apk can select Nix 2.24 and above.
RUN curl -L https://releases.nixos.org/nix/nix-2.32.4/install | sh -s -- --daemon && \
    printf "experimental-features = nix-command flakes\n\
download-buffer-size = 524288000\n" >> /etc/nix/nix.conf

ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
