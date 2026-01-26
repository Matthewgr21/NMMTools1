// 3D Print Costs Calculator
// Data stored locally using localStorage

// Default data
const defaultMaterials = [
    { id: 1, name: 'PLA Standard', type: 'PLA', costPerKg: 25, density: 1.24, color: 'Various' },
    { id: 2, name: 'PETG', type: 'PETG', costPerKg: 30, density: 1.27, color: 'Various' },
    { id: 3, name: 'ABS', type: 'ABS', costPerKg: 28, density: 1.04, color: 'Various' },
    { id: 4, name: 'TPU Flexible', type: 'TPU', costPerKg: 45, density: 1.21, color: 'Various' },
    { id: 5, name: 'PLA+', type: 'PLA', costPerKg: 32, density: 1.24, color: 'Various' }
];

const defaultSettings = {
    printerName: 'Default Printer',
    printerCost: 500,
    printerLifespan: 5000,
    powerConsumption: 150,
    electricityRate: 0.12,
    laborRate: 15,
    overheadRate: 20,
    profitMargin: 30,
    currency: '$'
};

// State
let materials = [];
let settings = {};
let history = [];
let editingMaterialId = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    loadData();
    initTabs();
    initCalculator();
    initMaterials();
    initSettings();
    initHistory();
    updateCalculation();
});

// Local Storage Functions
function loadData() {
    const storedMaterials = localStorage.getItem('3dpc_materials');
    const storedSettings = localStorage.getItem('3dpc_settings');
    const storedHistory = localStorage.getItem('3dpc_history');

    materials = storedMaterials ? JSON.parse(storedMaterials) : [...defaultMaterials];
    settings = storedSettings ? JSON.parse(storedSettings) : { ...defaultSettings };
    history = storedHistory ? JSON.parse(storedHistory) : [];
}

function saveData() {
    localStorage.setItem('3dpc_materials', JSON.stringify(materials));
    localStorage.setItem('3dpc_settings', JSON.stringify(settings));
    localStorage.setItem('3dpc_history', JSON.stringify(history));
}

function saveMaterials() {
    localStorage.setItem('3dpc_materials', JSON.stringify(materials));
}

function saveSettings() {
    localStorage.setItem('3dpc_settings', JSON.stringify(settings));
}

function saveHistory() {
    localStorage.setItem('3dpc_history', JSON.stringify(history));
}

// Tab Navigation
function initTabs() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tabId = btn.dataset.tab;

            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            btn.classList.add('active');
            document.getElementById(tabId).classList.add('active');
        });
    });
}

// Calculator
function initCalculator() {
    populateMaterialSelect();

    // Add event listeners to all calculator inputs
    const inputs = [
        'materialSelect', 'filamentUsed', 'printTime', 'supportMaterial',
        'failureRisk', 'postProcessing', 'quantity'
    ];

    inputs.forEach(id => {
        document.getElementById(id).addEventListener('input', updateCalculation);
        document.getElementById(id).addEventListener('change', updateCalculation);
    });

    document.getElementById('saveQuote').addEventListener('click', saveQuote);
    document.getElementById('resetCalc').addEventListener('click', resetCalculator);
}

function populateMaterialSelect() {
    const select = document.getElementById('materialSelect');
    select.innerHTML = materials.map(m =>
        `<option value="${m.id}">${m.name} (${m.type}) - ${settings.currency}${m.costPerKg}/kg</option>`
    ).join('');
}

function updateCalculation() {
    const materialId = parseInt(document.getElementById('materialSelect').value);
    const filamentUsed = parseFloat(document.getElementById('filamentUsed').value) || 0;
    const printTime = parseFloat(document.getElementById('printTime').value) || 0;
    const supportMaterial = parseFloat(document.getElementById('supportMaterial').value) || 0;
    const failureRisk = parseFloat(document.getElementById('failureRisk').value) || 1;
    const postProcessing = parseFloat(document.getElementById('postProcessing').value) || 0;
    const quantity = parseInt(document.getElementById('quantity').value) || 1;

    const material = materials.find(m => m.id === materialId);
    if (!material) return;

    const currency = settings.currency;

    // Calculate costs
    const materialCost = (filamentUsed / 1000) * material.costPerKg;
    const supportCost = (supportMaterial / 1000) * material.costPerKg;
    const depreciation = settings.printerCost / settings.printerLifespan;
    const machineCost = printTime * depreciation;
    const electricityCost = (settings.powerConsumption / 1000) * printTime * settings.electricityRate;
    const laborCost = postProcessing * settings.laborRate;

    const baseCost = materialCost + supportCost + machineCost + electricityCost + laborCost;
    const failureCost = baseCost * (failureRisk - 1);
    const subtotal = baseCost + failureCost;

    const overheadCost = subtotal * (settings.overheadRate / 100);
    const profitCost = (subtotal + overheadCost) * (settings.profitMargin / 100);

    const totalPerUnit = subtotal + overheadCost + profitCost;
    const grandTotal = totalPerUnit * quantity;

    // Update display
    document.getElementById('materialCost').textContent = formatCurrency(materialCost);
    document.getElementById('supportCost').textContent = formatCurrency(supportCost);
    document.getElementById('machineCost').textContent = formatCurrency(machineCost);
    document.getElementById('electricityCost').textContent = formatCurrency(electricityCost);
    document.getElementById('laborCost').textContent = formatCurrency(laborCost);
    document.getElementById('failureCost').textContent = formatCurrency(failureCost);
    document.getElementById('subtotal').textContent = formatCurrency(subtotal);
    document.getElementById('overheadPercent').textContent = settings.overheadRate;
    document.getElementById('overheadCost').textContent = formatCurrency(overheadCost);
    document.getElementById('profitPercent').textContent = settings.profitMargin;
    document.getElementById('profitCost').textContent = formatCurrency(profitCost);
    document.getElementById('totalPerUnit').textContent = formatCurrency(totalPerUnit);
    document.getElementById('quantityDisplay').textContent = quantity;
    document.getElementById('grandTotal').textContent = formatCurrency(grandTotal);
}

