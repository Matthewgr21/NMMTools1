/**
 * Print Cost Pro - 3D Print Cost Calculator
 * Version 1.0
 */

// ============================================================================
// PRINTER PRESETS DATABASE
// ============================================================================
const PRINTER_PRESETS = [
    // Bambu Lab
    { name: "Bambu Lab X1 Carbon", type: "FDM", wattage: 350, peakWattage: 1000, cost: 1449, lifespan: 8000 },
    { name: "Bambu Lab X1E", type: "FDM", wattage: 350, peakWattage: 1000, cost: 1999, lifespan: 10000 },
    { name: "Bambu Lab P1S", type: "FDM", wattage: 350, peakWattage: 1000, cost: 699, lifespan: 6000 },
    { name: "Bambu Lab P1P", type: "FDM", wattage: 350, peakWattage: 1000, cost: 599, lifespan: 6000 },
    { name: "Bambu Lab A1", type: "FDM", wattage: 150, peakWattage: 400, cost: 399, lifespan: 5000 },
    { name: "Bambu Lab A1 Mini", type: "FDM", wattage: 120, peakWattage: 350, cost: 299, lifespan: 5000 },

    // Creality FDM
    { name: "Creality Ender 3 V3", type: "FDM", wattage: 270, peakWattage: 350, cost: 199, lifespan: 4000 },
    { name: "Creality Ender 3 S1 Pro", type: "FDM", wattage: 270, peakWattage: 350, cost: 399, lifespan: 4000 },
    { name: "Creality Ender 3 V2", type: "FDM", wattage: 270, peakWattage: 350, cost: 279, lifespan: 4000 },
    { name: "Creality Ender 5 S1", type: "FDM", wattage: 350, peakWattage: 450, cost: 399, lifespan: 5000 },
    { name: "Creality K1", type: "FDM", wattage: 350, peakWattage: 500, cost: 519, lifespan: 5000 },
    { name: "Creality K1 Max", type: "FDM", wattage: 500, peakWattage: 700, cost: 799, lifespan: 6000 },
    { name: "Creality CR-10 Smart Pro", type: "FDM", wattage: 350, peakWattage: 450, cost: 569, lifespan: 5000 },

    // Prusa FDM
    { name: "Prusa MK4", type: "FDM", wattage: 150, peakWattage: 300, cost: 799, lifespan: 8000 },
    { name: "Prusa MK3S+", type: "FDM", wattage: 120, peakWattage: 250, cost: 749, lifespan: 8000 },
    { name: "Prusa Mini+", type: "FDM", wattage: 80, peakWattage: 160, cost: 429, lifespan: 6000 },
    { name: "Prusa XL (Single)", type: "FDM", wattage: 300, peakWattage: 500, cost: 1999, lifespan: 10000 },

    // Anycubic FDM
    { name: "Anycubic Kobra 2 Pro", type: "FDM", wattage: 400, peakWattage: 500, cost: 289, lifespan: 4000 },
    { name: "Anycubic Kobra 2 Max", type: "FDM", wattage: 450, peakWattage: 600, cost: 499, lifespan: 5000 },
    { name: "Anycubic Vyper", type: "FDM", wattage: 350, peakWattage: 450, cost: 259, lifespan: 4000 },

    // Elegoo FDM
    { name: "Elegoo Neptune 4 Pro", type: "FDM", wattage: 310, peakWattage: 400, cost: 259, lifespan: 4000 },
    { name: "Elegoo Neptune 4 Plus", type: "FDM", wattage: 400, peakWattage: 500, cost: 359, lifespan: 5000 },
    { name: "Elegoo Neptune 4 Max", type: "FDM", wattage: 500, peakWattage: 650, cost: 469, lifespan: 5000 },

    // Resin Printers - Elegoo
    { name: "Elegoo Mars 4 Ultra", type: "Resin", wattage: 54, peakWattage: 60, cost: 249, lifespan: 3000 },
    { name: "Elegoo Mars 4 Max", type: "Resin", wattage: 72, peakWattage: 80, cost: 349, lifespan: 3000 },
    { name: "Elegoo Mars 4 DLP", type: "Resin", wattage: 55, peakWattage: 65, cost: 299, lifespan: 3000 },
    { name: "Elegoo Saturn 3 Ultra", type: "Resin", wattage: 75, peakWattage: 90, cost: 399, lifespan: 4000 },
    { name: "Elegoo Saturn 3", type: "Resin", wattage: 72, peakWattage: 85, cost: 349, lifespan: 4000 },
    { name: "Elegoo Saturn 4 Ultra", type: "Resin", wattage: 80, peakWattage: 95, cost: 499, lifespan: 4000 },

    // Resin Printers - Anycubic
    { name: "Anycubic Photon Mono M5s Pro", type: "Resin", wattage: 80, peakWattage: 95, cost: 399, lifespan: 4000 },
    { name: "Anycubic Photon Mono M5s", type: "Resin", wattage: 75, peakWattage: 90, cost: 319, lifespan: 4000 },
    { name: "Anycubic Photon Mono M7 Pro", type: "Resin", wattage: 85, peakWattage: 100, cost: 449, lifespan: 4000 },
    { name: "Anycubic Photon Mono 2", type: "Resin", wattage: 45, peakWattage: 55, cost: 189, lifespan: 3000 },

    // Resin Printers - Creality
    { name: "Creality Halot Mage Pro", type: "Resin", wattage: 90, peakWattage: 110, cost: 349, lifespan: 4000 },
    { name: "Creality Halot One Plus", type: "Resin", wattage: 60, peakWattage: 75, cost: 249, lifespan: 3000 },

    // Resin Printers - Prusa
    { name: "Prusa SL1S Speed", type: "Resin", wattage: 100, peakWattage: 125, cost: 1599, lifespan: 5000 },

    // Resin Printers - Phrozen
    { name: "Phrozen Sonic Mini 8K S", type: "Resin", wattage: 50, peakWattage: 60, cost: 349, lifespan: 3000 },
    { name: "Phrozen Sonic Mega 8K", type: "Resin", wattage: 150, peakWattage: 180, cost: 999, lifespan: 4000 },
    { name: "Phrozen Sonic Mighty 8K", type: "Resin", wattage: 85, peakWattage: 100, cost: 599, lifespan: 4000 },
];

// ============================================================================
// DEFAULT MATERIALS
// ============================================================================
const DEFAULT_MATERIALS = [
    { id: 'mat_1', name: 'PLA Standard', type: 'PLA', color: 'Various', costPerKg: 20, density: 1.24 },
    { id: 'mat_2', name: 'PLA+', type: 'PLA+', color: 'Various', costPerKg: 25, density: 1.24 },
    { id: 'mat_3', name: 'PETG', type: 'PETG', color: 'Various', costPerKg: 22, density: 1.27 },
    { id: 'mat_4', name: 'ABS', type: 'ABS', color: 'Various', costPerKg: 20, density: 1.04 },
    { id: 'mat_5', name: 'TPU 95A', type: 'TPU', color: 'Various', costPerKg: 35, density: 1.21 },
    { id: 'mat_6', name: 'Standard Resin', type: 'Resin Standard', color: 'Grey', costPerKg: 35, density: 1.10 },
    { id: 'mat_7', name: 'ABS-Like Resin', type: 'Resin ABS-Like', color: 'Grey', costPerKg: 40, density: 1.12 },
];

// ============================================================================
// APPLICATION STATE
// ============================================================================
let state = {
    printers: [],
    materials: [],
    products: [],
    quotes: [],
    sales: [],
    consumableTemplates: [],
    settings: {
        electricityRate: 0.12,
        designLaborRate: 15,
        postLaborRate: 12,
        failureRate: 5,
        wearCostPerHour: 0.10,
        overheadPercent: 15,
        defaultMarginType: 'percentage',
        defaultMarginValue: 30,
        currencySymbol: '$',
        materialTrackingMode: 'simple'
    },
    currentCalc: {
        parts: [],
        consumables: []
    }
};

