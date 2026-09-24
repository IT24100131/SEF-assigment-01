using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace FishLink.API.Migrations
{
    /// <inheritdoc />
    public partial class AddBuyerPreferences : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BuyerPreferences",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    BuyerId = table.Column<int>(type: "integer", nullable: false),
                    PreferredSpecies = table.Column<string>(type: "text", nullable: false),
                    MinQuantityKg = table.Column<decimal>(type: "numeric", nullable: false),
                    MaxQuantityKg = table.Column<decimal>(type: "numeric", nullable: false),
                    MaxPricePerKg = table.Column<decimal>(type: "numeric", nullable: false),
                    PreferredCity = table.Column<string>(type: "text", nullable: false),
                    Notes = table.Column<string>(type: "text", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BuyerPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BuyerPreferences_Users_BuyerId",
                        column: x => x.BuyerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BuyerPreferences_BuyerId",
                table: "BuyerPreferences",
                column: "BuyerId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BuyerPreferences");
        }
    }
}
