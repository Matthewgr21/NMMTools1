# 3D Print Costs Calculator

A simple, standalone 3D printing price calculator that runs entirely in your browser. No server, no Node.js, no installation required.

## Features

- **Price Calculator** - Calculate costs based on material, print time, labor, and more
- **Materials Library** - Manage your filament/resin inventory with costs and properties
- **Configurable Settings** - Set printer depreciation, electricity rates, labor costs, overhead, and profit margins
- **Quote History** - Save and track your quotes over time
- **Data Persistence** - All data stored locally in your browser (localStorage)
- **Import/Export** - Backup and restore your data as JSON files
- **Responsive Design** - Works on desktop, tablet, and mobile

## Getting Started

1. Open `index.html` in any modern web browser
2. That's it! No build process, no dependencies, no installation

## How It Works

### Price Calculation Formula

The calculator uses the following cost components:

1. **Material Cost** = (Filament Used in grams / 1000) × Cost per kg
2. **Support Material Cost** = (Support Material in grams / 1000) × Cost per kg
3. **Machine Cost** = Print Time × (Printer Cost / Expected Lifespan Hours)
4. **Electricity Cost** = (Power Consumption in watts / 1000) × Print Time × Electricity Rate
5. **Labor Cost** = Post-Processing Hours × Labor Rate
6. **Failure Risk** = Base Costs × Failure Risk Percentage
7. **Subtotal** = Sum of all above costs
8. **Overhead** = Subtotal × Overhead Percentage
9. **Profit** = (Subtotal + Overhead) × Profit Margin Percentage
10. **Total** = Subtotal + Overhead + Profit

### Configurable Settings

- **Printer Settings**: Name, cost, expected lifespan, power consumption
- **Cost Settings**: Electricity rate, labor rate, overhead percentage, profit margin
- **Currency**: Customizable currency symbol

## Data Storage

All data is stored in your browser's localStorage under these keys:
- `3dpc_materials` - Materials library
- `3dpc_settings` - Application settings
- `3dpc_history` - Quote history

## Browser Compatibility

Works with all modern browsers:
- Chrome/Edge (recommended)
- Firefox
- Safari
- Opera

## Files

```
3dprintcosts/
├── index.html    # Main application file
├── styles.css    # Styling
├── app.js        # Application logic
└── README.md     # This file
```

## License

MIT License - Feel free to use and modify as needed.
