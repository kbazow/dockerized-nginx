#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

declare branches=(
    "stable"
    "mainline"
)

# Current nginx versions
# Remember to update pkgosschecksum when changing this.
declare -A nginx=(
    [mainline]='1.23.1'
    [stable]='1.22.0'
)

# Current njs versions
declare -A njs=(
    [mainline]='0.7.6'
    [stable]='0.7.6'
)

# Current package patchlevel version
# Remember to update pkgosschecksum when changing this.
declare -A pkg=(
    [mainline]=1
    [stable]=1
)

declare -A debian=(
    [mainline]='bullseye'
    [stable]='bullseye'
)

declare -A alpine=(
    [mainline]='3.16'
    [stable]='3.16'
)

# When we bump njs version in a stable release we don't move the tag in the
# mercurial repo.  This setting allows us to specify a revision to check out
# when building alpine packages on architectures not supported by nginx.org
# Remember to update pkgosschecksum when changing this.
declare -A rev=(
    [mainline]='${NGINX_VERSION}-${PKG_RELEASE}'
    [stable]='725'
)

# Holds SHA512 checksum for the pkg-oss tarball produced by source code
# revision/tag in the previous block
# Used in alpine builds for architectures not packaged by nginx.org
declare -A pkgosschecksum=(
    [mainline]='513952f1e0432e667a8e3afef791a2daa036911f35573c849712747f10418f3f5b8712faf75fcb87f91bfaf593622b1e1c4f38ad9fef830f4cae141357206ecd'
    [stable]='a6c56bb7e98be77337affe349e1316a71ddad7a732dc3b34294a794b3e740d68385022f0de72d08c090156f194580a92dcb8b5e2aa1c9c29b5a8484a6431e9b3'
)

get_packages() {
    local distro="$1"
    shift
    local branch="$1"
    shift
    local perl=
    local r=
    local sep=

    case "$distro:$branch" in
    alpine*:*)
        r="r"
        sep="."
        ;;
    debian*:*)
        sep="+"
        ;;
    esac

    case "$distro" in
    *-perl)
        perl="nginx-module-perl"
        ;;
    esac

    echo -n ' \\\n'
    case "$distro" in
    *-slim)
        for p in nginx; do
            echo -n '        '"$p"'=${NGINX_VERSION}-'"$r"'${PKG_RELEASE} \\'
        done
        ;;
    *)
        for p in nginx nginx-module-xslt nginx-module-geoip nginx-module-image-filter $perl; do
            echo -n '        '"$p"'=${NGINX_VERSION}-'"$r"'${PKG_RELEASE} \\\n'
        done
        for p in nginx-module-njs; do
            echo -n '        '"$p"'=${NGINX_VERSION}'"$sep"'${NJS_VERSION}-'"$r"'${PKG_RELEASE} \\'
        done
        ;;
    esac
}

get_packagerepo() {
    local distro="${1%-perl}"
    distro="${distro%-slim}"
    shift
    local branch="$1"
    shift

    [ "$branch" = "mainline" ] && branch="$branch/" || branch=""

    echo "https://nginx.org/packages/${branch}${distro}/"
}

get_packagever() {
    local distro="${1%-perl}"
    shift
    local branch="$1"
    shift
    local suffix=

    [ "${distro}" = "debian" ] && suffix="~${debianver}"

    echo ${pkg[$branch]}${suffix}
}

generated_warning() {
    cat <<__EOF__
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
__EOF__
}

for branch in "${branches[@]}"; do
    for variant in \
        alpine{,-perl,-slim} \
        debian{,-perl}; do
        echo "$branch: $variant"
        dir="$branch/$variant"
        variant="$(basename "$variant")"

        [ -d "$dir" ] || continue

        template="Dockerfile-${variant%-perl}.template"
        {
            generated_warning
            cat "$template"
        } >"$dir/Dockerfile"

        debianver="${debian[$branch]}"
        alpinever="${alpine[$branch]}"
        nginxver="${nginx[$branch]}"
        njsver="${njs[${branch}]}"
        revver="${rev[${branch}]}"
        pkgosschecksumver="${pkgosschecksum[${branch}]}"

        packagerepo=$(get_packagerepo "$variant" "$branch")
        packages=$(get_packages "$variant" "$branch")
        packagever=$(get_packagever "$variant" "$branch")

        sed -i.bak \
            -e 's,%%ALPINE_VERSION%%,'"$alpinever"',' \
            -e 's,%%DEBIAN_VERSION%%,'"$debianver"',' \
            -e 's,%%NGINX_VERSION%%,'"$nginxver"',' \
            -e 's,%%NJS_VERSION%%,'"$njsver"',' \
            -e 's,%%PKG_RELEASE%%,'"$packagever"',' \
            -e 's,%%PACKAGES%%,'"$packages"',' \
            -e 's,%%PACKAGEREPO%%,'"$packagerepo"',' \
            -e 's,%%REVISION%%,'"$revver"',' \
            -e 's,%%PKGOSSCHECKSUM%%,'"$pkgosschecksumver"',' \
            "$dir/Dockerfile"

        cp -a entrypoint/*.sh "$dir/"

    done
done
