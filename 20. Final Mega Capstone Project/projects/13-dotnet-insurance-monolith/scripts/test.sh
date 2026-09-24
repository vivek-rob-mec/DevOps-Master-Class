#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD:/src" -w /src mcr.microsoft.com/dotnet/sdk:10.0 dotnet run --project tests/DomainTests.csproj
docker compose config --quiet
