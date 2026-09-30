FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY FishLink.API/FishLink.API.csproj FishLink.API/
RUN dotnet restore FishLink.API/FishLink.API.csproj

# Copy everything else and publish Release build
COPY FishLink.API/ FishLink.API/
RUN dotnet publish FishLink.API/FishLink.API.csproj -c Release -o /app/publish --no-restore

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "FishLink.API.dll"]
