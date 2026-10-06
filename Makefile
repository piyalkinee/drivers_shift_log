.PHONY: run test ios test-ios
run:
	cd backend && go run ./cmd/server

test:
	cd backend && go test -race -coverprofile=coverage.out ./...
	cd backend && go vet ./...

ios:
	cd ios && xcodegen generate
	open ios/ShiftLog.xcodeproj

test-ios:
	./scripts/test-ios.sh