// ============================================================================
// STORAGE KEYS
// ============================================================================
const STORAGE_KEYS = {
    PRINTERS: 'pcp_printers',
    MATERIALS: 'pcp_materials',
    PRODUCTS: 'pcp_products',
    QUOTES: 'pcp_quotes',
    SALES: 'pcp_sales',
    CONSUMABLES: 'pcp_consumables',
    SETTINGS: 'pcp_settings'
};

// ============================================================================
// INITIALIZATION
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
    loadData();
    initNavigation();
    initCalculator();
    initPrinters();
    initMaterials();
    initProducts();
    initSettings();
    initModals();
    initExportImport();
    updateDashboard();
});

// ============================================================================
// DATA PERSISTENCE
// ============================================================================
function loadData() {
    // Load printers
    const savedPrinters = localStorage.getItem(STORAGE_KEYS.PRINTERS);
    state.printers = savedPrinters ? JSON.parse(savedPrinters) : [];

    // Load materials (with defaults if empty)
    const savedMaterials = localStorage.getItem(STORAGE_KEYS.MATERIALS);
    state.materials = savedMaterials ? JSON.parse(savedMaterials) : [...DEFAULT_MATERIALS];

    // Load products
    const savedProducts = localStorage.getItem(STORAGE_KEYS.PRODUCTS);
    state.products = savedProducts ? JSON.parse(savedProducts) : [];

    // Load quotes
    const savedQuotes = localStorage.getItem(STORAGE_KEYS.QUOTES);
    state.quotes = savedQuotes ? JSON.parse(savedQuotes) : [];

    // Load sales
    const savedSales = localStorage.getItem(STORAGE_KEYS.SALES);
    state.sales = savedSales ? JSON.parse(savedSales) : [];

    // Load consumable templates
    const savedConsumables = localStorage.getItem(STORAGE_KEYS.CONSUMABLES);
    state.consumableTemplates = savedConsumables ? JSON.parse(savedConsumables) : [];

    // Load settings
    const savedSettings = localStorage.getItem(STORAGE_KEYS.SETTINGS);
    if (savedSettings) {
        state.settings = { ...state.settings, ...JSON.parse(savedSettings) };
    }
}

function saveData(key, data) {
    localStorage.setItem(key, JSON.stringify(data));
}

function saveAllData() {
    saveData(STORAGE_KEYS.PRINTERS, state.printers);
    saveData(STORAGE_KEYS.MATERIALS, state.materials);
    saveData(STORAGE_KEYS.PRODUCTS, state.products);
    saveData(STORAGE_KEYS.QUOTES, state.quotes);
    saveData(STORAGE_KEYS.SALES, state.sales);
    saveData(STORAGE_KEYS.CONSUMABLES, state.consumableTemplates);
    saveData(STORAGE_KEYS.SETTINGS, state.settings);
}

// ============================================================================
// NAVIGATION
// ============================================================================
function initNavigation() {
    const navBtns = document.querySelectorAll('.nav-btn');
    navBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tabId = btn.dataset.tab;
            switchTab(tabId);
        });
    });
}

function switchTab(tabId) {
    // Update nav buttons
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabId);
    });

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.toggle('active', tab.id === tabId);
    });

    // Refresh data when switching tabs
    if (tabId === 'dashboard') updateDashboard();
    if (tabId === 'calculator') populateCalculatorDropdowns();
    if (tabId === 'printers') renderPrinters();
    if (tabId === 'materials') renderMaterials();
    if (tabId === 'products') renderProducts();
}

// ============================================================================
// DASHBOARD
// ============================================================================
function updateDashboard() {
    // Calculate revenue stats
    let totalRevenue = 0;
    let totalProfit = 0;
    let totalItemsSold = 0;
    let monthlyRevenue = 0;

    const now = new Date();
    const currentMonth = now.getMonth();
    const currentYear = now.getFullYear();

    state.sales.forEach(sale => {
        const saleDate = new Date(sale.date);
        const revenue = sale.price * sale.quantity;
        const cost = sale.costPerUnit * sale.quantity;

        totalRevenue += revenue;
        totalProfit += (revenue - cost);
        totalItemsSold += sale.quantity;

        if (saleDate.getMonth() === currentMonth && saleDate.getFullYear() === currentYear) {
            monthlyRevenue += revenue;
        }
    });

    document.getElementById('totalRevenue').textContent = formatCurrency(totalRevenue);
    document.getElementById('totalProfit').textContent = formatCurrency(totalProfit);
    document.getElementById('totalItemsSold').textContent = totalItemsSold;
    document.getElementById('monthlyRevenue').textContent = formatCurrency(monthlyRevenue);

    // Printer hours summary
    const printerHoursDiv = document.getElementById('printerHoursSummary');
    if (state.printers.length === 0) {
        printerHoursDiv.innerHTML = '<p class="empty-state">No printers added yet</p>';
    } else {
        printerHoursDiv.innerHTML = state.printers.map(printer => {
            const percentUsed = Math.min((printer.hoursUsed / printer.lifespan) * 100, 100);
            return `
                <div class="printer-hour-item">
                    <span>${printer.name}</span>
                    <span>${printer.hoursUsed} / ${printer.lifespan} hrs</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${percentUsed}%"></div>
                </div>
            `;
        }).join('');
    }

    // Recent quotes
    const quotesDiv = document.getElementById('recentQuotes');
    const recentQuotes = state.quotes.slice(-5).reverse();

    if (recentQuotes.length === 0) {
        quotesDiv.innerHTML = '<p class="empty-state">No quotes yet. Create one in the Calculator tab.</p>';
    } else {
        quotesDiv.innerHTML = recentQuotes.map(quote => `
            <div class="quote-item">
                <div class="quote-info">
                    <h4>${quote.jobName}</h4>
                    <p>${quote.material} | ${quote.quantity} items | ${new Date(quote.date).toLocaleDateString()}</p>
                </div>
                <span class="quote-price">${formatCurrency(quote.grandTotal)}</span>
                <button class="btn btn-small btn-secondary" onclick="loadQuoteToCalculator('${quote.id}')">Load</button>
            </div>
        `).join('');
    }
}

// ============================================================================
// CALCULATOR
// ============================================================================
function initCalculator() {
    populateCalculatorDropdowns();

    // Add event listeners for real-time calculation
    const calcInputs = [
        'materialUsed', 'printTime', 'supportMaterial', 'quantity',
        'itemsPerBatch', 'bulkDiscount', 'designTime', 'postProcessTime',
        'marginType', 'marginValue', 'calcPrinter', 'calcMaterial'
    ];

    calcInputs.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener('input', updateCalculation);
            el.addEventListener('change', updateCalculation);
        }
    });

    // Parts and consumables buttons
    document.getElementById('addPartBtn').addEventListener('click', () => openModal('partModal'));
    document.getElementById('addConsumableBtn').addEventListener('click', () => {
        populateConsumableTemplates();
        openModal('consumableModal');
    });

    // Action buttons
    document.getElementById('saveQuoteBtn').addEventListener('click', saveQuote);
    document.getElementById('saveProductBtn').addEventListener('click', () => openSaveProductModal());
    document.getElementById('copyQuoteBtn').addEventListener('click', copyQuoteToClipboard);
    document.getElementById('pdfQuoteBtn').addEventListener('click', generatePDF);
    document.getElementById('resetCalcBtn').addEventListener('click', resetCalculator);

    // Set default margin from settings
    document.getElementById('marginType').value = state.settings.defaultMarginType;
    document.getElementById('marginValue').value = state.settings.defaultMarginValue;
}

function populateCalculatorDropdowns() {
    // Populate printers
    const printerSelect = document.getElementById('calcPrinter');
    printerSelect.innerHTML = '<option value="">Select printer...</option>';
    state.printers.forEach(printer => {
        printerSelect.innerHTML += `<option value="${printer.id}">${printer.name} (${printer.type})</option>`;
    });

    // Populate materials
    const materialSelect = document.getElementById('calcMaterial');
    materialSelect.innerHTML = '<option value="">Select material...</option>';
    state.materials.forEach(mat => {
        materialSelect.innerHTML += `<option value="${mat.id}">${mat.name} - ${formatCurrency(mat.costPerKg)}/kg</option>`;
    });
}

