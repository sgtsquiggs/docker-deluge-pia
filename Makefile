IMAGE=sgtsquiggs/deluge-pia
BUILDER=qemubuilder

.PHONY: build
build:
	sh build.sh "$(IMAGE)" "$(BUILDER)"

.PHONY: push
push:
	sh push.sh "$(IMAGE)" "$(BUILDER)"

.PHONY: readme
readme:
	bash readme.sh
