using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FishLink.API.Migrations
{
    /// <inheritdoc />
    public partial class AddQualityValidationFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CatchDateTime",
                table: "Catches",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeclaredQualityGrade",
                table: "Catches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "FraudRisk",
                table: "Catches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "InspectionResult",
                table: "Catches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "RequiresAdminReview",
                table: "Catches",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "SellerNote",
                table: "Catches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ValidationSummary",
                table: "Catches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "VerifiedWeightKg",
                table: "Catches",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "WeightDiscrepancyPct",
                table: "Catches",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CatchDateTime",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "DeclaredQualityGrade",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "FraudRisk",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "InspectionResult",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "RequiresAdminReview",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "SellerNote",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "ValidationSummary",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "VerifiedWeightKg",
                table: "Catches");

            migrationBuilder.DropColumn(
                name: "WeightDiscrepancyPct",
                table: "Catches");
        }
    }
}