function updateCalculation() {
    const currency = state.settings.currencySymbol;

    // Get inputs
    const printerId = document.getElementById('calcPrinter').value;
    const materialId = document.getElementById('calcMaterial').value;
    const materialUsed = parseFloat(document.getElementById('materialUsed').value) || 0;
    const printTime = parseFloat(document.getElementById('printTime').value) || 0;
    const supportMaterial = parseFloat(document.getElementById('supportMaterial').value) || 0;
    const quantity = parseInt(document.getElementById('quantity').value) || 1;
    const itemsPerBatch = parseInt(document.getElementById('itemsPerBatch').value) || 1;
    const bulkDiscountPercent = parseFloat(document.getElementById('bulkDiscount').value) || 0;
    const designTime = parseFloat(document.getElementById('designTime').value) || 0;
    const postProcessTime = parseFloat(document.getElementById('postProcessTime').value) || 0;
    const marginType = document.getElementById('marginType').value;
    const marginValue = parseFloat(document.getElementById('marginValue').value) || 0;

    // Get printer and material
    const printer = state.printers.find(p => p.id === printerId);
    const material = state.materials.find(m => m.id === materialId);

    // Calculate costs
    let costMaterial = 0;
    let costSupport = 0;
    let costElectricity = 0;
    let costDepreciation = 0;

    if (material) {
        // Calculate effective cost per gram including shipping if detailed mode
        let effectiveCostPerKg = material.costPerKg;
        if (material.shippingCost && material.spoolWeight) {
            effectiveCostPerKg = (material.costPerKg + (material.shippingCost / (material.spoolWeight / 1000)));
        }
        costMaterial = (materialUsed / 1000) * effectiveCostPerKg;
        costSupport = (supportMaterial / 1000) * effectiveCostPerKg;
    }

    if (printer) {
        // Electricity cost
        const kWh = (printer.wattage / 1000) * printTime;
        costElectricity = kWh * state.settings.electricityRate;

        // Depreciation cost (including maintenance amortized)
        const totalPrinterCost = printer.cost + (printer.maintenanceCost || 0);
        costDepreciation = (totalPrinterCost / printer.lifespan) * printTime;
    }

    // Labor costs
    const costDesignLabor = designTime * state.settings.designLaborRate;
    const costPostLabor = postProcessTime * state.settings.postLaborRate;

    // Parts cost
    let costParts = 0;
    state.currentCalc.parts.forEach(part => {
        costParts += part.cost * part.quantity;
    });

    // Consumables cost
    let costConsumables = 0;
    const jobQuantity = (state.currentCalc && state.currentCalc.quantity) ? state.currentCalc.quantity : 1;
    state.currentCalc.consumables.forEach(cons => {
        if (cons.costType === 'per-job') {
            // Spread one-time per-job consumable cost across all units in the job
            costConsumables += cons.cost / jobQuantity;
        } else {
            costConsumables += cons.cost / cons.uses;
        }
    });

    // Wear cost
    const costWear = printTime * state.settings.wearCostPerHour;

    // Base subtotal
    let baseSubtotal = costMaterial + costSupport + costElectricity + costDepreciation +
                       costDesignLabor + costPostLabor + costParts + costConsumables + costWear;

    // Failure rate adjustment
    const failureMultiplier = state.settings.failureRate / 100;
    const costFailure = baseSubtotal * failureMultiplier;

    // Subtotal with failure
    const subtotalWithFailure = baseSubtotal + costFailure;

    // Overhead
    const costOverhead = subtotalWithFailure * (state.settings.overheadPercent / 100);

    // Subtotal before profit
    const subtotalBeforeProfit = subtotalWithFailure + costOverhead;

    // Profit
    let costProfit = 0;
    if (marginType === 'percentage') {
        costProfit = subtotalBeforeProfit * (marginValue / 100);
    } else {
        costProfit = marginValue;
    }

    // Price per unit
    const pricePerUnit = subtotalBeforeProfit + costProfit;

    // Batch efficiency: if multiple items per batch, design time is shared
    let adjustedPricePerUnit = pricePerUnit;
    if (itemsPerBatch > 1 && quantity > 1) {
        // Design labor is shared across batch
        const sharedDesignCost = costDesignLabor / itemsPerBatch;
        const designSavings = costDesignLabor - sharedDesignCost;
        adjustedPricePerUnit = pricePerUnit - (designSavings * (1 + failureMultiplier) * (1 + state.settings.overheadPercent/100));
    }

    // Bulk discount
    const bulkDiscountAmount = adjustedPricePerUnit * quantity * (bulkDiscountPercent / 100);

    // Grand total
    const grandTotal = (adjustedPricePerUnit * quantity) - bulkDiscountAmount;

    // Update display
    document.getElementById('costMaterial').textContent = formatCurrency(costMaterial);
    document.getElementById('costSupport').textContent = formatCurrency(costSupport);
    document.getElementById('costElectricity').textContent = formatCurrency(costElectricity);
    document.getElementById('costDepreciation').textContent = formatCurrency(costDepreciation);
    document.getElementById('costDesignLabor').textContent = formatCurrency(costDesignLabor);
    document.getElementById('costPostLabor').textContent = formatCurrency(costPostLabor);
    document.getElementById('costParts').textContent = formatCurrency(costParts);
    document.getElementById('costConsumables').textContent = formatCurrency(costConsumables);
    document.getElementById('costWear').textContent = formatCurrency(costWear);
    document.getElementById('costFailure').textContent = formatCurrency(costFailure);
    document.getElementById('costSubtotal').textContent = formatCurrency(baseSubtotal);
    document.getElementById('costOverhead').textContent = formatCurrency(costOverhead);
    document.getElementById('costProfit').textContent = formatCurrency(costProfit);
    document.getElementById('pricePerUnit').textContent = formatCurrency(adjustedPricePerUnit);
    document.getElementById('bulkDiscountAmount').textContent = `-${formatCurrency(bulkDiscountAmount)}`;
    document.getElementById('totalQty').textContent = quantity;
    document.getElementById('grandTotal').textContent = formatCurrency(grandTotal);

    // Store calculated values for saving
    state.currentCalc.results = {
        costMaterial, costSupport, costElectricity, costDepreciation,
        costDesignLabor, costPostLabor, costParts, costConsumables,
        costWear, costFailure, subtotalWithFailure, costOverhead,
        costProfit, pricePerUnit: adjustedPricePerUnit, bulkDiscountAmount, grandTotal
    };
}

function renderParts() {
    const container = document.getElementById('additionalParts');
    if (state.currentCalc.parts.length === 0) {
        container.innerHTML = '';
        return;
    }

    container.innerHTML = state.currentCalc.parts.map((part, index) => `
        <div class="part-item">
            <span>${part.name} (x${part.quantity})</span>
            <span class="part-total">${formatCurrency(part.cost * part.quantity)}</span>
            <button class="btn btn-small btn-danger" onclick="removePart(${index})">×</button>
        </div>
    `).join('');
}

function renderConsumables() {
    const container = document.getElementById('consumablesList');
    if (state.currentCalc.consumables.length === 0) {
        container.innerHTML = '';
        return;
    }

    container.innerHTML = state.currentCalc.consumables.map((cons, index) => {
        const effectiveCost = cons.costType === 'per-job' ? cons.cost : cons.cost / cons.uses;
        return `
            <div class="consumable-item">
                <span>${cons.name}</span>
                <span class="consumable-total">${formatCurrency(effectiveCost)}</span>
                <button class="btn btn-small btn-danger" onclick="removeConsumable(${index})">×</button>
            </div>
        `;
    }).join('');
}

