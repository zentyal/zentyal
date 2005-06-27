TOOLS_DIR = ../tools
ENSURE_XSL = if ! test -e "$(TOOLS_DIR)/xsl"; then $(TOOLS_DIR)/find-xsl.py; fi
XSLTPROC = xsltproc
INSTALL_DIR = $(DESTDIR)/usr/share/doc/subversion
INSTALL = install

## You shouldn't normally need to edit anything below here.
SHELL = /bin/sh
BOOK_TOP = .
TOOLS_DIR = ../tools
BOOK_HTML_CHUNK_DIR = $(BOOK_DIR)/html-chunk
BOOK_DIR = ${BOOK_TOP}
BOOK_HTML_TARGET = $(BOOK_DIR)/ebox-instguide-book.html
BOOK_HTML_CHUNK_TARGET = $(BOOK_HTML_CHUNK_DIR)/index.html  # index.html is created last
BOOK_PDF_TARGET = $(BOOK_DIR)/ebox-instguide-book.pdf
BOOK_PS_TARGET = $(BOOK_DIR)/ebox-instguide-book.ps
BOOK_FO_TARGET = $(BOOK_DIR)/ebox-instguide-book.fo
BOOK_XML_SOURCE = $(BOOK_DIR)/book.xml
BOOK_ALL_SOURCE = $(BOOK_DIR)/*.xml
BOOK_IMAGES = $(BOOK_DIR)/images/*.png
BOOK_INSTALL_DIR = $(INSTALL_DIR)/book

XSL_FO = $(TOOLS_DIR)/fo-stylesheet.xsl
XSL_HTML = $(TOOLS_DIR)/html-stylesheet.xsl
XSL_HTML_CHUNK = $(TOOLS_DIR)/chunk-stylesheet.xsl

RUN_FOP = $(TOOLS_DIR)/bin/run-fop.sh

# Book xsltproc options for HTML output
# Note: --stringparam arguments no longer go here; 
# see ../tools/html-stylesheet.xsl and ../tools/chunk-stylesheet.xsl
BOOK_HTML_XSLTPROC_OPTS = 

# Book xsltproc options for PDF and PostScript output
# BOOK_PDF_XSLTPROC_OPTS = --stringparam page.height 9in --stringparam page.width 6.4in
# BOOK_PS_XSLTPROC_OPTS = --stringparam page.height 9in --stringparam page.width 6.4in

# Uncomment the following lines if you'd like to print on A4 paper
# BOOK_PDF_XSLTPROC_OPTS = --stringparam paper.type A4
# BOOK_PS_XSLTPROC_OPTS = --stringparam paper.type A4


pdf-html: pdf html

all: all-html all-pdf all-ps

install: install-book

all-html: html html-chunk

all-pdf: pdf

all-ps: ps

all-book: html html-chunk pdf ps

install-book: install-book-html install-book-html-chunk install-book-pdf install-book-ps

clean: book-clean

test: $(BOOK_XML_SOURCE)
	xmllint --valid --noout $(BOOK_XML_SOURCE)

html: $(BOOK_HTML_TARGET)

$(BOOK_HTML_TARGET): $(BOOK_ALL_SOURCE)
	$(ENSURE_XSL)
	$(XSLTPROC) $(BOOK_HTML_XSLTPROC_OPTS) \
           --output $(BOOK_HTML_TARGET) $(XSL_HTML) $(BOOK_XML_SOURCE)

html-chunk: $(BOOK_HTML_CHUNK_TARGET)

## This trailing slash is essential that xsltproc will output pages to the dir
$(BOOK_HTML_CHUNK_TARGET): $(BOOK_ALL_SOURCE)  \
                           $(BOOK_DIR)/styles.css $(BOOK_IMAGES)
	mkdir -p $(BOOK_HTML_CHUNK_DIR)
	mkdir -p $(BOOK_HTML_CHUNK_DIR)/images
	$(ENSURE_XSL)
	$(XSLTPROC) $(BOOK_HTML_XSLTPROC_OPTS) \
           --output $(BOOK_HTML_CHUNK_DIR)/ \
	   $(XSL_HTML_CHUNK) $(BOOK_XML_SOURCE)
	cp $(BOOK_DIR)/styles.css $(BOOK_HTML_CHUNK_DIR)
	cp $(BOOK_IMAGES) $(BOOK_HTML_CHUNK_DIR)/images

pdf: $(BOOK_PDF_TARGET)

ps: $(BOOK_PS_TARGET)

$(BOOK_PDF_TARGET): $(BOOK_ALL_SOURCE) $(BOOK_IMAGES)
	$(ENSURE_XSL)
	$(XSLTPROC) $(BOOK_PDF_XSLTPROC_OPTS) \
	   --output $(BOOK_FO_TARGET) $(XSL_FO) $(BOOK_XML_SOURCE)
	$(RUN_FOP) $(BOOK_TOP) -fo $(BOOK_FO_TARGET) -pdf $(BOOK_PDF_TARGET)

$(BOOK_PS_TARGET): $(BOOK_ALL_SOURCE) $(BOOK_IMAGES)
	$(ENSURE_XSL)
	$(XSLTPROC) $(BOOK_PS_XSLTPROC_OPTS) \
	   --output $(BOOK_FO_TARGET) $(XSL_FO) $(BOOK_XML_SOURCE)
	$(RUN_FOP) $(BOOK_TOP) -fo $(BOOK_FO_TARGET) -ps $(BOOK_PS_TARGET)

$(BOOK_INSTALL_DIR):
	$(INSTALL) -d $(BOOK_INSTALL_DIR)

install-book-html: $(BOOK_HTML_TARGET)
	$(INSTALL) -d $(BOOK_INSTALL_DIR)/images
	$(INSTALL) $(BOOK_HTML_TARGET) $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_DIR)/styles.css $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_IMAGES) $(BOOK_INSTALL_DIR)/images

install-book-html-chunk: $(BOOK_HTML_CHUNK_TARGET)
	$(INSTALL) -d $(BOOK_INSTALL_DIR)/images
	$(INSTALL) $(BOOK_HTML_CHUNK_DIR)/*.html $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_DIR)/styles.css $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_IMAGES) $(BOOK_INSTALL_DIR)/images

install-book-pdf: $(BOOK_PDF_TARGET) $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_PDF_TARGET) $(BOOK_INSTALL_DIR)

install-book-ps: $(BOOK_PS_TARGET) $(BOOK_INSTALL_DIR)
	$(INSTALL) $(BOOK_PS_TARGET) $(BOOK_INSTALL_DIR)

book-clean:
	rm -f $(BOOK_HTML_TARGET) $(BOOK_FO_TARGET)
	rm -rf $(BOOK_HTML_CHUNK_DIR)
	rm -f $(BOOK_PDF_TARGET) $(BOOK_PS_TARGET) 
