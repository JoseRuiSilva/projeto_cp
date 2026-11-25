CC = g++
SRC = src/
CXXFLAGS = -O3 -mcpu=a64fx -msve-vector-bits=512 -fno-math-errno -fno-trapping-math -fopenmp

.DEFAULT_GOAL = md

md: $(SRC)MD.cpp
	$(CC) $(CXXFLAGS) $(SRC)MD.cpp -lm -o md

clean:
	rm -f ./md

export OMP_NUM_THREADS ?= 48
export OMP_PROC_BIND ?= close
export OMP_PLACES ?= cores

run: md
	./md < inputdata.txt