function addPart() {
    const name = document.getElementById('partName').value.trim();
    const cost = parseFloat(document.getElementById('partCost').value) || 0;
    const quantity = parseInt(document.getElementById('partQuantity').value) || 1;

    if (!name) {
        alert('Please enter a part name');
        return;
    }

    state.currentCalc.parts.push({ name, cost, quantity });
    renderParts();
    updateCalculation();
    closeModal('partModal');

    // Reset form
    document.getElementById('partName').value = '';
    document.getElementById('partCost').value = '0.10';
    document.getElementById('partQuantity').value = '1';
}

function removePart(index) {
    state.currentCalc.parts.splice(index, 1);
    renderParts();
    updateCalculation();
}

function addConsumable() {
    const name = document.getElementById('consumableName').value.trim();
    const costType = document.getElementById('consumableCostType').value;
    const cost = parseFloat(document.getElementById('consumableCost').value) || 0;
    const uses = parseInt(document.getElementById('consumableUses').value) || 1;

    if (!name) {
        alert('Please enter a consumable name');
        return;
    }

    state.currentCalc.consumables.push({ name, costType, cost, uses });
    renderConsumables();
    updateCalculation();
    closeModal('consumableModal');

    // Reset form
    document.getElementById('consumableName').value = '';
    document.getElementById('consumableCost').value = '5';
    document.getElementById('consumableUses').value = '10';
}

function removeConsumable(index) {
    state.currentCalc.consumables.splice(index, 1);
    renderConsumables();
    updateCalculation();
}

function populateConsumableTemplates() {
    const select = document.getElementById('consumableTemplate');
    select.innerHTML = '<option value="">-- New Consumable --</option>';
    state.consumableTemplates.forEach(template => {
        select.innerHTML += `<option value="${template.id}">${template.name} - ${formatCurrency(template.cost)}</option>`;
    });

    select.onchange = () => {
        const templateId = select.value;
        if (templateId) {
            const template = state.consumableTemplates.find(t => t.id === templateId);
            if (template) {
                document.getElementById('consumableName').value = template.name;
                document.getElementById('consumableCost').value = template.cost;
                document.getElementById('consumableUses').value = template.uses;
                document.getElementById('consumableCostType').value = 'spread';
            }
        }
    };
}

function saveQuote() {
    const jobName = document.getElementById('jobName').value.trim() || 'Unnamed Job';
    const printerId = document.getElementById('calcPrinter').value;
    const materialId = document.getElementById('calcMaterial').value;
    const quantity = parseInt(document.getElementById('quantity').value) || 1;

    const printer = state.printers.find(p => p.id === printerId);
    const material = state.materials.find(m => m.id === materialId);

    const quote = {
        id: 'quote_' + Date.now(),
        jobName,
        printer: printer ? printer.name : 'Not specified',
        material: material ? material.name : 'Not specified',
        quantity,
        materialUsed: parseFloat(document.getElementById('materialUsed').value) || 0,
        printTime: parseFloat(document.getElementById('printTime').value) || 0,
        pricePerUnit: state.currentCalc.results?.pricePerUnit || 0,
        grandTotal: state.currentCalc.results?.grandTotal || 0,
        breakdown: { ...state.currentCalc.results },
        parts: [...state.currentCalc.parts],
        consumables: [...state.currentCalc.consumables],
        calculatorState: {
            printerId: document.getElementById('calcPrinter').value,
            materialId: document.getElementById('calcMaterial').value,
            materialUsed: document.getElementById('materialUsed').value,
            printTime: document.getElementById('printTime').value,
            supportMaterial: document.getElementById('supportMaterial').value,
            itemsPerBatch: document.getElementById('itemsPerBatch').value,
            bulkDiscount: document.getElementById('bulkDiscount').value,
            designTime: document.getElementById('designTime').value,
            postProcessTime: document.getElementById('postProcessTime').value,
            parts: [...state.currentCalc.parts],
            consumables: [...state.currentCalc.consumables],
            marginType: document.getElementById('marginType').value,
            marginValue: document.getElementById('marginValue').value
        },
        date: new Date().toISOString()
    };

    state.quotes.push(quote);
    saveData(STORAGE_KEYS.QUOTES, state.quotes);
    alert('Quote saved successfully!');
    updateDashboard();
}

function loadQuoteToCalculator(quoteId) {
    const quote = state.quotes.find(q => q.id === quoteId);
    if (!quote) return;

    switchTab('calculator');

    // If quote has full calculator state, restore it (newer format)
    if (quote.calculatorState) {
        const cs = quote.calculatorState;
        document.getElementById('jobName').value = quote.jobName;
        document.getElementById('calcPrinter').value = cs.printerId || '';
        document.getElementById('calcMaterial').value = cs.materialId || '';
        document.getElementById('materialUsed').value = cs.materialUsed || 0;
        document.getElementById('printTime').value = cs.printTime || 0;
        document.getElementById('supportMaterial').value = cs.supportMaterial || 0;
        document.getElementById('itemsPerBatch').value = cs.itemsPerBatch || 1;
        document.getElementById('bulkDiscount').value = cs.bulkDiscount || 0;
        document.getElementById('designTime').value = cs.designTime || 0;
        document.getElementById('postProcessTime').value = cs.postProcessTime || 0;
        document.getElementById('marginType').value = cs.marginType || 'percentage';
        document.getElementById('marginValue').value = cs.marginValue || 30;
        document.getElementById('quantity').value = quote.quantity;

        state.currentCalc.parts = [...(cs.parts || [])];
        state.currentCalc.consumables = [...(cs.consumables || [])];
    } else {
        // Fallback for older quotes without full calculator state
        document.getElementById('jobName').value = quote.jobName;
        document.getElementById('materialUsed').value = quote.materialUsed;
        document.getElementById('printTime').value = quote.printTime;
        document.getElementById('quantity').value = quote.quantity;

        state.currentCalc.parts = [...(quote.parts || [])];
        state.currentCalc.consumables = [...(quote.consumables || [])];
    }

    renderParts();
    renderConsumables();
    updateCalculation();
}

function resetCalculator() {
    document.getElementById('jobName').value = '';
    document.getElementById('calcPrinter').value = '';
    document.getElementById('calcMaterial').value = '';
    document.getElementById('materialUsed').value = '0';
    document.getElementById('printTime').value = '0';
    document.getElementById('supportMaterial').value = '0';
    document.getElementById('quantity').value = '1';
    document.getElementById('itemsPerBatch').value = '1';
    document.getElementById('bulkDiscount').value = '0';
    document.getElementById('designTime').value = '0';
    document.getElementById('postProcessTime').value = '0';
    document.getElementById('marginType').value = state.settings.defaultMarginType;
    document.getElementById('marginValue').value = state.settings.defaultMarginValue;

    state.currentCalc.parts = [];
    state.currentCalc.consumables = [];

    renderParts();
    renderConsumables();
    updateCalculation();
}

function copyQuoteToClipboard() {
    const showBreakdown = document.getElementById('showBreakdown').checked;
    const jobName = document.getElementById('jobName').value || 'Quote';
    const quantity = document.getElementById('quantity').value || 1;
    const results = state.currentCalc.results || {};

    let text = `=== ${jobName} ===\n`;
    text += `Quantity: ${quantity}\n\n`;

    if (showBreakdown) {
        text += `Material: ${formatCurrency(results.costMaterial || 0)}\n`;
        text += `Labor: ${formatCurrency((results.costDesignLabor || 0) + (results.costPostLabor || 0))}\n`;
        text += `Other Costs: ${formatCurrency((results.costElectricity || 0) + (results.costDepreciation || 0) + (results.costWear || 0) + (results.costParts || 0) + (results.costConsumables || 0))}\n`;
        text += `-------------------\n`;
    }

    text += `Price per Unit: ${formatCurrency(results.pricePerUnit || 0)}\n`;
    text += `TOTAL: ${formatCurrency(results.grandTotal || 0)}\n`;

    navigator.clipboard.writeText(text).then(() => {
        alert('Quote copied to clipboard!');
    });
}

