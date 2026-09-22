using Microsoft.EntityFrameworkCore;
using FishLink.API.Models;

namespace FishLink.API.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<User> Users { get; set; }
    public DbSet<Catch> Catches { get; set; }
    public DbSet<Bid> Bids { get; set; }
    public DbSet<Order> Orders { get; set; }
    public DbSet<AgentWorkflowState> AgentWorkflows { get; set; }
    public DbSet<QualityCheck> QualityChecks { get; set; }
    public DbSet<Delivery> Deliveries { get; set; }
    public DbSet<BuyerPreference> BuyerPreferences { get; set; }
    // Logistics
    public DbSet<Vehicle>      Vehicles      { get; set; }
    public DbSet<Driver>       Drivers       { get; set; }
    public DbSet<ColdStorage>  ColdStorages  { get; set; }
    public DbSet<DeliveryPlan> DeliveryPlans { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        // Additional configurations or seed data can go here
    }
}
