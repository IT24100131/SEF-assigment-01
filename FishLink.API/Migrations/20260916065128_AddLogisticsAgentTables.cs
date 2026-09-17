using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace FishLink.API.Migrations
{
    /// <inheritdoc />
    public partial class AddLogisticsAgentTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ColdStorages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    StorageCode = table.Column<string>(type: "text", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false),
                    Location = table.Column<string>(type: "text", nullable: false),
                    TotalCapacityKg = table.Column<decimal>(type: "numeric", nullable: false),
                    UsedCapacityKg = table.Column<decimal>(type: "numeric", nullable: false),
                    TemperatureCelsius = table.Column<decimal>(type: "numeric", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ColdStorages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DeliveryPlans",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    PlanId = table.Column<string>(type: "text", nullable: false),
                    CatchId = table.Column<int>(type: "integer", nullable: false),
                    BidId = table.Column<int>(type: "integer", nullable: true),
                    VehicleCode = table.Column<string>(type: "text", nullable: false),
                    DriverCode = table.Column<string>(type: "text", nullable: false),
                    ColdStorageCode = table.Column<string>(type: "text", nullable: false),
                    PickupLocation = table.Column<string>(type: "text", nullable: false),
                    DeliveryLocation = table.Column<string>(type: "text", nullable: false),
                    SelectedRoute = table.Column<string>(type: "text", nullable: false),
                    DistanceKm = table.Column<decimal>(type: "numeric", nullable: false),
                    EstimatedMinutes = table.Column<int>(type: "integer", nullable: false),
                    PickupTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    EstimatedETA = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeliveryDeadline = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    AgentReasoning = table.Column<string>(type: "text", nullable: false),
                    WeatherNote = table.Column<string>(type: "text", nullable: false),
                    AdminNote = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeliveryPlans", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Drivers",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    DriverCode = table.Column<string>(type: "text", nullable: false),
                    FullName = table.Column<string>(type: "text", nullable: false),
                    Phone = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    AvailableFrom = table.Column<string>(type: "text", nullable: false),
                    AvailableTo = table.Column<string>(type: "text", nullable: false),
                    CurrentLocation = table.Column<string>(type: "text", nullable: false),
                    TotalDeliveries = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Drivers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Vehicles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VehicleCode = table.Column<string>(type: "text", nullable: false),
                    DriverName = table.Column<string>(type: "text", nullable: false),
                    CapacityKg = table.Column<decimal>(type: "numeric", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    LicensePlate = table.Column<string>(type: "text", nullable: false),
                    VehicleType = table.Column<string>(type: "text", nullable: false),
                    CurrentLocation = table.Column<string>(type: "text", nullable: false),
                    HasColdChain = table.Column<bool>(type: "boolean", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Vehicles", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ColdStorages");

            migrationBuilder.DropTable(
                name: "DeliveryPlans");

            migrationBuilder.DropTable(
                name: "Drivers");

            migrationBuilder.DropTable(
                name: "Vehicles");
        }
    }
}