function generatePDF() {
    const showBreakdown = document.getElementById('showBreakdown').checked;
    const jobName = document.getElementById('jobName').value || 'Quote';
    const quantity = document.getElementById('quantity').value || 1;
    const results = state.currentCalc.results || {};
    const material = state.materials.find(m => m.id === document.getElementById('calcMaterial').value);

    // Create a printable content
    const content = `
        <html>
        <head>
            <title>Print Cost Pro - Quote</title>
            <style>
                body { font-family: Arial, sans-serif; padding: 40px; max-width: 600px; margin: 0 auto; }
                h1 { color: #333; border-bottom: 2px solid #4f8cff; padding-bottom: 10px; }
                .quote-header { margin-bottom: 30px; }
                .quote-details { margin-bottom: 20px; }
                .quote-line { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
                .quote-total { font-size: 1.5em; font-weight: bold; color: #10b981; margin-top: 20px; padding-top: 20px; border-top: 2px solid #333; }
                .footer { margin-top: 40px; color: #666; font-size: 0.9em; }
            </style>
        </head>
        <body>
            <div class="quote-header">
                <h1>Print Cost Pro</h1>
                <p>Quote #${Date.now()}</p>
                <p>Date: ${new Date().toLocaleDateString()}</p>
            </div>
            <h2>${jobName}</h2>
            <div class="quote-details">
                <p>Quantity: ${quantity}</p>
                ${material ? `<p>Material: ${material.name}</p>` : ''}
            </div>
            ${showBreakdown ? `
                <div class="quote-line"><span>Material Cost</span><span>${formatCurrency(results.costMaterial || 0)}</span></div>
                <div class="quote-line"><span>Labor</span><span>${formatCurrency((results.costDesignLabor || 0) + (results.costPostLabor || 0))}</span></div>
                <div class="quote-line"><span>Production Costs</span><span>${formatCurrency((results.costElectricity || 0) + (results.costDepreciation || 0) + (results.costWear || 0))}</span></div>
                ${results.costParts > 0 ? `<div class="quote-line"><span>Parts/Hardware</span><span>${formatCurrency(results.costParts)}</span></div>` : ''}
                ${results.costConsumables > 0 ? `<div class="quote-line"><span>Finishing</span><span>${formatCurrency(results.costConsumables)}</span></div>` : ''}
            ` : ''}
            <div class="quote-line"><span>Price per Unit</span><span>${formatCurrency(results.pricePerUnit || 0)}</span></div>
            ${results.bulkDiscountAmount > 0 ? `<div class="quote-line"><span>Bulk Discount</span><span>-${formatCurrency(results.bulkDiscountAmount)}</span></div>` : ''}
            <div class="quote-total">
                <span>Total: ${formatCurrency(results.grandTotal || 0)}</span>
            </div>
            <div class="footer">
                <p>Generated by Print Cost Pro</p>
            </div>
        </body>
        </html>
    `;

    const printWindow = window.open('', '_blank');
    printWindow.document.write(content);
    printWindow.document.close();
    printWindow.print();
}

// ============================================================================
// PRINTERS
// ============================================================================
function initPrinters() {
    document.getElementById('addPrinterBtn').addEventListener('click', () => {
        resetPrinterForm();
        document.getElementById('printerModalTitle').textContent = 'Add Printer';
        populatePrinterPresets();
        openModal('printerModal');
    });

    document.getElementById('savePrinterBtn').addEventListener('click', savePrinter);

    document.getElementById('printerPreset').addEventListener('change', (e) => {
        const presetName = e.target.value;
        if (presetName) {
            const preset = PRINTER_PRESETS.find(p => p.name === presetName);
            if (preset) {
                document.getElementById('printerName').value = preset.name;
                document.getElementById('printerType').value = preset.type;
                document.getElementById('printerCost').value = preset.cost;
                document.getElementById('printerLifespan').value = preset.lifespan;
                document.getElementById('printerWattage').value = preset.wattage;
                document.getElementById('printerPeakWattage').value = preset.peakWattage;
            }
        }
    });

    renderPrinters();
}

function populatePrinterPresets() {
    const select = document.getElementById('printerPreset');
    select.innerHTML = '<option value="">-- Custom Printer --</option>';

    // Group by manufacturer
    const fdmPrinters = PRINTER_PRESETS.filter(p => p.type === 'FDM');
    const resinPrinters = PRINTER_PRESETS.filter(p => p.type === 'Resin');

    select.innerHTML += '<optgroup label="FDM Printers">';
    fdmPrinters.forEach(p => {
        select.innerHTML += `<option value="${p.name}">${p.name}</option>`;
    });
    select.innerHTML += '</optgroup>';

    select.innerHTML += '<optgroup label="Resin Printers">';
    resinPrinters.forEach(p => {
        select.innerHTML += `<option value="${p.name}">${p.name}</option>`;
    });
    select.innerHTML += '</optgroup>';
}

function resetPrinterForm() {
    document.getElementById('printerPreset').value = '';
    document.getElementById('printerName').value = '';
    document.getElementById('printerType').value = 'FDM';
    document.getElementById('printerCost').value = '300';
    document.getElementById('printerLifespan').value = '5000';
    document.getElementById('printerWattage').value = '150';
    document.getElementById('printerPeakWattage').value = '350';
    document.getElementById('printerMaintenanceCost').value = '50';
    document.getElementById('printerHoursUsed').value = '0';
    delete document.getElementById('savePrinterBtn').dataset.editId;
}

function savePrinter() {
    const name = document.getElementById('printerName').value.trim();
    const type = document.getElementById('printerType').value;
    const cost = parseFloat(document.getElementById('printerCost').value) || 0;
    const lifespan = parseInt(document.getElementById('printerLifespan').value) || 5000;
    const wattage = parseInt(document.getElementById('printerWattage').value) || 150;
    const peakWattage = parseInt(document.getElementById('printerPeakWattage').value) || 350;
    const maintenanceCost = parseFloat(document.getElementById('printerMaintenanceCost').value) || 0;
    const hoursUsed = parseInt(document.getElementById('printerHoursUsed').value) || 0;

    if (!name) {
        alert('Please enter a printer name');
        return;
    }

    const editId = document.getElementById('savePrinterBtn').dataset.editId;

    if (editId) {
        // Update existing
        const index = state.printers.findIndex(p => p.id === editId);
        if (index !== -1) {
            state.printers[index] = {
                ...state.printers[index],
                name, type, cost, lifespan, wattage, peakWattage, maintenanceCost, hoursUsed
            };
        }
    } else {
        // Add new
        state.printers.push({
            id: 'printer_' + Date.now(),
            name, type, cost, lifespan, wattage, peakWattage, maintenanceCost, hoursUsed
        });
    }

    saveData(STORAGE_KEYS.PRINTERS, state.printers);
    renderPrinters();
    populateCalculatorDropdowns();
    closeModal('printerModal');
}

function renderPrinters() {
    const container = document.getElementById('printersList');

    if (state.printers.length === 0) {
        container.innerHTML = '<p class="empty-state">No printers added yet. Click "Add Printer" to get started.</p>';
        return;
    }

    container.innerHTML = state.printers.map(printer => {
        const percentUsed = Math.min((printer.hoursUsed / printer.lifespan) * 100, 100);
        return `
            <div class="printer-card">
                <h4>
                    ${printer.name}
                    <span class="printer-type-badge ${printer.type.toLowerCase()}">${printer.type}</span>
                </h4>
                <div class="card-details">
                    <p>Cost: ${formatCurrency(printer.cost)} | Lifespan: ${printer.lifespan} hrs</p>
                    <p>Power: ${printer.wattage}W avg / ${printer.peakWattage}W peak</p>
                    <p>Hours Used: ${printer.hoursUsed} / ${printer.lifespan}</p>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${percentUsed}%"></div>
                </div>
                <div class="card-actions">
                    <button class="btn btn-small btn-secondary" onclick="editPrinter('${printer.id}')">Edit</button>
                    <button class="btn btn-small btn-secondary" onclick="updatePrinterHours('${printer.id}')">Log Hours</button>
                    <button class="btn btn-small btn-danger" onclick="deletePrinter('${printer.id}')">Delete</button>
                </div>
            </div>
        `;
    }).join('');
}

