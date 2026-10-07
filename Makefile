# ---------------------------------------------------------------------------
# ISTEX PDF sample -> PNG pages -> OCR (Tesseract 3 and 5) -> merged text
# + gold reference (pdftotext) and interactive fzf diffs.
#
# Usage:
#   make download          # fetch + unzip the sample (only if pdfs/ is empty)
#   make -j4 ocr           # PDFs -> images -> OCR with both engines
#   make -j4 ocr3          # only Tesseract 3
#   make -j4 ocr5          # only Tesseract 5
#   make -j4 merge         # one text file per document, per engine
#   make gold              # reference text from pdftotext
#   make diff              # fzf: Tesseract 3 vs Tesseract 5
#   make diff3             # fzf: gold vs Tesseract 3
#   make diff5             # fzf: gold vs Tesseract 5
#   make clean             # remove generated images/OCR/text (keeps PDFs)
#   make distclean         # also remove downloaded PDFs
#
# ---------------------------------------------------------------------------

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

# --- Configuration (override on the command line: make DPI=300) -------------
PDF_DIR   ?= pdfs
BUILD     ?= build
DPI       ?= 600 
LANG_OCR  ?= eng
TESS3     ?= tesseract3
TESS5     ?= tesseract
# Training data (exported by the nix dev shell; override if needed):
#   TESSDATA3 = parent of tessdata/, with trailing slash  (Tesseract 3 TESSDATA_PREFIX)
#   TESSDATA5 = directory containing eng.traineddata      (Tesseract 5 --tessdata-dir)
TESSDATA3 ?=
TESSDATA5 ?=
GOLD_OPTS ?= -nopgbrk
# Options for git diff (add --word-diff-regex='[[:alnum:]]+' to ignore punctuation)
DIFF_OPTS ?= --color=always --no-index --word-diff -w -B

# Parallelism is handled by `make -jN`; stop Tesseract from also spawning
# its own OpenMP threads, which causes oversubscription.
export OMP_THREAD_LIMIT := 1

ISTEX_URL := https://api.istex.fr/document?q=(*)+AND+(language.raw:"eng")+AND+publicationDate:[2020+TO+2026]+AND+(genre.raw:"research-article"+genre.raw:"article")+AND+qualityIndicators.pdfWordCount:[1500+TO+275240]&size=100&rankBy=random&randomSeed=1791360826098&archiveType=zip&compressionLevel=6&sid=istex-search&extract=fulltext[pdf]
ZIP       := $(BUILD)/pdf-sample.zip

# --- Discover inputs --------------------------------------------------------
PDFS  := $(shell find $(PDF_DIR) -type f -name '*.pdf' 2>/dev/null | sort)
STEMS := $(PDFS:%.pdf=%)

IMG_DONE  := $(STEMS:%=$(BUILD)/images/%.done)
OCR3_DONE := $(STEMS:%=$(BUILD)/ocr3/%.done)
OCR5_DONE := $(STEMS:%=$(BUILD)/ocr5/%.done)
TXT3      := $(STEMS:%=$(BUILD)/text3/%.txt)
TXT5      := $(STEMS:%=$(BUILD)/text5/%.txt)
GOLD      := $(STEMS:%=$(BUILD)/gold/%.txt)

# --- Phony targets ----------------------------------------------------------
.PHONY: help download images ocr ocr3 ocr5 merge merge3 merge5 gold \
        diff diff3 diff5 clean distclean

help:
	@echo "Targets: download | images | ocr3 | ocr5 | ocr | merge3 | merge5 | merge | gold"
	@echo "         diff (3 vs 5) | diff3 (gold vs 3) | diff5 (gold vs 5) | clean | distclean"
	@echo "Tip: use 'make -j4 ocr' to process PDFs in parallel."
	@echo "Found $(words $(PDFS)) PDF(s) in $(PDF_DIR)/"

