#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
cd "$(dirname "$0")"


if [[ "${1-}" =~ ^-*h(elp)?$ || $# < 2 || ! -d "$2" ]]; then
    echo '
Usage: ./mayke.sh TITLE POSTS [ MEDIA ]

Use pandoc to generate a single-page blog with title TITLE from Markdown files.
The posts should each have a metadata block
        ---
        date: ""
        title: ""
        summary: ""
        ...
and be located in the directory specified by argument POSTS. Optionally include
media in a directory MEDIA.'
    exit
fi


for d in temp page; do [[ -d "$d" ]] && rm -rf "$d"; mkdir "$d"; done


# Create pandoc templates:
art_id='${if(date)}${date}${else}${title}${endif}'

# Article template
echo '
<section id="#'"$art_id"'">
<h1 id="'"$art_id"'">
  ${title}
</h1>

${if(date)}
<time>
  ${date}
</time>
${endif}

${body}
</section>' > temp/article.html

# TOC-entry template
echo '
<div>
  <div>
    ${if(date)}
    <div class="home">
      ${date}
    </div>
    ${endif}

    <h2 class="home">
      <a href="#'"$art_id"'">
        ${title}
      </a>
    </h2>
  </div>

  ${if(summary)}
  <div>
    <p class="home">
      ${summary}
    </p>
  </div>
  ${endif}
</div>' > temp/toc_entry.html

# Style-file
echo '
<style>
  section{display: none;}
</style>' > temp/style.css

# Script-file
echo '
<script>
const SECTION = "boerseth-section-key";
const setElementDisplay = (elementId, value) => {
    const element = document.getElementById(elementId);
    if (element) { element.style.display = value; }
};
const showSection = (section) => {
    const sectionOld = window.sessionStorage.getItem(SECTION);
    window.sessionStorage.setItem(SECTION, section);
    setElementDisplay(sectionOld, "none");
    setElementDisplay(section, "block");
};
window.onhashchange = () => showSection(window.location.hash || "#");
window.onhashchange();
</script>' > temp/script.html


files=$(find "$2" -type f -name '*.md')


# Verify metadata headers
for file in $files; do
    header="$(head -n 5 $file | sed 's/:.*$//' | paste -s - | sed 's/\s//g')"
    [[ $header == "---datetitlesummary..." ]] && continue
    echo "Error in header of $file: $header" >&2
    exit 1
done


# Create TOC
echo '<section id="#">' > temp/toc.html
for file in $files; do
    echo `pandoc --template temp/toc_entry.html $file`
done | sort --reverse >> temp/toc.html
echo '</section>' >> temp/toc.html


# Create index.html
for file in $files; do
    pandoc --template temp/article.html "$file"
done | pandoc -s --katex -f html -t html \
    --include-in-header=temp/style.css \
    --include-after-body=temp/script.html \
    --metadata title="$1" \
    -o page/index.html
sed -i -e '/^<\/header>$/r temp/toc.html' \
    -e 's/^<header/<a href="#"><header/' \
    -e 's/^<\/header>$/<\/header><\/a>/' \
    page/index.html


# Maybe import media-files
[[ $@ == 3 && -d $3 ]] && cp "$3"/* page/


# Clean up temporary files
rm -rf temp
