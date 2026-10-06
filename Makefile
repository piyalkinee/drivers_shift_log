.PHONY: run test ios test-ios
run:
	@if [ -z "$${DATA_FILE:-}" ] && [ ! -e backend/data/trips.json ]; then mkdir -p backend/data; cp backend/testdata/trips.json backend/data/trips.json; fi
	cd backend && go run ./cmd/server

test:
	cd backend && go test -race -coverprofile=coverage.out ./...
	cd backend && go vet ./...

ios:
	cd ios && xcodegen generate
	open ios/ShiftLog.xcodeproj

test-ios:
	./scripts/test-ios.sh
