/**
 * STL and 3MF File Parser for Print Cost Pro+
 * Extracts volume, dimensions, surface area, and triangle count from 3D model files
 */

class ModelParser {
    constructor() {
        this.modelData = null;
    }

    /**
     * Parse a file (STL or 3MF)
     * @param {File} file - The file to parse
     * @returns {Promise<Object>} - Parsed model data
     */
    async parseFile(file) {
        const extension = file.name.split('.').pop().toLowerCase();

        if (extension === 'stl') {
            return this.parseSTL(file);
        } else if (extension === '3mf') {
            return this.parse3MF(file);
        } else {
            throw new Error('Unsupported file format. Please use STL or 3MF files.');
        }
    }

    /**
     * Parse an STL file (binary or ASCII)
     */
    async parseSTL(file) {
        const arrayBuffer = await file.arrayBuffer();
        const dataView = new DataView(arrayBuffer);

        // Check if binary or ASCII
        const isBinary = this.isSTLBinary(arrayBuffer);

        let triangles;
        if (isBinary) {
            triangles = this.parseSTLBinary(dataView);
        } else {
            const text = new TextDecoder().decode(arrayBuffer);
            triangles = this.parseSTLASCII(text);
        }

        return this.calculateMeshProperties(triangles, file.name);
    }

    /**
     * Check if STL is binary format
     */
    isSTLBinary(arrayBuffer) {
        // Binary STL has 80 byte header + 4 byte triangle count
        // Then each triangle is 50 bytes
        if (arrayBuffer.byteLength < 84) return false;

        const dataView = new DataView(arrayBuffer);
        const triangleCount = dataView.getUint32(80, true);
        const expectedSize = 84 + (triangleCount * 50);

        // Check if file size matches binary format
        if (Math.abs(arrayBuffer.byteLength - expectedSize) < 10) {
            return true;
        }

        // Check for "solid" keyword at start (ASCII indicator)
        const header = new TextDecoder().decode(arrayBuffer.slice(0, 5));
        return header.toLowerCase() !== 'solid';
    }

    /**
     * Parse binary STL format
     */
    parseSTLBinary(dataView) {
        const triangleCount = dataView.getUint32(80, true);
        const triangles = [];

        let offset = 84; // Skip header (80) and count (4)

        for (let i = 0; i < triangleCount; i++) {
            // Normal vector (12 bytes) - skip
            offset += 12;

            // Vertices (3 vertices × 3 floats × 4 bytes = 36 bytes)
            const v1 = {
                x: dataView.getFloat32(offset, true),
                y: dataView.getFloat32(offset + 4, true),
                z: dataView.getFloat32(offset + 8, true)
            };
            offset += 12;

            const v2 = {
                x: dataView.getFloat32(offset, true),
                y: dataView.getFloat32(offset + 4, true),
                z: dataView.getFloat32(offset + 8, true)
            };
            offset += 12;

            const v3 = {
                x: dataView.getFloat32(offset, true),
                y: dataView.getFloat32(offset + 4, true),
                z: dataView.getFloat32(offset + 8, true)
            };
            offset += 12;

            // Attribute byte count (2 bytes) - skip
            offset += 2;

            triangles.push({ v1, v2, v3 });
        }

        return triangles;
    }

    /**
     * Parse ASCII STL format
     */
    parseSTLASCII(text) {
        const triangles = [];
        const vertexRegex = /vertex\s+([-\d.e+]+)\s+([-\d.e+]+)\s+([-\d.e+]+)/gi;

        let match;
        let vertices = [];

        while ((match = vertexRegex.exec(text)) !== null) {
            vertices.push({
                x: parseFloat(match[1]),
                y: parseFloat(match[2]),
                z: parseFloat(match[3])
            });

            if (vertices.length === 3) {
                triangles.push({
                    v1: vertices[0],
                    v2: vertices[1],
                    v3: vertices[2]
                });
                vertices = [];
            }
        }

        return triangles;
    }

    /**
     * Parse 3MF file (ZIP archive with XML)
     */
    async parse3MF(file) {
        // Load JSZip dynamically if not available
        if (typeof JSZip === 'undefined') {
            await this.loadJSZip();
        }

        const arrayBuffer = await file.arrayBuffer();
        const zip = await JSZip.loadAsync(arrayBuffer);

        // Find the model file (usually 3D/3dmodel.model)
        let modelXML = null;

        for (const filename of Object.keys(zip.files)) {
            if (filename.endsWith('.model')) {
                modelXML = await zip.files[filename].async('string');
                break;
            }
        }

        if (!modelXML) {
            throw new Error('No model file found in 3MF archive');
        }

        const triangles = this.parse3MFModel(modelXML);
        return this.calculateMeshProperties(triangles, file.name);
    }

