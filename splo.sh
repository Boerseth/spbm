#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
cd "$(dirname "$0")"

HELP='
usage: ./splo.sh -t <title> -p <posts_directory>
                 [-m <media_directory>] [-h]

Create a single-page blog from Markdown. Files need a metadata block:
date: "[0-9]{4}-[0-9]{2}-[0-9]{2}"
title: ".*"
summary: ".*"

Dependencies:
  pandoc

Options:
  -t <title>           Title of the blog, (e.g. "John Doe")
  -p <posts_directory> Location of markdown-file directory
  -m <media_directory> Optional location of media-files
  -h                   Show this help message and exit

Examples:
  ./mayke.sh -h
  ./mayke.sh -t "Ola Nordmann" -p ./path/to/posts/
  ./mayke.sh -t "frode" -p posts/ -m media/'

ART_ID='$if(date)$$date$$else$$title$$endif$'
TEMPLATE_TOC='<h2><a href="#'"$ART_ID"'">$title$</a></h2>
$if(date)$<div class="post-date">$date$</div>$endif$
$if(summary)$<div class="post-summary">$summary$</div>$endif$'

TEMPLATE_POST='<section id="'"$ART_ID"'">
<h1>$title$</h1>
$if(date)$<div class="post-date">$date$</div>$endif$
$if(summary)$<div class="post-summary">$summary$</div>$endif$
$body$
</section>'

HOME="home"  # Will be the fragment of the default section: "www.url.com#home"
TEMPLATE_STYLE='<style>
    /*  With inspiration from "58 bytes of css to look great nearly everywhere":
        https://gist.github.com/JoeyBurzynski/617fb6201335779f8424ad9528b72c41  */
html {
    max-width: 80ch;
    padding: 3em 1em;
    margin: auto;
    line-height: 1.5;
    font-size: 1em;
}
h1,h2,h3,h4,h5,h6 {
    margin: 3em 0 0;
}
p,ul,ol {
    margin-bottom: 2em;
    color: #1d1d1d;
    font-family: sans-serif;
}
.center {
    display: block;
    margin-left: auto;
    margin-right: auto;
}

section { display: none; }
section:target { display: block; }
section#'"$HOME"' { display: block; }
section:target ~ section#'"$HOME"' { display: none; }
    /*  The order of the sections is now important: #home must be last  */
:target { scroll-margin: 50vh; }
</style>'  # (The order of the sections is now important: #home must be last)

TEMP="temp"
BUILD="build"

prepare_workspace() {
    [[ ! -d $TEMP ]] && mkdir "$TEMP"
    [[ ! -d $BUILD ]] && mkdir "$BUILD"
    echo "$TEMPLATE_TOC" > "$TEMP"/toc_entry.html
    echo "$TEMPLATE_POST" > "$TEMP"/post.html
    echo "$TEMPLATE_STYLE" > "$TEMP"/style.css
}

check_all_files() {
    for file in $(find "$1" -type f -name "*.md"); do
        if ! grep -Eq "date: \"([0-9]{4}-[0-9]{2}-[0-9]{2}|)\"" "$file"; then
            echo "Error in metadata-block of $file" >&2
            return 1
        elif ! grep -Eq "title: \".*\"" "$file"; then
            echo "Error in metadata-block of $file" >&2
            return 1
        elif ! grep -Eq "summary: \".*\"" "$file"; then
            echo "Error in metadata-block of $file" >&2
            return 1
        fi
    done
}

check_dependencies() {
    if ! command -v pandoc >/dev/null; then
        echo "Error: pandoc must be installed."
        return 1
    fi
}

parse_arguments() {
    while getopts ":t:p:m:h-:" opt "$@"; do
        case $opt in
            h)
                echo "$HELP"
                return 0
                ;;
            t)
                title="$OPTARG"
                ;;
            p)
                posts="$OPTARG"
                ;;
            m)
                media="$OPTARG"
                ;;
            *)
                echo "Error: Invalid option: $opt"
                return 1
                ;;
        esac
    done
    if [[ -z "$title" || -z "$posts" ]]; then
        echo "Error! Missing options"
        return 1
    fi
}

main() {
    cd "$(dirname "$0")"
    parse_arguments "$@" || exit 1
    check_dependencies  || exit 1
    check_all_files "$posts" || exit 1
    prepare_workspace

    # Sort file names by date for chronological TOC
    files=$(for f in $(find "$posts" -type f -name "*.md"); do
        head -n 5 $f | grep '^date: ' | sed 's|^date: "\(.*\)"$|\1 '"$f"'|'
    done | sort --reverse | sed 's/^.* //')

    # Create TOC and sections
    echo '<section id="'"$HOME"'">' > "$TEMP"/toc
    for f in $files; do pandoc --template "$TEMP"/toc_entry.html "$f"; done >> "$TEMP"/toc
    echo '</section>' >> "$TEMP"/toc
    for f in $files; do pandoc --template "$TEMP"/post.html "$f"; done >> "$TEMP"/secs

    # Create index.html
    pandoc -s --katex -f html -t html -M title="$title" -H "$TEMP"/style.css "$TEMP"/secs "$TEMP"/toc \
        | sed -e 's/^<header/<a href="#'"$HOME"'"><header/' -e 's/^<\/header>$/<\/header><\/a>/' \
        > "$BUILD"/index.html

    # Maybe import media-files
    if [[ ! -z "$media" && -d "$media" ]]; then
        cp "$media"/* "$BUILD"/
    fi
}

main "$@"
