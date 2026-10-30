# Sourced by fpc-setup.sh and sdl3-setup.sh: fetch a Free Pascal or SDL3 build published as a goldbox-toolchain
# release, or pack one for publishing. Release <tag> holds one <tag>-<target>.tar.zst per target and a SHA256SUMS
# listing them; each archive unpacks into FPC_PREFIX as the folder the setup script would have built.
#
#   TOOLCHAIN_RELEASES     the releases' download base, <forge>/talonius/goldbox-toolchain/releases/download. When it
#                          is set, a build not yet installed is downloaded from there before anything is compiled.
#   TOOLCHAIN_FETCH_ONLY   1 makes a build with no release an error instead of compiling it from source, as CI wants.

# release_fetch TAG FILE DIR: download FILE from release TAG, check it against the release's SHA256SUMS and unpack it
# into DIR. Returns 1, having changed nothing, when TOOLCHAIN_RELEASES is unset or either download fails; a file that
# does not match its checksum stops the script.
release_fetch() {
    local tag="$1" file="$2" dir="$3" dl tool
    [ -n "${TOOLCHAIN_RELEASES:-}" ] || return 1
    for tool in curl zstd sha256sum; do
        command -v "$tool" > /dev/null 2>&1 \
            || { echo "$tool is not on PATH: cannot fetch release $tag." >&2; return 1; }
    done
    dl="$(mktemp -d)"
    if ! curl -fsSL -o "$dl/$file" "$TOOLCHAIN_RELEASES/$tag/$file" \
            || ! curl -fsSL -o "$dl/SHA256SUMS" "$TOOLCHAIN_RELEASES/$tag/SHA256SUMS"; then
        rm -rf "$dl"
        return 1
    fi
    if ! (cd "$dl" && grep "  $file\$" SHA256SUMS | sha256sum --check --strict --quiet); then
        echo "$file does not match its SHA-256 in release $tag." >&2
        rm -rf "$dl"
        exit 1
    fi
    mkdir -p "$dir"
    tar --zstd -xf "$dl/$file" -C "$dir"
    rm -rf "$dl"
}

# release_missing WHAT TAG: with TOOLCHAIN_FETCH_ONLY=1, stop because release TAG has no build of WHAT.
release_missing() {
    [ "${TOOLCHAIN_FETCH_ONLY:-}" = 1 ] || return 0
    echo "$1 has no toolchain release ($2 at ${TOOLCHAIN_RELEASES:-an unset TOOLCHAIN_RELEASES}), and" \
        "TOOLCHAIN_FETCH_ONLY=1 forbids building it here: tag $2 in goldbox-toolchain." >&2
    exit 1
}

# release_pack DIR ITEM FILE OUT: pack DIR/ITEM as OUT/FILE and add its SHA-256 to OUT/SHA256SUMS.
release_pack() {
    local dir="$1" item="$2" file="$3" out="$4"
    mkdir -p "$out"
    rm -f "$out/$file"
    tar -C "$dir" --sort=name --owner=0 --group=0 --numeric-owner --exclude="$item/.complete" \
        -I 'zstd -19 -T0 -q' -cf "$out/$file" "$item"
    (cd "$out" && sha256sum "$file") >> "$out/SHA256SUMS"
}