    /**
     * Load JSZip library dynamically
     */
    async loadJSZip() {
        return new Promise((resolve, reject) => {
            if (typeof JSZip !== 'undefined') {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js';
            script.onload = resolve;
            script.onerror = () => reject(new Error('Failed to load JSZip library'));
            document.head.appendChild(script);
        });
    }

    /**
     * Parse 3MF model XML
     */
    parse3MFModel(xml) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(xml, 'text/xml');

        const triangles = [];

        // Get all mesh elements
        const meshes = doc.querySelectorAll('mesh');

        meshes.forEach(mesh => {
            const vertices = [];
            const vertexElements = mesh.querySelectorAll('vertices vertex');

            vertexElements.forEach(v => {
                vertices.push({
                    x: parseFloat(v.getAttribute('x')),
                    y: parseFloat(v.getAttribute('y')),
                    z: parseFloat(v.getAttribute('z'))
                });
            });

            const triangleElements = mesh.querySelectorAll('triangles triangle');

            triangleElements.forEach(t => {
                const v1Index = parseInt(t.getAttribute('v1'));
                const v2Index = parseInt(t.getAttribute('v2'));
                const v3Index = parseInt(t.getAttribute('v3'));

                if (vertices[v1Index] && vertices[v2Index] && vertices[v3Index]) {
                    triangles.push({
                        v1: vertices[v1Index],
                        v2: vertices[v2Index],
                        v3: vertices[v3Index]
                    });
                }
            });
        });

        return triangles;
    }

    /**
     * Calculate mesh properties from triangles
     */
    calculateMeshProperties(triangles, filename) {
        if (triangles.length === 0) {
            throw new Error('No triangles found in model');
        }

        let volume = 0;
        let surfaceArea = 0;
        let minX = Infinity, minY = Infinity, minZ = Infinity;
        let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;

        triangles.forEach(tri => {
            // Update bounding box
            [tri.v1, tri.v2, tri.v3].forEach(v => {
                minX = Math.min(minX, v.x);
                minY = Math.min(minY, v.y);
                minZ = Math.min(minZ, v.z);
                maxX = Math.max(maxX, v.x);
                maxY = Math.max(maxY, v.y);
                maxZ = Math.max(maxZ, v.z);
            });

            // Calculate signed volume of tetrahedron formed with origin
            // Using the formula: V = (1/6) * |v1 · (v2 × v3)|
            volume += this.signedVolumeOfTriangle(tri.v1, tri.v2, tri.v3);

            // Calculate surface area of triangle
            surfaceArea += this.triangleArea(tri.v1, tri.v2, tri.v3);
        });

        // Take absolute value of volume (orientation might be inverted)
        volume = Math.abs(volume);

        // Dimensions in mm (assuming STL units are mm)
        const dimensions = {
            x: maxX - minX,
            y: maxY - minY,
            z: maxZ - minZ
        };

        // Convert units (STL is typically in mm)
        // Volume: mm³ to cm³ (divide by 1000)
        // Surface area: mm² to cm² (divide by 100)
        const volumeCm3 = volume / 1000;
        const surfaceAreaCm2 = surfaceArea / 100;

        this.modelData = {
            filename,
            triangleCount: triangles.length,
            volume: volumeCm3,
            volumeMm3: volume,
            surfaceArea: surfaceAreaCm2,
            surfaceAreaMm2: surfaceArea,
            dimensions: {
                x: dimensions.x,
                y: dimensions.y,
                z: dimensions.z
            },
            boundingBox: {
                min: { x: minX, y: minY, z: minZ },
                max: { x: maxX, y: maxY, z: maxZ }
            }
        };

        return this.modelData;
    }

    /**
     * Calculate signed volume of tetrahedron with one vertex at origin
     */
    signedVolumeOfTriangle(v1, v2, v3) {
        return (
            v1.x * (v2.y * v3.z - v3.y * v2.z) -
            v1.y * (v2.x * v3.z - v3.x * v2.z) +
            v1.z * (v2.x * v3.y - v3.x * v2.y)
        ) / 6.0;
    }

