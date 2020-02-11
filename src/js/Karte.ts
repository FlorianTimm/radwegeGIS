import { Map, View, Feature } from 'ol';
import { Tile as TileLayer, Vector as VectorLayer } from 'ol/layer';
import TileWMS from 'ol/source/TileWMS';
import { fromLonLat } from 'ol/proj.js';
import VectorSource from 'ol/source/Vector';
import GeoJSON from 'ol/format/GeoJSON';
import { bbox as bboxStrategy, all as allStrategy } from 'ol/loadingstrategy';
import { Stroke, Style } from 'ol/style';
import { never as neverCondition } from 'ol/events/condition'
import { Select } from 'ol/interaction';

export default class Karte extends Map {
    private dop: TileLayer;
    private geobasis: TileLayer;
    public vectorLayer: VectorLayer;
    private select: Select;

    constructor() {
        super({
            target: document.getElementById('map') ?? undefined,
            view: new View({
                projection: 'EPSG:25832',
                center: fromLonLat([9.977, 53.452], 'EPSG:25832'),
                zoom: 17
            })
        });

        // Geobasis
        this.geobasis = this.createGeobasis();
        // DOP
        this.dop = this.createDop();
        this.createAutoLayerSwitch()
        
        // Radwege-Layer
        this.vectorLayer = this.createRadwegeLayer()

        this.select = new Select({
            layers: [this.vectorLayer],
            hitTolerance: 10,
            toggleCondition: neverCondition
        });
        this.addInteraction(this.select);
    }

    public getSelect(): Select {
        return this.select;
    }

    private createDop() {
        let dop = new TileLayer({
            opacity: 0.8,
            visible: false,
            source: new TileWMS({
                url: 'https://geodienste.hamburg.de/HH_WMS_DOP_hochaufloesend?',
                params: { 'LAYERS': 'dop_hochaufloesend', 'TILED': true },
                serverType: 'geoserver',
                // Countries have transparency, so do not fade tiles:
                transition: 0
            })
        });
        this.addLayer(dop);
        return dop;
    }

    private createGeobasis() {
        let gb = new TileLayer({
            opacity: 0.5,
            visible: true,
            source: new TileWMS({
                url: 'https://geodienste.hamburg.de/HH_WMS_Geobasiskarten_GB?',
                params: { 'LAYERS': '2,6,10,14,18,22,26', 'TILED': true },
                serverType: 'geoserver',
                // Countries have transparency, so do not fade tiles:
                transition: 0
            })
        });
        this.addLayer(gb);
        return gb;
    }

    private createAutoLayerSwitch() {
        // Switch between background layers
        this.getView().on('change:resolution', function (this: Karte, event: Event) {
            let zoom = this.getView().getZoom();
            if (zoom && zoom > 16) {
                this.dop.setVisible(true);
                this.geobasis.setVisible(false);
                this.dop.setOpacity(0.6);
            } else if (zoom && zoom == 16) {
                this.dop.setVisible(true);
                this.geobasis.setVisible(true);
                this.dop.setOpacity(0.3);
            } else {
                this.dop.setVisible(false);
                this.geobasis.setVisible(true);
            }
        }.bind(this));
    }

    private createRadwegeLayer() {
        let vectorSource = new VectorSource({
            format: new GeoJSON(),
            url: 'http://gv-srv-w00118:8080/radwegeGIS/jsp/geo.jsp',
            strategy: allStrategy
        });

        let rwl = new VectorLayer({
            source: vectorSource,
            style: function (feat) {
                let color = 'rgb(100,100,100)';
                switch (feat.get("radweg_art")) {
                    case "Straße <= 30 km/h":
                        color = 'rgb(255,130,0)';
                        break;
                    case "Straße > 30km/h":
                        color = 'rgb(255,0,255)';
                        break;
                    case "Fuß-/Radweg":
                    case "Fuß-/Radweg, unbeschildert":
                        color = 'rgb(255,0,255)';
                        break;
                    case "Getrennter Fuß-/Radweg":
                    case "Getrennter Fuß-/Radweg, unbeschildert":
                    case "Getrennter Fuß-/Radweg, benutzungspflichtig":
                        color = 'rgb(120,0,255)';
                        break;
                    case "Radfurt ohne LSA":
                        color = 'rgb(255,120,0)';
                        break;
                    case "Radfurt mit LSA":
                        color = 'rgb(0,120,0)';
                        break;
                    case "Radweg, benutzungspflichtig":
                        color = 'rgb(20,20,240)';
                        break;
                    case "Radweg":
                        color = 'rgb(20,130,240)';
                        break;
                }
                return new Style({
                    stroke: new Stroke({
                        color: color,
                        width: 2
                    })
                });
            }
        });
        this.addLayer(rwl);
        return rwl;
    }
}