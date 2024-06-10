all: asmsnake

asmsnake:
	gcc -x assembler -c src/main.s && ld -o asmsnake main.o

clean:
	rm asmsnake main.o
