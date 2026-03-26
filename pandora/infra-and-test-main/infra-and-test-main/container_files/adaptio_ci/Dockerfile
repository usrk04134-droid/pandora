FROM nixos/nix:2.33.2

# Bump image version for any changes
LABEL version="1.0.7"
LABEL authors="team-godzilla"

# Need to update config file according to experimentation and dev setup
RUN printf "build-users-group = nixbld\n\
trusted-users = root\n\
sandbox = relaxed\n\
filter-syscalls = false\n\
experimental-features = nix-command flakes\n\
download-buffer-size = 524288000\n" > /etc/nix/nix.conf


RUN nix-env -iA nixpkgs.bash \
    nixpkgs.bzip2 \
    nixpkgs.cmake \
    nixpkgs.coreutils \
    nixpkgs.curl \
    nixpkgs.gcc \
    nixpkgs.gitMinimal \
    nixpkgs.glibc \
    nixpkgs.gnused \
    nixpkgs.gnutar \
    nixpkgs.jq \
    nixpkgs.nix-bundle \
    nixpkgs.util-linux \
    nixpkgs.xz \
    --argstr configureFlags "--disable-readelf"

RUN mkdir -p /var/lib/adaptio /var/log/adaptio