    /**
     * Calculate area of a triangle
     */
    triangleArea(v1, v2, v3) {
        // Cross product of two edges
        const edge1 = {
            x: v2.x - v1.x,
            y: v2.y - v1.y,
            z: v2.z - v1.z
        };

        const edge2 = {
            x: v3.x - v1.x,
            y: v3.y - v1.y,
            z: v3.z - v1.z
        };

        const cross = {
            x: edge1.y * edge2.z - edge1.z * edge2.y,
            y: edge1.z * edge2.x - edge1.x * edge2.z,
            z: edge1.x * edge2.y - edge1.y * edge2.x
        };

        // Area is half the magnitude of the cross product
        return 0.5 * Math.sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z);
    }

    /**
     * Estimate material usage based on print settings
     * @param {Object} settings - Print settings (infill, walls, etc.)
     * @param {number} density - Material density in g/cm³
     * @returns {Object} - Estimated material usage
     */
    estimateMaterialUsage(settings, density = 1.24) {
        if (!this.modelData) {
            throw new Error('No model loaded. Parse a file first.');
        }

        const {
            infillPercent = 20,
            wallCount = 3,
            topBottomLayers = 4,
            lineWidth = 0.4,
            layerHeight = 0.2
        } = settings;

        const volume = this.modelData.volumeMm3;
        const surfaceArea = this.modelData.surfaceAreaMm2;
        const dimensions = this.modelData.dimensions;

        // Estimate shell volume (walls)
        // Simplified: wall thickness = wallCount * lineWidth
        const wallThickness = wallCount * lineWidth;
        const shellVolume = surfaceArea * wallThickness;

        // Estimate top/bottom volume
        // Simplified: assuming flat top/bottom with area proportional to XY dimensions
        const topBottomThickness = topBottomLayers * layerHeight;
        const estimatedTopBottomArea = dimensions.x * dimensions.y * 0.7; // 70% fill estimate
        const topBottomVolume = estimatedTopBottomArea * topBottomThickness * 2; // top and bottom

        // Estimate infill volume
        // Internal volume minus shell and top/bottom
        const internalVolume = Math.max(0, volume - shellVolume - topBottomVolume);
        const infillVolume = internalVolume * (infillPercent / 100);

        // Total plastic volume
        const totalVolume = shellVolume + topBottomVolume + infillVolume;

        // Convert to cm³ and calculate weight
        const totalVolumeCm3 = totalVolume / 1000;
        const weightGrams = totalVolumeCm3 * density;

        // Estimate print time based on volume and complexity
        // Rough estimate: ~10-15 cm³/hour for typical FDM printing
        const printSpeedFactor = 12; // cm³ per hour (conservative)
        const estimatedHours = totalVolumeCm3 / printSpeedFactor;

        // Adjust for model height (more layers = more time)
        const layerCount = dimensions.z / layerHeight;
        const layerTimeAdjustment = layerCount * 0.01; // ~0.6 seconds per layer for moves
        const adjustedHours = estimatedHours + (layerTimeAdjustment / 60);

        return {
            totalVolumeMm3: totalVolume,
            totalVolumeCm3: totalVolumeCm3,
            weightGrams: weightGrams,
            estimatedPrintTimeHours: adjustedHours,
            breakdown: {
                shellVolume: shellVolume / 1000, // cm³
                topBottomVolume: topBottomVolume / 1000, // cm³
                infillVolume: infillVolume / 1000, // cm³
                layerCount: Math.ceil(layerCount)
            }
        };
    }

    /**
     * Estimate support material
     * @param {number} supportPercent - Percentage of model that needs support
     * @param {number} density - Material density
     * @returns {Object} - Support material estimate
     */
    estimateSupportMaterial(supportPercent = 0, density = 1.24) {
        if (!this.modelData || supportPercent === 0) {
            return {
                volumeCm3: 0,
                weightGrams: 0
            };
        }

        // Estimate support as a percentage of model volume
        // Support is typically less dense than the model
        const supportVolumeCm3 = this.modelData.volume * (supportPercent / 100) * 0.15; // 15% density for supports
        const supportWeight = supportVolumeCm3 * density;

        return {
            volumeCm3: supportVolumeCm3,
            weightGrams: supportWeight
        };
    }
}

// Export for use
window.ModelParser = ModelParser;