function formatCurrency(value) {
    return settings.currency + value.toFixed(2);
}

function saveQuote() {
    const jobName = document.getElementById('jobName').value || 'Unnamed Job';
    const materialId = parseInt(document.getElementById('materialSelect').value);
    const material = materials.find(m => m.id === materialId);
    const quantity = parseInt(document.getElementById('quantity').value) || 1;
    const grandTotal = parseFloat(document.getElementById('grandTotal').textContent.replace(settings.currency, ''));

    const quote = {
        id: Date.now(),
        jobName,
        material: material ? material.name : 'Unknown',
        filamentUsed: parseFloat(document.getElementById('filamentUsed').value) || 0,
        printTime: parseFloat(document.getElementById('printTime').value) || 0,
        quantity,
        totalPrice: grandTotal,
        date: new Date().toISOString()
    };

    history.unshift(quote);
    saveHistory();
    renderHistory();
    alert('Quote saved successfully!');
}

function resetCalculator() {
    document.getElementById('jobName').value = '';
    document.getElementById('filamentUsed').value = 0;
    document.getElementById('printTime').value = 0;
    document.getElementById('supportMaterial').value = 0;
    document.getElementById('failureRisk').value = '1.10';
    document.getElementById('postProcessing').value = 0;
    document.getElementById('quantity').value = 1;
    updateCalculation();
}

// Materials Management
function initMaterials() {
    renderMaterials();

    document.getElementById('addMaterial').addEventListener('click', () => {
        editingMaterialId = null;
        document.getElementById('modalTitle').textContent = 'Add Material';
        document.getElementById('matName').value = '';
        document.getElementById('matType').value = 'PLA';
        document.getElementById('matCost').value = 25;
        document.getElementById('matDensity').value = 1.24;
        document.getElementById('matColor').value = '';
        document.getElementById('materialModal').classList.remove('hidden');
    });

    document.getElementById('saveMaterial').addEventListener('click', saveMaterial);
    document.getElementById('cancelMaterial').addEventListener('click', () => {
        document.getElementById('materialModal').classList.add('hidden');
    });

    // Close modal on outside click
    document.getElementById('materialModal').addEventListener('click', (e) => {
        if (e.target.id === 'materialModal') {
            document.getElementById('materialModal').classList.add('hidden');
        }
    });
}

function renderMaterials() {
    const list = document.getElementById('materialsList');

    if (materials.length === 0) {
        list.innerHTML = '<div class="empty-state">No materials added yet.</div>';
        return;
    }

    list.innerHTML = materials.map(m => `
        <div class="material-item" data-id="${m.id}">
            <div class="material-info">
                <h4>${m.name}</h4>
                <p>${m.type} | ${settings.currency}${m.costPerKg}/kg | Density: ${m.density} g/cm³ | ${m.color}</p>
            </div>
            <div class="material-actions">
                <button class="btn-icon edit" onclick="editMaterial(${m.id})">✏️</button>
                <button class="btn-icon delete" onclick="deleteMaterial(${m.id})">🗑️</button>
            </div>
        </div>
    `).join('');
}

function editMaterial(id) {
    const material = materials.find(m => m.id === id);
    if (!material) return;

    editingMaterialId = id;
    document.getElementById('modalTitle').textContent = 'Edit Material';
    document.getElementById('matName').value = material.name;
    document.getElementById('matType').value = material.type;
    document.getElementById('matCost').value = material.costPerKg;
    document.getElementById('matDensity').value = material.density;
    document.getElementById('matColor').value = material.color;
    document.getElementById('materialModal').classList.remove('hidden');
}