function editPrinter(id) {
    const printer = state.printers.find(p => p.id === id);
    if (!printer) return;

    document.getElementById('printerModalTitle').textContent = 'Edit Printer';
    document.getElementById('printerName').value = printer.name;
    document.getElementById('printerType').value = printer.type;
    document.getElementById('printerCost').value = printer.cost;
    document.getElementById('printerLifespan').value = printer.lifespan;
    document.getElementById('printerWattage').value = printer.wattage;
    document.getElementById('printerPeakWattage').value = printer.peakWattage;
    document.getElementById('printerMaintenanceCost').value = printer.maintenanceCost || 0;
    document.getElementById('printerHoursUsed').value = printer.hoursUsed || 0;
    document.getElementById('savePrinterBtn').dataset.editId = id;

    populatePrinterPresets();
    openModal('printerModal');
}

function updatePrinterHours(id) {
    const printer = state.printers.find(p => p.id === id);
    if (!printer) return;

    const newHours = prompt(`Enter total hours for ${printer.name}:`, printer.hoursUsed);
    if (newHours !== null) {
        printer.hoursUsed = parseInt(newHours) || 0;
        saveData(STORAGE_KEYS.PRINTERS, state.printers);
        renderPrinters();
        updateDashboard();
    }
}

function deletePrinter(id) {
    if (!confirm('Are you sure you want to delete this printer?')) return;

    state.printers = state.printers.filter(p => p.id !== id);
    saveData(STORAGE_KEYS.PRINTERS, state.printers);
    renderPrinters();
    populateCalculatorDropdowns();
}

// ============================================================================
// MATERIALS
// ============================================================================
function initMaterials() {
    document.getElementById('addMaterialBtn').addEventListener('click', () => {
        resetMaterialForm();
        document.getElementById('materialModalTitle').textContent = 'Add Material';
        openModal('materialModal');
    });

    document.getElementById('saveMaterialBtn').addEventListener('click', saveMaterial);

    document.getElementById('materialTrackingMode').addEventListener('change', (e) => {
        state.settings.materialTrackingMode = e.target.value;
        saveData(STORAGE_KEYS.SETTINGS, state.settings);
        updateMaterialFormFields();
    });

    document.getElementById('addSavedConsumableBtn').addEventListener('click', () => {
        openModal('consumableTemplateModal');
    });

    document.getElementById('saveTemplateBtn').addEventListener('click', saveConsumableTemplate);

    renderMaterials();
    renderConsumableTemplates();
}

function updateMaterialFormFields() {
    const mode = state.settings.materialTrackingMode;
    document.getElementById('materialTrackingMode').value = mode;

    const detailedFields = document.getElementById('detailedMaterialFields');
    const inventoryFields = document.getElementById('inventoryMaterialFields');

    detailedFields.classList.toggle('visible', mode === 'detailed' || mode === 'inventory');
    inventoryFields.classList.toggle('visible', mode === 'inventory');
}

function resetMaterialForm() {
    document.getElementById('materialName').value = '';
    document.getElementById('materialType').value = 'PLA';
    document.getElementById('materialColor').value = '';
    document.getElementById('materialCostPerKg').value = '25';
    document.getElementById('materialDensity').value = '1.24';
    document.getElementById('materialSpoolWeight').value = '1000';
    document.getElementById('materialShipping').value = '0';
    document.getElementById('materialQuantityOwned').value = '1';
    document.getElementById('materialRemainingGrams').value = '1000';
    document.getElementById('materialPurchaseDate').value = '';
    delete document.getElementById('saveMaterialBtn').dataset.editId;
    updateMaterialFormFields();
}

function saveMaterial() {
    const name = document.getElementById('materialName').value.trim();
    const type = document.getElementById('materialType').value;
    const color = document.getElementById('materialColor').value.trim();
    const costPerKg = parseFloat(document.getElementById('materialCostPerKg').value) || 0;
    const density = parseFloat(document.getElementById('materialDensity').value) || 1.24;

    if (!name) {
        alert('Please enter a material name');
        return;
    }

    const material = {
        name, type, color, costPerKg, density
    };

    // Add detailed fields if applicable
    if (state.settings.materialTrackingMode === 'detailed' || state.settings.materialTrackingMode === 'inventory') {
        material.spoolWeight = parseInt(document.getElementById('materialSpoolWeight').value) || 1000;
        material.shippingCost = parseFloat(document.getElementById('materialShipping').value) || 0;
    }

    // Add inventory fields if applicable
    if (state.settings.materialTrackingMode === 'inventory') {
        material.spoolsOwned = parseInt(document.getElementById('materialQuantityOwned').value) || 1;
        material.remainingGrams = parseInt(document.getElementById('materialRemainingGrams').value) || 1000;
        material.purchaseDate = document.getElementById('materialPurchaseDate').value;
    }

    const editId = document.getElementById('saveMaterialBtn').dataset.editId;

    if (editId) {
        const index = state.materials.findIndex(m => m.id === editId);
        if (index !== -1) {
            state.materials[index] = { ...state.materials[index], ...material };
        }
    } else {
        material.id = 'mat_' + Date.now();
        state.materials.push(material);
    }

    saveData(STORAGE_KEYS.MATERIALS, state.materials);
    renderMaterials();
    populateCalculatorDropdowns();
    closeModal('materialModal');
}

function renderMaterials() {
    const container = document.getElementById('materialsList');
    document.getElementById('materialTrackingMode').value = state.settings.materialTrackingMode;

    if (state.materials.length === 0) {
        container.innerHTML = '<p class="empty-state">No materials added yet.</p>';
        return;
    }

    container.innerHTML = state.materials.map(mat => {
        let detailsHtml = `<p>Cost: ${formatCurrency(mat.costPerKg)}/kg | Density: ${mat.density} g/cm³</p>`;

        if (mat.shippingCost) {
            detailsHtml += `<p>Shipping: ${formatCurrency(mat.shippingCost)}</p>`;
        }
        if (mat.remainingGrams !== undefined) {
            detailsHtml += `<p>Stock: ${mat.spoolsOwned} spools | ${mat.remainingGrams}g remaining</p>`;
        }

        return `
            <div class="material-card">
                <h4>
                    ${mat.name}
                    <span class="material-type-badge">${mat.type}</span>
                </h4>
                <div class="card-details">
                    ${mat.color ? `<p>Color: ${mat.color}</p>` : ''}
                    ${detailsHtml}
                </div>
                <div class="card-actions">
                    <button class="btn btn-small btn-secondary" onclick="editMaterial('${mat.id}')">Edit</button>
                    <button class="btn btn-small btn-danger" onclick="deleteMaterial('${mat.id}')">Delete</button>
                </div>
            </div>
        `;
    }).join('');
}

function editMaterial(id) {
    const mat = state.materials.find(m => m.id === id);
    if (!mat) return;

    document.getElementById('materialModalTitle').textContent = 'Edit Material';
    document.getElementById('materialName').value = mat.name;
    document.getElementById('materialType').value = mat.type;
    document.getElementById('materialColor').value = mat.color || '';
    document.getElementById('materialCostPerKg').value = mat.costPerKg;
    document.getElementById('materialDensity').value = mat.density;
    document.getElementById('materialSpoolWeight').value = mat.spoolWeight || 1000;
    document.getElementById('materialShipping').value = mat.shippingCost || 0;
    document.getElementById('materialQuantityOwned').value = mat.spoolsOwned || 1;
    document.getElementById('materialRemainingGrams').value = mat.remainingGrams || 1000;
    document.getElementById('materialPurchaseDate').value = mat.purchaseDate || '';
    document.getElementById('saveMaterialBtn').dataset.editId = id;

    updateMaterialFormFields();
    openModal('materialModal');
}

function deleteMaterial(id) {
    if (!confirm('Are you sure you want to delete this material?')) return;

    state.materials = state.materials.filter(m => m.id !== id);
    saveData(STORAGE_KEYS.MATERIALS, state.materials);
    renderMaterials();
    populateCalculatorDropdowns();
}

