
all:
	./Makefile.sh

stats:
	for log in logs/*.log; do \
	  wc -l < "$$log" > "counts/`basename "$$log" .log`.count"; \
	done;

clean:
	rm -rf logs/* downloads/*