function saveMaterial() {
    const name = document.getElementById('matName').value.trim();
    const type = document.getElementById('matType').value;
    const costPerKg = parseFloat(document.getElementById('matCost').value);
    const density = parseFloat(document.getElementById('matDensity').value);
    const color = document.getElementById('matColor').value.trim() || 'Various';

    if (!name) {
        alert('Please enter a material name.');
        return;
    }

    if (editingMaterialId) {
        const index = materials.findIndex(m => m.id === editingMaterialId);
        if (index !== -1) {
            materials[index] = { ...materials[index], name, type, costPerKg, density, color };
        }
    } else {
        const newId = Math.max(0, ...materials.map(m => m.id)) + 1;
        materials.push({ id: newId, name, type, costPerKg, density, color });
    }

    saveMaterials();
    renderMaterials();
    populateMaterialSelect();
    document.getElementById('materialModal').classList.add('hidden');
}

function deleteMaterial(id) {
    if (!confirm('Are you sure you want to delete this material?')) return;

    materials = materials.filter(m => m.id !== id);
    saveMaterials();
    renderMaterials();
    populateMaterialSelect();
}

// Settings
function initSettings() {
    // Load settings into form
    document.getElementById('printerName').value = settings.printerName;
    document.getElementById('printerCost').value = settings.printerCost;
    document.getElementById('printerLifespan').value = settings.printerLifespan;
    document.getElementById('powerConsumption').value = settings.powerConsumption;
    document.getElementById('electricityRate').value = settings.electricityRate;
    document.getElementById('laborRate').value = settings.laborRate;
    document.getElementById('overheadRate').value = settings.overheadRate;
    document.getElementById('profitMargin').value = settings.profitMargin;
    document.getElementById('currency').value = settings.currency;

    document.getElementById('saveSettings').addEventListener('click', saveSettingsForm);
    document.getElementById('resetSettings').addEventListener('click', resetSettingsForm);
    document.getElementById('exportData').addEventListener('click', exportAllData);
    document.getElementById('importData').addEventListener('click', () => {
        document.getElementById('importFile').click();
    });
    document.getElementById('importFile').addEventListener('change', importData);
}

function saveSettingsForm() {
    settings.printerName = document.getElementById('printerName').value;
    settings.printerCost = parseFloat(document.getElementById('printerCost').value);
    settings.printerLifespan = parseFloat(document.getElementById('printerLifespan').value);
    settings.powerConsumption = parseFloat(document.getElementById('powerConsumption').value);
    settings.electricityRate = parseFloat(document.getElementById('electricityRate').value);
    settings.laborRate = parseFloat(document.getElementById('laborRate').value);
    settings.overheadRate = parseFloat(document.getElementById('overheadRate').value);
    settings.profitMargin = parseFloat(document.getElementById('profitMargin').value);
    settings.currency = document.getElementById('currency').value || '$';

    saveSettings();
    updateCalculation();
    populateMaterialSelect();
    renderMaterials();
    renderHistory();
    alert('Settings saved successfully!');
}

function resetSettingsForm() {
    if (!confirm('Reset all settings to defaults?')) return;

    settings = { ...defaultSettings };
    saveSettings();
    initSettings();
    updateCalculation();
    alert('Settings reset to defaults.');
}

function exportAllData() {
    const data = {
        materials,
        settings,
        history,
        exportDate: new Date().toISOString()
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `3dprintcosts-backup-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
}

function importData(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
        try {
            const data = JSON.parse(event.target.result);

            if (data.materials) materials = data.materials;
            if (data.settings) settings = { ...defaultSettings, ...data.settings };
            if (data.history) history = data.history;

            saveData();
            loadData();
            initSettings();
            renderMaterials();
            populateMaterialSelect();
            renderHistory();
            updateCalculation();

            alert('Data imported successfully!');
        } catch (err) {
            alert('Error importing data. Please check the file format.');
        }
    };
    reader.readAsText(file);
    e.target.value = '';
}

// History
function initHistory() {
    renderHistory();
    document.getElementById('clearHistory').addEventListener('click', clearHistory);
}

function renderHistory() {
    const list = document.getElementById('historyList');

    if (history.length === 0) {
        list.innerHTML = '<div class="empty-state">No quotes saved yet.</div>';
        return;
    }

    list.innerHTML = history.map(h => {
        const date = new Date(h.date).toLocaleDateString();
        return `
            <div class="history-item" data-id="${h.id}">
                <div class="history-info">
                    <h4>${h.jobName}</h4>
                    <p>${h.material} | ${h.filamentUsed}g | ${h.printTime}hrs | Qty: ${h.quantity} | ${date}</p>
                </div>
                <div class="history-actions">
                    <span class="history-price">${settings.currency}${h.totalPrice.toFixed(2)}</span>
                    <button class="btn-icon delete" onclick="deleteHistoryItem(${h.id})">🗑️</button>
                </div>
            </div>
        `;
    }).join('');
}

function deleteHistoryItem(id) {
    if (!confirm('Delete this quote from history?')) return;
    history = history.filter(h => h.id !== id);
    saveHistory();
    renderHistory();
}

function clearHistory() {
    if (!confirm('Clear all quote history? This cannot be undone.')) return;
    history = [];
    saveHistory();
    renderHistory();
}

// Make functions globally available for onclick handlers
window.editMaterial = editMaterial;
window.deleteMaterial = deleteMaterial;
window.deleteHistoryItem = deleteHistoryItem;
