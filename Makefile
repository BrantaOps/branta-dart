install:
	dart pub get

build:
	dart run build_runner build

run:
	dart .\example\branta_example.dart

coverage:
	dart test --coverage=coverage
	dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
