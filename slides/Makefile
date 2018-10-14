LATEX=pdflatex
VIEWER=mupdf
TARGET=main

all:
	$(LATEX) $(TARGET)
	$(LATEX) $(TARGET)
	$(LATEX) $(TARGET)

# alle Dateien loeschen, die von latex automatisch erzeugt werden;
clean:
	rm -f *.dvi *.ps *.rtf *.aux *.bbl *.bcf *.blg *.idx *.ilg *.ind *.log *.toc *.loa *.lof *.lol *.lot *.out *.run.xml *.nav *.snm *.vrb

tidyup:	clean
	rm -f *.pdf

view: clean
	$(VIEWER) $(TARGET).pdf