download: | $(BUILD)
	if [ -n "$$(find $(PDF_DIR) -name '*.pdf' -print -quit 2>/dev/null)" ]; then
	  echo "PDFs already present in $(PDF_DIR)/, skipping download (run 'make distclean' to redo)."
	else
	  curl --fail --location --show-error --retry 3 -g $(ISTEX_URL) \
	  -H "Authorization: Bearer $ISTEX_TOKEN" \
	  -o $(ZIP)
	  mkdir -p $(PDF_DIR)
	  unzip -q -o $(ZIP) -d $(PDF_DIR)
	  echo "Extracted to $(PDF_DIR)/ (re-run make to pick up the new PDFs)"
	fi

images: $(IMG_DONE)
ocr3:   $(OCR3_DONE)
ocr5:   $(OCR5_DONE)
ocr:    ocr3 ocr5
merge3: $(TXT3)
merge5: $(TXT5)
merge:  merge3 merge5
gold:   $(GOLD)

# PDF -> build/images/<path>/page-N.png
$(BUILD)/images/%.done: %.pdf
	@echo "[images] $<"
	mkdir -p $(BUILD)/images/$*
	pdftoppm -r $(DPI) -png "$<" "$(BUILD)/images/$*/page"
	touch $@

# PNGs -> build/ocr3/<path>/page-N.txt
$(BUILD)/ocr3/%.done: $(BUILD)/images/%.done
	@echo "[ocr3]   $*"
	mkdir -p $(BUILD)/ocr3/$*
	for img in $(BUILD)/images/$*/page-*.png; do
	  TESSDATA_PREFIX="$(TESSDATA3)" $(TESS3) "$$img" "$(BUILD)/ocr3/$*/$$(basename "$$img" .png)" -l $(LANG_OCR) >/dev/null 2>&1
	done
	touch $@

# PNGs -> build/ocr5/<path>/page-N.txt
$(BUILD)/ocr5/%.done: $(BUILD)/images/%.done
	@echo "[ocr5]   $*"
	mkdir -p $(BUILD)/ocr5/$*
	for img in $(BUILD)/images/$*/page-*.png; do
	  $(TESS5) "$$img" "$(BUILD)/ocr5/$*/$$(basename "$$img" .png)" -l $(LANG_OCR) --tessdata-dir "$(TESSDATA5)" >/dev/null 2>&1
	done
	touch $@

# page-N.txt -> build/text3/<path>.txt (one file per document)
$(BUILD)/text3/%.txt: $(BUILD)/ocr3/%.done
	@echo "[merge3] $*"
	mkdir -p $(dir $@)
	cat $(BUILD)/ocr3/$*/page-*.txt > $@

$(BUILD)/text5/%.txt: $(BUILD)/ocr5/%.done
	@echo "[merge5] $*"
	mkdir -p $(dir $@)
	cat $(BUILD)/ocr5/$*/page-*.txt > $@

# PDF -> build/gold/<path>.txt (reference text layer)
$(BUILD)/gold/%.txt: %.pdf
	@echo "[gold]   $*"
	mkdir -p $(dir $@)
	pdftotext $(GOLD_OPTS) "$<" "$@"

$(BUILD):
	@mkdir -p $@

# --- Interactive diffs ------------------------------------------------------
# LEFT is the list shown in fzf, RIGHT is the file it is compared with.
diff:  LEFT=text3
diff:  RIGHT=text5
diff3: LEFT=gold
diff3: RIGHT=text3
diff5: LEFT=gold
diff5: RIGHT=text5

diff diff3 diff5:
	cmd='git diff $(DIFF_OPTS) {} "$$(echo {} | sed "s|^$(BUILD)/$(LEFT)/|$(BUILD)/$(RIGHT)/|")"'
	find $(BUILD)/$(LEFT) -type f -name '*.txt' | sort | fzf \
	  --prompt='$(LEFT) vs $(RIGHT)> ' \
	  --preview "$$cmd | tail -n +5" \
	  --preview-window=right:70% \
	  --bind "enter:execute($$cmd | less -R)" || true

.SECONDARY:

clean:
	rm -rf $(BUILD)/images $(BUILD)/ocr3 $(BUILD)/ocr5 \
	       $(BUILD)/text3 $(BUILD)/text5 $(BUILD)/gold

distclean: clean
	rm -rf $(BUILD) $(PDF_DIR)