function saveConsumableTemplate() {
    const name = document.getElementById('templateName').value.trim();
    const cost = parseFloat(document.getElementById('templateCost').value) || 0;
    const uses = parseInt(document.getElementById('templateUses').value) || 1;

    if (!name) {
        alert('Please enter a name');
        return;
    }

    state.consumableTemplates.push({
        id: 'cons_' + Date.now(),
        name, cost, uses
    });

    saveData(STORAGE_KEYS.CONSUMABLES, state.consumableTemplates);
    renderConsumableTemplates();
    closeModal('consumableTemplateModal');

    document.getElementById('templateName').value = '';
    document.getElementById('templateCost').value = '8';
    document.getElementById('templateUses').value = '20';
}

function renderConsumableTemplates() {
    const container = document.getElementById('savedConsumablesList');

    if (state.consumableTemplates.length === 0) {
        container.innerHTML = '<p class="empty-state">No consumable templates saved.</p>';
        return;
    }

    container.innerHTML = state.consumableTemplates.map(template => `
        <div class="consumable-template-card">
            <h4>${template.name}</h4>
            <div class="card-details">
                <p>Cost: ${formatCurrency(template.cost)} | Uses: ${template.uses}</p>
                <p>Per Use: ${formatCurrency(template.cost / template.uses)}</p>
            </div>
            <div class="card-actions">
                <button class="btn btn-small btn-danger" onclick="deleteConsumableTemplate('${template.id}')">Delete</button>
            </div>
        </div>
    `).join('');
}

function deleteConsumableTemplate(id) {
    if (!confirm('Delete this consumable template?')) return;
    state.consumableTemplates = state.consumableTemplates.filter(t => t.id !== id);
    saveData(STORAGE_KEYS.CONSUMABLES, state.consumableTemplates);
    renderConsumableTemplates();
}

// ============================================================================
// PRODUCTS & SALES
// ============================================================================
function initProducts() {
    document.getElementById('saveProductConfirmBtn').addEventListener('click', saveProduct);
    document.getElementById('saveSaleBtn').addEventListener('click', saveSale);

    document.getElementById('salesProductFilter').addEventListener('change', renderSales);
    document.getElementById('salesMonthFilter').addEventListener('change', renderSales);

    renderProducts();
    renderSales();
    populateSalesFilters();
}

function openSaveProductModal() {
    const jobName = document.getElementById('jobName').value.trim();
    document.getElementById('productName').value = jobName;
    document.getElementById('productDescription').value = '';
    document.getElementById('productCategory').value = '';
    openModal('productModal');
}

function saveProduct() {
    const name = document.getElementById('productName').value.trim();
    const description = document.getElementById('productDescription').value.trim();
    const category = document.getElementById('productCategory').value.trim();

    if (!name) {
        alert('Please enter a product name');
        return;
    }

    const product = {
        id: 'prod_' + Date.now(),
        name,
        description,
        category,
        pricePerUnit: state.currentCalc.results?.pricePerUnit || 0,
        costPerUnit: state.currentCalc.results?.subtotalWithFailure || 0,
        calculatorState: {
            printerId: document.getElementById('calcPrinter').value,
            materialId: document.getElementById('calcMaterial').value,
            materialUsed: document.getElementById('materialUsed').value,
            printTime: document.getElementById('printTime').value,
            supportMaterial: document.getElementById('supportMaterial').value,
            designTime: document.getElementById('designTime').value,
            postProcessTime: document.getElementById('postProcessTime').value,
            parts: [...state.currentCalc.parts],
            consumables: [...state.currentCalc.consumables],
            marginType: document.getElementById('marginType').value,
            marginValue: document.getElementById('marginValue').value
        },
        totalSold: 0,
        totalRevenue: 0,
        createdAt: new Date().toISOString()
    };

    state.products.push(product);
    saveData(STORAGE_KEYS.PRODUCTS, state.products);
    renderProducts();
    populateSalesFilters();
    closeModal('productModal');
    alert('Product saved successfully!');
}

function renderProducts() {
    const container = document.getElementById('productsList');

    if (state.products.length === 0) {
        container.innerHTML = '<p class="empty-state">No products saved yet. Save a calculation as a product from the Calculator.</p>';
        return;
    }

    container.innerHTML = state.products.map(product => `
        <div class="product-card">
            <h4>${product.name}</h4>
            ${product.category ? `<p class="text-muted">${product.category}</p>` : ''}
            ${product.description ? `<p>${product.description}</p>` : ''}
            <div class="product-price">${formatCurrency(product.pricePerUnit)}</div>
            <div class="product-stats">
                <span>Sold: ${product.totalSold}</span>
                <span>Revenue: ${formatCurrency(product.totalRevenue)}</span>
            </div>
            <div class="card-actions">
                <button class="btn btn-small btn-primary" onclick="loadProductToCalculator('${product.id}')">Load</button>
                <button class="btn btn-small btn-secondary" onclick="recordSale('${product.id}')">Record Sale</button>
                <button class="btn btn-small btn-danger" onclick="deleteProduct('${product.id}')">Delete</button>
            </div>
        </div>
    `).join('');
}

function loadProductToCalculator(productId) {
    const product = state.products.find(p => p.id === productId);
    if (!product || !product.calculatorState) return;

    switchTab('calculator');

    const cs = product.calculatorState;
    document.getElementById('jobName').value = product.name;
    document.getElementById('calcPrinter').value = cs.printerId || '';
    document.getElementById('calcMaterial').value = cs.materialId || '';
    document.getElementById('materialUsed').value = cs.materialUsed || 0;
    document.getElementById('printTime').value = cs.printTime || 0;
    document.getElementById('supportMaterial').value = cs.supportMaterial || 0;
    document.getElementById('designTime').value = cs.designTime || 0;
    document.getElementById('postProcessTime').value = cs.postProcessTime || 0;
    document.getElementById('marginType').value = cs.marginType || 'percentage';
    document.getElementById('marginValue').value = cs.marginValue || 30;

    state.currentCalc.parts = [...(cs.parts || [])];
    state.currentCalc.consumables = [...(cs.consumables || [])];

    renderParts();
    renderConsumables();
    updateCalculation();
}

function recordSale(productId) {
    const product = state.products.find(p => p.id === productId);
    if (!product) return;

    document.getElementById('saleQuantity').value = 1;
    document.getElementById('salePrice').value = product.pricePerUnit.toFixed(2);
    document.getElementById('saleDate').value = new Date().toISOString().split('T')[0];
    document.getElementById('saleNotes').value = '';
    document.getElementById('saveSaleBtn').dataset.productId = productId;

    openModal('saleModal');
}

function saveSale() {
    const productId = document.getElementById('saveSaleBtn').dataset.productId;
    const product = state.products.find(p => p.id === productId);
    if (!product) return;

    const quantity = parseInt(document.getElementById('saleQuantity').value) || 1;
    const price = parseFloat(document.getElementById('salePrice').value) || product.pricePerUnit;
    const date = document.getElementById('saleDate').value || new Date().toISOString().split('T')[0];
    const notes = document.getElementById('saleNotes').value.trim();

    const sale = {
        id: 'sale_' + Date.now(),
        productId,
        productName: product.name,
        quantity,
        price,
        costPerUnit: product.costPerUnit,
        date,
        notes
    };

    state.sales.push(sale);
    saveData(STORAGE_KEYS.SALES, state.sales);

    // Update product stats
    product.totalSold += quantity;
    product.totalRevenue += price * quantity;
    saveData(STORAGE_KEYS.PRODUCTS, state.products);

    renderProducts();
    renderSales();
    updateDashboard();
    closeModal('saleModal');
}

function populateSalesFilters() {
    const select = document.getElementById('salesProductFilter');
    select.innerHTML = '<option value="all">All Products</option>';
    state.products.forEach(product => {
        select.innerHTML += `<option value="${product.id}">${product.name}</option>`;
    });
}

