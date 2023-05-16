SHELL = /usr/bin/bash

TITLE ?= spbm
DEFAULT ?= home

SOURCE_FILES = $(wildcard source/*.md)
MEDIA_FILES = $(shell find media/ -type f)

WORK_DIRECTORIES = .templates .sections build
SECTION_FILES = $(SOURCE_FILES:source/%.md=.sections/%.html)
IMPORTED_FILES = $(MEDIA_FILES:media/%=build/%)


# TEMPLATES


ART_ID = $${if(date)}$${date}$${else}$${title}$${endif}

define TEMPLATE_MARKDOWN
---
date: "%s"
title: "%s"
summary: "%s"
...
%s
endef

define TEMPLATE_TOC
<h1><a href="#$(ART_ID)">$${title}</a></h1>
$${if(date)}<div class="toc date">$${date}</div>$${endif}
$${if(summary)}<div class="toc summary">$${summary}</div>$${endif}
endef

define TEMPLATE_SECTION
<section id="$(ART_ID)">
<h1>$${title}</h1>
$${if(date)}<div class="sec date">$${date}</div>$${endif}
$${if(summary)}<div class="sec summary">$${summary}</div>$${endif}
$${body}
</section>
endef

define TEMPLATE_MAIN
endef

define TEMPLATE_STYLE_CSS
html {
	max-width: 70ch;
	padding: 3em 1em;
	margin: auto;
	line-height: 1.75;
	font-size: 1.25em;
}
endef

define NECESSARY_STYLE
:target { scroll-margin: 50vh; }
section { display: none; }
section:target { display: block; }
section#$(DEFAULT) { display: block; }
section:target ~ section#$(DEFAULT) { display: none; }
/*  The order of the sections is now important: #$(DEFAULT) must be last  */
endef


# RECIPES


.PHONY: default
default: blog
	@echo "Done"

.PHONY: init
export TITLE
init: | source media
	@sed -i "s/^TITLE ?= .*$$/TITLE ?= $$TITLE/" ./Makefile
	@echo "Done"


# PREPARATIONS


media $(WORK_DIRECTORIES):
	@mkdir $@

export TEMPLATE_MARKDOWN
source:
	@mkdir $@
	@printf -- "$$TEMPLATE_MARKDOWN" \
		"" "About" "" "This is an about-page." > $@/about.md
	@printf -- "$$TEMPLATE_MARKDOWN" \
		"2020-01-01" "Blog-post" "First one" "This is a blog-post." > $@/post.md

export TEMPLATE_STYLE_CSS
source/styles.css: | source
	@echo "$$TEMPLATE_STYLE_CSS" > $@

export TEMPLATE_TOC
.templates/toc.html: | .templates
	@echo "$$TEMPLATE_TOC" > $@

export TEMPLATE_SECTION
.templates/section.html: | .templates
	@echo "$$TEMPLATE_SECTION" > $@


# TRANSIENT FILES


# Build individual blog sections, after verifying
$(SECTION_FILES): .sections/%.html: source/%.md .templates/section.html | .sections
	@echo "- $@"
	@if ! head "$<" -n 1 | grep "^---$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^date: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^title: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^summary: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 5 | grep "^...$$" > /dev/null; then exit 1; fi
	@pandoc --mathml --template ".templates/section.html" -o $@ -i $<

# Sort filenames chronologically, after they`ve all been verified
.templates/sorted-filenames: $(SECTION_FILES) | .templates
	@grep "^date: \".*\"$$" source/* \
		| sed 's|^source/\(.*\).md:date: "\(.*\)"$$|\2 \1|' \
		| sort --reverse \
		| sed 's|^.* ||' > $@

# Build Table of Contents
.sections/toc.html: .templates/sorted-filenames .templates/toc.html | .sections
	@echo "- $@"
	@echo '<section id="$(DEFAULT)">' > $@
	@for source_file in $$(sed -e 's|^|source/|' -e 's|$$|.md|' $<); \
		do pandoc --mathml --template ".templates/toc.html" "$$source_file"; \
	done >> $@
	@echo '</section>' >> $@


# BUILD


# Create final style-file
export NECESSARY_STYLE
build/styles.css: source/styles.css | build 
	@echo "- $@"
	@cp $< $@
	@echo "$$NECESSARY_STYLE" >> $@

# Build index.html
build/index.html: build/styles.css .sections/toc.html .templates/sorted-filenames | build
	@echo "- $@"
	@pandoc -s --mathml  -f html -t html -M title="$(TITLE)" --css "/styles.css" \
		--shift-heading-level-by=1 \
		$$(sed -e 's|^|.sections/|' -e 's|$$|.html|' .templates/sorted-filenames) \
		.sections/toc.html \
		| sed 's|<h1\(.*\)>$(TITLE)</h1>|<h1\1><a href="#$(DEFAULT)">$(TITLE)</a></h1>|' \
		> $@

# Import media
build/%: media/% | build
	@mkdir -p $(@D)
	@if [[ -f $@ ]]; then rm $@; fi
	@cp $< $@

# Build Page
.PHONY: blog
blog: build/index.html $(IMPORTED_FILES)


# DEVELOPMENT


# Serve contents of build/ on localhost:3948
.PHONY: serve
serve: | build
	@cd build && python3 -m http.server 3948

# Clean
CLEAN_TARGETS = $(WORK_DIRECTORIES:%=clean-%)

$(CLEAN_TARGETS): clean-%: %
	@if [[ -d $< ]]; then echo "- Removing $<"; rm -rf $<; fi

clean: $(CLEAN_TARGETS)
