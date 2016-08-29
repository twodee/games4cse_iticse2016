# ---------------------------------------------------------------------------- 
# FILE:   makefile                                                             
# AUTHOR: Chris Johnson                                                        
# DATE:   Apr 30 2007                                                          
#                                                                              
# This file generates a PDF from a LaTeX source file.
# ---------------------------------------------------------------------------- 

PDFLATEX = pdflatex
BIBTEX = bibtex
TEXFILES = $(wildcard *.tex)

MAINTEXFILE = main.tex

E=\=

# .PRECIOUS: mobile.ps 

RERUN = "(There were undefined references|Rerun to get (cross-references|the bars) right)"
RERUNBIB = "No file.*\.bbl|Citation.*undefined" 

PNGFILES = $(wildcard images/*.png)
PDFFILES = $(MAINTEXFILE:.tex=.pdf)
BIBFILES = references.bib
BBLFILES = $(MAINTEXFILE:.tex=.bbl)

COPY = if test -r $*.toc; then cp $*.toc $*.toc.bak; fi 
RM = rm -f 

all: pdf

pdf: $(PDFFILES)

$(BBLFILES): $(BIBFILES)
	@echo $@ $<
	@echo "Found BIB ($?) changed."
	@$(COPY); $(PDFLATEX) $(MAINTEXFILE)
	echo $(BIBTEX) $(MAINTEXFILE:.tex=) 

%.pdf: %.tex $(TEXFILES) $(BBLFILES)
	@echo "Found ($?) changed."
	@$(COPY); $(PDFLATEX) $<
	@egrep -c $(RERUNBIB) $*.log && ($(BIBTEX) $*; $(COPY); $(PDFLATEX) $<); true
	@egrep $(RERUN) $*.log && ($(COPY); $(PDFLATEX) $<); true
	@egrep $(RERUN) $*.log && ($(COPY); $(PDFLATEX) $<); true
	@if cmp -s $*.toc $*.toc.bak; then .; else $(PDFLATEX) $<; fi
	@$(RM) $*.toc.bak
	@egrep -i "(Reference|Citation).*undefined" $*.log ; true

%.run: $(PDFFILES)
	pdfonce $(PDFFILES) &

.PHONY: clean

FORCE:

clean:
	rm -rf $(PDFFILES) *.log *.bbl *.blg *.aux *.out