function renderSales() {
    const container = document.getElementById('salesList');
    const productFilter = document.getElementById('salesProductFilter').value;
    const monthFilter = document.getElementById('salesMonthFilter').value;

    let filteredSales = [...state.sales];

    if (productFilter !== 'all') {
        filteredSales = filteredSales.filter(s => s.productId === productFilter);
    }

    if (monthFilter) {
        filteredSales = filteredSales.filter(s => s.date.startsWith(monthFilter));
    }

    filteredSales.sort((a, b) => new Date(b.date) - new Date(a.date));

    if (filteredSales.length === 0) {
        container.innerHTML = '<p class="empty-state">No sales recorded yet.</p>';
        return;
    }

    container.innerHTML = filteredSales.map(sale => {
        const profit = (sale.price - sale.costPerUnit) * sale.quantity;
        return `
            <div class="sale-item">
                <span><strong>${sale.productName}</strong></span>
                <span>x${sale.quantity}</span>
                <span>${formatCurrency(sale.price * sale.quantity)}</span>
                <span class="text-success">+${formatCurrency(profit)}</span>
                <span class="text-muted">${new Date(sale.date).toLocaleDateString()}</span>
            </div>
        `;
    }).join('');
}

function deleteProduct(id) {
    if (!confirm('Delete this product? Sales history will be preserved.')) return;

    state.products = state.products.filter(p => p.id !== id);
    saveData(STORAGE_KEYS.PRODUCTS, state.products);
    renderProducts();
    populateSalesFilters();
}

// ============================================================================
// SETTINGS
// ============================================================================
function initSettings() {
    // Load settings into form
    document.getElementById('electricityRate').value = state.settings.electricityRate;
    document.getElementById('designLaborRate').value = state.settings.designLaborRate;
    document.getElementById('postLaborRate').value = state.settings.postLaborRate;
    document.getElementById('failureRate').value = state.settings.failureRate;
    document.getElementById('wearCostPerHour').value = state.settings.wearCostPerHour;
    document.getElementById('overheadPercent').value = state.settings.overheadPercent;
    document.getElementById('defaultMarginType').value = state.settings.defaultMarginType;
    document.getElementById('defaultMarginValue').value = state.settings.defaultMarginValue;
    document.getElementById('currencySymbol').value = state.settings.currencySymbol;

    // Add listeners
    const settingInputs = [
        'electricityRate', 'designLaborRate', 'postLaborRate', 'failureRate',
        'wearCostPerHour', 'overheadPercent', 'defaultMarginType', 'defaultMarginValue', 'currencySymbol'
    ];

    settingInputs.forEach(id => {
        document.getElementById(id).addEventListener('change', saveSettings);
    });

    document.getElementById('resetSettingsBtn').addEventListener('click', resetSettings);
    document.getElementById('clearAllDataBtn').addEventListener('click', clearAllData);
}

function saveSettings() {
    state.settings.electricityRate = parseFloat(document.getElementById('electricityRate').value) || 0.12;
    state.settings.designLaborRate = parseFloat(document.getElementById('designLaborRate').value) || 15;
    state.settings.postLaborRate = parseFloat(document.getElementById('postLaborRate').value) || 12;
    state.settings.failureRate = parseFloat(document.getElementById('failureRate').value) || 5;
    state.settings.wearCostPerHour = parseFloat(document.getElementById('wearCostPerHour').value) || 0.10;
    state.settings.overheadPercent = parseFloat(document.getElementById('overheadPercent').value) || 15;
    state.settings.defaultMarginType = document.getElementById('defaultMarginType').value;
    state.settings.defaultMarginValue = parseFloat(document.getElementById('defaultMarginValue').value) || 30;
    state.settings.currencySymbol = document.getElementById('currencySymbol').value || '$';

    saveData(STORAGE_KEYS.SETTINGS, state.settings);
}

function resetSettings() {
    if (!confirm('Reset all settings to defaults?')) return;

    state.settings = {
        electricityRate: 0.12,
        designLaborRate: 15,
        postLaborRate: 12,
        failureRate: 5,
        wearCostPerHour: 0.10,
        overheadPercent: 15,
        defaultMarginType: 'percentage',
        defaultMarginValue: 30,
        currencySymbol: '$',
        materialTrackingMode: 'simple'
    };

    saveData(STORAGE_KEYS.SETTINGS, state.settings);
    initSettings();
    alert('Settings reset to defaults');
}

function clearAllData() {
    if (!confirm('This will delete ALL data including printers, materials, products, quotes, and sales. Are you sure?')) return;
    if (!confirm('This cannot be undone. Really delete everything?')) return;

    localStorage.removeItem(STORAGE_KEYS.PRINTERS);
    localStorage.removeItem(STORAGE_KEYS.MATERIALS);
    localStorage.removeItem(STORAGE_KEYS.PRODUCTS);
    localStorage.removeItem(STORAGE_KEYS.QUOTES);
    localStorage.removeItem(STORAGE_KEYS.SALES);
    localStorage.removeItem(STORAGE_KEYS.CONSUMABLES);
    localStorage.removeItem(STORAGE_KEYS.SETTINGS);

    location.reload();
}

// ============================================================================
// EXPORT / IMPORT
// ============================================================================
function initExportImport() {
    document.getElementById('exportBtn').addEventListener('click', exportAllData);
    document.getElementById('importBtn').addEventListener('click', () => {
        document.getElementById('importFile').click();
    });
    document.getElementById('importFile').addEventListener('change', importData);
}

function exportAllData() {
    const data = {
        version: '1.0',
        exportDate: new Date().toISOString(),
        printers: state.printers,
        materials: state.materials,
        products: state.products,
        quotes: state.quotes,
        sales: state.sales,
        consumableTemplates: state.consumableTemplates,
        settings: state.settings
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `print-cost-pro-backup-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
}

function importData(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
        try {
            const data = JSON.parse(e.target.result);

            if (!confirm('This will replace all current data. Continue?')) {
                event.target.value = '';
                return;
            }

            if (data.printers) state.printers = data.printers;
            if (data.materials) state.materials = data.materials;
            if (data.products) state.products = data.products;
            if (data.quotes) state.quotes = data.quotes;
            if (data.sales) state.sales = data.sales;
            if (data.consumableTemplates) state.consumableTemplates = data.consumableTemplates;
            if (data.settings) state.settings = { ...state.settings, ...data.settings };

            saveAllData();
            alert('Data imported successfully!');
            location.reload();
        } catch (err) {
            alert('Error importing file: ' + err.message);
        }
    };
    reader.readAsText(file);
    event.target.value = '';
}

// ============================================================================
// MODALS
// ============================================================================
function initModals() {
    // Close buttons
    document.querySelectorAll('.modal-close, .modal-cancel').forEach(btn => {
        btn.addEventListener('click', () => {
            const modal = btn.closest('.modal');
            if (modal) closeModal(modal.id);
        });
    });

    // Click outside to close
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeModal(modal.id);
        });
    });

    // Part modal save
    document.getElementById('savePartBtn').addEventListener('click', addPart);

    // Consumable modal save
    document.getElementById('saveConsumableBtn').addEventListener('click', addConsumable);

    // Consumable cost type change
    document.getElementById('consumableCostType').addEventListener('change', (e) => {
        const usesGroup = document.getElementById('consumableUsesGroup');
        usesGroup.style.display = e.target.value === 'spread' ? 'block' : 'none';
    });
}

function openModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// ============================================================================
// UTILITIES
// ============================================================================
function formatCurrency(amount) {
    const symbol = state.settings.currencySymbol || '$';
    return `${symbol}${(amount || 0).toFixed(2)}`;
}

function generateId(prefix) {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// Make functions available globally for onclick handlers
window.editPrinter = editPrinter;
window.updatePrinterHours = updatePrinterHours;
window.deletePrinter = deletePrinter;
window.editMaterial = editMaterial;
window.deleteMaterial = deleteMaterial;
window.deleteConsumableTemplate = deleteConsumableTemplate;
window.loadProductToCalculator = loadProductToCalculator;
window.recordSale = recordSale;
window.deleteProduct = deleteProduct;
window.loadQuoteToCalculator = loadQuoteToCalculator;
window.removePart = removePart;
window.removeConsumable = removeConsumable;
