.PHONY: all

all: uc1-gcp/uc1-store/build/distributions/uc1-store.zip uc3-gcp/uc3-aggregate/build/distributions/uc3-aggregate.zip uc1-gcp/uc1-node/node_modules uc3-gcp/uc3-node/node_modules uc1-aws/uc1-store/build/distributions/uc1-store.zip uc3-aws/uc3-aggregate/build/distributions/uc3-aggregate.zip

uc1-gcp/uc1-store/build/distributions/uc1-store.zip:
	cd uc1-gcp/uc1-store && gradle build

uc3-gcp/uc3-aggregate/build/distributions/uc3-aggregate.zip:
	cd uc3-gcp/uc3-aggregate && gradle build

uc1-gcp/uc1-node/node_modules:
	cd uc1-gcp/uc1-node && npm i

uc3-gcp/uc3-node/node_modules:
	cd uc3-gcp/uc3-node && npm i

uc1-aws/uc1-store/build/distributions/uc1-store.zip:
	cd uc1-aws/uc1-store && gradle buildZip

uc3-aws/uc3-aggregate/build/distributions/uc3-aggregate.zip:
	cd uc3-aws/uc3-aggregate && gradle buildZip