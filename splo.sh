#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
cd "$(dirname "$0")"

HELP='
usage: ./splo.sh -t <title> -p <posts_directory>
                 [-m <media_directory>] [-f] [-h]

Create a single-page blog from Markdown. Files need a metadata block:
date: "[0-9]{4}-[0-9]{2}-[0-9]{2}"
title: ".*"
summary: ".*"

Dependencies:
  pandoc

Options:
  -t <title>            Title of the blog, (e.g. "John Doe")
  -p <posts_directory>  Location of markdown-file directory
  -m <media_directory>  Optional location of media-files
  -f                    Force - deletes old temporary- and output-directories
  -h                    Show this help message and exit

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
</style>'

TEMP="temp"
BUILD="build"

prepare_workspace() {
    base="$1"
    force="$2"

    temp="$base"/temp
    build="$base"/build

    for arg in "$temp" "$build"; do
        if [[ -d $arg ]]; then
            echo "Error:" >&2
            echo "> directory already exists: $arg" >&2
            if [[ -z "$force" ]]; then
                return 1
            fi
            echo "> replacing by force" >&2
            rm -rf "$arg"
        fi
    done
    for arg in "$temp" "$build"; do
        mkdir "$arg"
    done

    echo "$TEMPLATE_TOC" > "$temp"/toc_entry.html
    echo "$TEMPLATE_POST" > "$temp"/post.html
    echo "$TEMPLATE_STYLE" > "$temp"/style.css
}

check_all_files() {
    error=""
    find "$1" -type f -name "*.md" -print0 | while read -d $'\0' file; do
        missing_fields=""
        if ! grep -Eq "date: \"([0-9]{4}-[0-9]{2}-[0-9]{2}|)\"" "$file"; then
            missing_fields="$missing_fields date"
        fi
        if ! grep -Eq "title: \".*\"" "$file"; then
            missing_fields="$missing_fields title"
        fi
        if ! grep -Eq "summary: \".*\"" "$file"; then
            missing_fields="$missing_fields summary"
        fi
        if [[ -n $missing_fields ]]; then
            error="true"
            echo "Error:" >&2
            echo "> metadata-block of $file is missing fields:" >&2
            echo "> $missing_fields"
        fi
    done
    if [[ -n $error ]]; then
        return 1
    fi
}

check_dependencies() {
    if ! command -v pandoc >/dev/null; then
        echo "Error:" >&2
        echo "> pandoc must be installed." >&2
        return 1
    fi
}

parse_arguments() {
    title=""
    posts=""
    media=""
    force=""
    while getopts ":t:p:m:h-:f-:" opt "$@"; do
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
            f)
                force="true"
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
    parse_arguments "$@" || exit 1
    check_dependencies  || exit 1
    check_all_files "$posts" || exit 1
    prepare_workspace "$(dirname "$posts")" "$force" || exit 1

    temp=$(dirname "$posts")/temp
    build=$(dirname "$posts")/build

    # Sort file names by date for chronological TOC
    # TODO: fix bug where a filename contains spaces
    files=$(find "$posts" -type f -name "*.md" -print0 | while read -d $'\0' f; do
        head -n 5 "$f" | grep '^date: ' | sed 's|^date: "\(.*\)"$|\1 '"$f"'|'
    done | sort --reverse | sed 's/^.* //')

    # Create TOC and sections
    echo '<section id="'"$HOME"'">' > "$temp"/toc
    for f in $files; do pandoc --template "$temp"/toc_entry.html "$f"; done >> "$temp"/toc
    echo '</section>' >> "$temp"/toc
    for f in $files; do pandoc --template "$temp"/post.html "$f"; done > "$temp"/secs

    # Create index.html
    pandoc -s --katex -f html -t html -M title="$title" -H "$temp"/style.css "$temp"/secs "$temp"/toc \
        | sed -e 's/^<header/<a href="#'"$HOME"'"><header/' -e 's/^<\/header>$/<\/header><\/a>/' \
        > "$build"/index.html

    # Maybe import media-files
    if [[ -n "$media" && -d "$media" ]]; then
        cp "$media"/* "$build"/
    fi
}

main "$@"
