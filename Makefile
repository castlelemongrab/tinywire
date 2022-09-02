
all:
	./Makefile.sh

stats:
	for log in logs/*.log; do \
	  wc -l < "$$log" > "stats/`basename "$$log" .log`.count"; \
	done;

clean:
	rm -rf logs/* downloads/* temp/* node_modules package-lock.json

