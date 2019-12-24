PWD := $(PWD)
function.zip: function.zip
	cd venv/lib/python3.7/site-packages \
		&& zip -r9 $(PWD)/$@ .

function.zip: comics.py
	zip -g $@ $<
