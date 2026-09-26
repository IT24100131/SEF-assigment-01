namespace FishLink.API.DTOs;

/// <summary>Payload for creating / updating a catch.</summary>
public class CatchRequest
{
    public string   FishSpecies          { get; set; } = string.Empty;
    public decimal  QuantityKg           { get; set; }
    public decimal  AskingPricePerKg     { get; set; }
    public string   Location             { get; set; } = string.Empty;
    public string   PhotoUrl             { get; set; } = string.Empty;
    public string   SellerNote           { get; set; } = string.Empty;
    public decimal  VerifiedWeightKg     { get; set; } = 0;
    public string   DeclaredQualityGrade { get; set; } = string.Empty;
    public string   InspectionResult     { get; set; } = "Pending";
    public DateTime? CatchDateTime       { get; set; }
}

/// <summary>Posted by the AI agent after running validation.</summary>
public class ValidationResultRequest
{
    public int     CatchId              { get; set; }
    public string  FraudRisk            { get; set; } = "Low";
    public decimal WeightDiscrepancyPct { get; set; } = 0;
    public int     QualityScore         { get; set; } = 0;
    public string  ValidationSummary    { get; set; } = string.Empty;
    public bool    RequiresAdminReview  { get; set; } = false;
    public string  RecommendedStatus    { get; set; } = "Published";
}
