FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY app/Claims.csproj app/
COPY tests/DomainTests.csproj tests/
RUN dotnet restore tests/DomainTests.csproj --locked-mode || dotnet restore tests/DomainTests.csproj
COPY app/ app/
COPY tests/ tests/
RUN dotnet run --project tests/DomainTests.csproj && dotnet publish app/Claims.csproj -c Release -o /out --no-restore
FROM mcr.microsoft.com/dotnet/aspnet:10.0
ENV ASPNETCORE_URLS=http://+:8080 DOTNET_EnableDiagnostics=0
WORKDIR /app
COPY --from=build --chown=10001:10001 /out ./
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["dotnet","Claims.dll"]
