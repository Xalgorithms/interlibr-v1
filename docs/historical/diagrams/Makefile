all: svg/invoice-process.svg png/invoice-process.svg

svg/invoice-process.svg: invoice-process.dia
	mkdir -p svg
	dia --export=svg/invoice-process.svg --filter=svg invoice-process.dia

png/invoice-process.svg: invoice-process.dia
	mkdir -p png
	dia --export=png/invoice-process.png --filter=png --size=1024x768 invoice-process.dia
