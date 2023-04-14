#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
cd "$(dirname "$0")"

HELP='    Usage: ./mayke.sh TITLE POSTS [ MEDIA ]
Create a single-page blog TITLE, from Markdown files in dir. POSTS. Optionally
include other media in a directory MEDIA. Markdown files should start with a
metadata block containing fields:
    date: "2000-01-01"
    title: "Simple title"
    summary: "A sentence or two about the post"'
if [[ "${1-}" =~ ^-*h(elp)?$ || $# < 2 || ! -d "$2" ]]; then echo "$HELP"; exit; fi

ART_ID='$if(date)$$date$$else$$title$$endif$'
TEMPLATE_POST='
$if(full)$<section id="'"$ART_ID"'">$endif$
$if(full)$<h1>$title$</h1>$else$<h2><a href="#'"$ART_ID"'">$title$</a></h2>$endif$
$if(date)$<div class="post-date">$date$</div>$endif$
$if(summary)$<div class="post-summary">$summary$</div>$endif$
$if(full)$$body$$endif$
$if(full)$</section>$endif$'
# (The order of the sections becomes important: #toc must be last)
TEMPLATE_STYLE='
<style>
section { display: none; } section:target { display: block; }
section#toc { display: block; } section:target ~ section#toc { display: none; }
</style>'

for d in temp build; do [[ ! -d "$d" ]] && mkdir "$d"; rm -rf "$d"/*; done
echo "$TEMPLATE_POST" > temp/post.html
echo "$TEMPLATE_STYLE" > temp/style.css

main() {
    # Verify metadata headers
    unsorted_files=$(find "$2" -type f -name "*.md")
    for file in $unsorted_files; do
        header="$(echo $(head -n 4 $file | sed 's/".*"$/""/' | paste -s -) | sed 's/ //g')"
        [[ $header == "---date:\"\"title:\"\"summary:\"\"" ]] && continue
        echo "Error in header of $file: $header" >&2
        exit 1
    done

    # Sort file names for chronological TOC
    files=$(for f in $unsorted_files; do
        head -n 5 $f | grep '^date: ' | sed 's|^.*"\(.*\)"$|\1 '"$f"'|'
    done | sort --reverse | sed 's/^.* //')

    # Create TOC and sections
    echo '<section id="toc">' > temp/toc
    for f in $files; do pandoc --template temp/post.html "$f"; done >> temp/toc
    echo '</section>' >> temp/toc
    for f in $files; do pandoc --template temp/post.html --metadata full "$f"; done > temp/secs

    # Create index.html
    pandoc -s --katex -f html -t html -M title="$1" -H temp/style.css temp/secs temp/toc \
        | sed -e 's/^<header/<a href="#toc"><header/' -e 's/^<\/header>$/<\/header><\/a>/' \
        > build/index.html

    # Maybe import media-files
    [[ $@ == 3 && -d $3 ]] && cp "$3"/* build/
}

main "$@"
