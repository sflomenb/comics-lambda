PWD := $(PWD)

PACKAGES_DIR = venv/lib/python3.7/site-packages
PACKAGES := $(shell find $(PACKAGES_DIR) -type f | sed 's: :\\ :')
TEST_DEPENDENCIES = moto mock

function.zip: comics.py | venv
	zip -g $@ $<

venv: $(PACKAGES) $(PACKAGES)
	cd $(PACKAGES_DIR) \
		&& zip -r9 $(PWD)/function.zip . $(addprefix -x ,$(addsuffix \*,$(TEST_DEPENDENCIES)))
	touch $@

.PHONY: clean
clean:
	rm function.zip
