SHELL = /usr/bin/bash

# Arguments:
DEFAULT ?= home
TITLE ?= spamake
SRC ?= posts
MEDIA ?= media

# Workspace directories
CHECKS = .checks
TEMPLATES = .templates
SECTIONS = .sections
BUILD = build

# Directory groupd
SOURCE_DIRECTORIES = $(SRC) $(MEDIA)
PREP_DIRECTORIES = $(CHECKS) $(TEMPLATES) $(SECTIONS)
WORK_DIRECTORIES = $(PREP_DIRECTORIES) $(BUILD)
ALL_DIRECTORIES = $(SOURCE_DIRECTORIES) $(WORK_DIRECTORIES)

# Template filenames
TEMPLATE_TOC_HTML = $(TEMPLATES)/toc.html
TEMPLATE_SECTION_HTML = $(TEMPLATES)/section.html
TEMPLATE_STYLES_CSS = $(TEMPLATES)/styles.css
TEMPLATE_FILES = $(TEMPLATE_TOC_HTML) $(TEMPLATE_SECTION_HTML) $(TEMPLATE_STYLES_CSS)

# Filenames generated from source-files
SOURCE_FILES = $(wildcard $(SRC)/*.md)
CHECK_FILES = $(SOURCE_FILES:$(SRC)/%.md=$(CHECKS)/%)
SECTION_FILES = $(SOURCE_FILES:$(SRC)/%.md=$(SECTIONS)/%.html)

# Media files, and their imported counterparts
MEDIA_FILES = $(wildcard $(MEDIA)/*)
IMPORTED_FILES = $(MEDIA_FILES:$(MEDIA)/%=$(BUILD)/%)

# These files will contain
SRC_FILENAMES_CHRONOLOGICALLY = $(TEMPLATES)/src-order
SECTION_FILENAMES_CHRONOLOGICALLY = $(TEMPLATES)/sect-order

# File containing the Table-of-Contents in HTML
TOC_FILE = $(SECTIONS)/toc.html

# Template file contents
ART_ID = $${if(date)}$${date}$${else}$${title}$${endif}

define TEMPLATE_TOC
<h1><a href="#$(ART_ID)">$${title}</a></h1>
$${if(date)}<div class="toc date">$${date}</div>$${endif}
$${if(summary)}<div class="toc summary">$${summary}</div>$${endif}
endef

define TEMPLATE_SECTION
<section id="$(ART_ID)">
<h1>$${title}</h1>
$${if(date)}<div class="section date">$${date}</div>$${endif}
$${if(summary)}<div class="section summary">$${summary}</div>$${endif}
$${body}
</section>
endef

define TEMPLATE_STYLE
<style>
/*style*/
section { display: none; }
section:target { display: block; }
section#$(DEFAULT) { display: block; }
section:target ~ section#$(DEFAULT) { display: none; }
/*  The order of the sections is now important: #home must be last  */
:target { scroll-margin: 50vh; }
</style>
endef

define MARKDOWN_EXAMPLE
---
date: "%s"
title: "%s"
summary: "%s"
...

%s
endef

default: single-page-blog

# PREPARATIONS

# Populate workspace:
$(WORK_DIRECTORIES):
	@mkdir $@

export MARKDOWN_EXAMPLE
$(SRC):
	@mkdir $@
	@printf -- "$$MARKDOWN_EXAMPLE" "" "About" "" "This is a blog." > $@/about.md
	@printf -- "$$MARKDOWN_EXAMPLE" "2020-01-01" "First post" "Brief summary" "This is the first post." > $@/first.md

export TEMPLATE_TOC
$(TEMPLATE_TOC_HTML): $(TEMPLATES)
	@echo "$$TEMPLATE_TOC" > $@

export TEMPLATE_SECTION
$(TEMPLATE_SECTION_HTML): $(TEMPLATES)
	@echo "$$TEMPLATE_SECTION" > $@

export TEMPLATE_STYLE
$(TEMPLATE_STYLES_CSS): $(TEMPLATES)
	@echo "$$TEMPLATE_STYLE" > $@

# Check input and metadata-blocks:
$(CHECKS)/%: $(SRC)/%.md $(CHECKS)
	@echo "  - Verifying $<"
	@if ! head "$<" -n 1 | grep "^---$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^date: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^title: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 4 | grep "^summary: \".*\"$$" > /dev/null; then exit 1; fi
	@if ! head "$<" -n 5 | grep "^...$$" > /dev/null; then exit 1; fi
	@head "$<" -n 4 | grep "^date" | sed 's|^.*"\(.*\)"|\1 $<|' > $@

.PHONY: preparations
preparations: $(ALL_DIRECTORIES) $(SOURCE_FILES) $(CHECK_FILES) $(TEMPLATE_FILES)
	@echo "Prepared; Verified source dirs and files"

# TRANSIENT FILES

# Sort filenames chronologically
$(SRC_FILENAMES_CHRONOLOGICALLY): preparations
	@cat $(CHECKS)/* | sort --reverse > $@
	@sed -i 's|^.*/\([^/]*\).md$$|\1|' $@

# Build Table of Contents
$(TOC_FILE): preparations $(SRC_FILENAMES_CHRONOLOGICALLY)
	@echo '<section id="$(DEFAULT)">' > $@
	@for p in $$(cat $(SRC_FILENAMES_CHRONOLOGICALLY)); do pandoc --template "$(TEMPLATE_TOC_HTML)" "$(SRC)/$${p}.md"; done >> $@
	@echo '</section>' >> $@
	@echo "- Built TOC"

# Build individual blog sections $(SECTION_FILES)
$(SECTIONS)/%.html: $(SRC)/%.md preparations
	@pandoc --template "$(TEMPLATE_SECTION_HTML)" -o $@ -i $<
	@echo "  - Built $@"

.PHONY: transients
transients: $(SRC_FILENAMES_CHRONOLOGICALLY) $(TOC_FILE) $(SECTION_FILES)

# BUILD

# Calculate section-filenames in chronological order
$(SECTION_FILENAMES_CHRONOLOGICALLY): transients
	@cp $(SRC_FILENAMES_CHRONOLOGICALLY) $@
	@sed -i 's|^\(.*\)$$|$(SECTIONS)/\1.html|' $@
	@for s in $$(cat $@); do [[ -f $$s ]]; done

# Build index.html
$(BUILD)/index.html: transients $(SECTION_FILENAMES_CHRONOLOGICALLY)
	@pandoc -s --katex -f html -t html -M title="$(TITLE)" -H "$(TEMPLATE_STYLES_CSS)" \
		--shift-heading-level-by=1 $$(cat $(SECTION_FILENAMES_CHRONOLOGICALLY)) $(TOC_FILE) \
		| sed 's|^<header|<a href="#$(DEFAULT)"><header|' \
		| sed 's|^</header>$$|</header></a>|' \
		> $@

# Import media
$(BUILD)/%: $(MEDIA)/% $(MEDIA) transients
	@if [[ -f $@ ]]; then rm $@; fi
	@cp $< $@

# Build Page
.PHONY: single-page-blog
single-page-blog: $(BUILD)/index.html $(IMPORTED_FILES)
	@echo "Done."

# DEVELOPMENT

# Serve page on localhost:3948
.PHONY: serve
serve: single-page-blog
	@cd $(BUILD) && python3 -m http.server 3948

# Clean
.PHONY: clean-temporary
clean-temporary:
	@for dir in $(PREP_DIRECTORIES); do if [[ -d $$dir ]]; then rm -rf $$dir; fi; done

.PHONY: clean-build
clean-build:
	@if [[ -d $(BUILD) ]]; then rm -rf $(BUILD); fi

.PHONY: clean
clean: clean-temporary clean-build
