# Release-note helpers, sourced by release.sh and release-asset.sh.
#
# Each script owns one block of a release's notes, delimited by <!-- ASSET --> and <!-- /ASSET --> lines, and replaces
# only that block on a rerun, so notes written by hand on the release page survive (#1105).

# notes_put BEGIN END BLOCK: copy notes from stdin to stdout with the lines from BEGIN through END replaced by BLOCK, or
# with BLOCK appended after a blank line when BEGIN is absent.
notes_put() {
    BLOCK="$3" awk -v b="$1" -v e="$2" '
        $0 == b { print ENVIRON["BLOCK"]; put = 1; skip = 1 }
        !skip { print }
        $0 == e { skip = 0 }
        END { if (!put) { if (NR) print ""; print ENVIRON["BLOCK"] } }'
}
