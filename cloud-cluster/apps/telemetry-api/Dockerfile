FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src
COPY HeartbeatMonitor.csproj ./
RUN dotnet restore
COPY . ./
RUN dotnet publish --configuration Release --no-restore --output /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app
COPY --from=build --chown=65532:65532 /app ./

ENV ASPNETCORE_HTTP_PORTS=8080

USER 65532:65532
EXPOSE 8080

ENTRYPOINT ["dotnet", "HeartbeatMonitor.dll"]
