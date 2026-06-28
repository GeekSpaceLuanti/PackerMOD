.PHONY: test e2e all

test:
	busted spec/

e2e:
	bash spec/e2e/run.sh

all: test e2e
