.PHONY: docs readme install test targets build check clean

docs:
	Rscript -e 'roxygen2::roxygenise()'

readme: README.Rmd
	Rscript -e 'rmarkdown::render("README.Rmd", output_format = "github_document", quiet = TRUE)'

install: docs
	R CMD INSTALL --preclean .

test: install
	Rscript -e 'tinytest::test_package("VariantStoryBench")'

targets: install
	Rscript -e 'targets::tar_make(callr_function = NULL)'

build: docs readme
	R CMD build .

check: docs readme
	R CMD build .
	R CMD check --no-manual $$(ls -1t VariantStoryBench_*.tar.gz | head -n 1)

clean:
	rm -rf VariantStoryBench.Rcheck VariantStoryBench_*.tar.gz README.utf8.md docs _targets
