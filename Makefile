coverage:
	dart test --coverage=coverage
	dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
