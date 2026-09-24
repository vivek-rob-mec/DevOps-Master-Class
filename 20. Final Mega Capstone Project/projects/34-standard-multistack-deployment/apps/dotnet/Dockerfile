FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY App.csproj .
RUN dotnet restore App.csproj
COPY Program.cs .
RUN dotnet publish App.csproj -c Release --no-restore -o /out /p:UseAppHost=false
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out/ .
ENV ASPNETCORE_HTTP_PORTS=8080 APP_VERSION=dev DOTNET_EnableDiagnostics=0
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["dotnet", "App.dll"]
