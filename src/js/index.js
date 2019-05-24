import 'ol/ol.css';
import { Map, View } from 'ol';
import { Tile as TileLayer, Vector as VectorLayer } from 'ol/layer.js';
import TileWMS from 'ol/source/TileWMS.js';
import { fromLonLat } from 'ol/proj.js';
import VectorSource from 'ol/source/Vector.js';
import GeoJSON from 'ol/format/GeoJSON.js';
import { bbox as bboxStrategy, all as allStrategy } from 'ol/loadingstrategy.js';
import { Stroke, Style } from 'ol/style.js';
import { register } from 'ol/proj/proj4.js';
import proj4 from 'proj4';
import Select from 'ol/interaction/Select.js'

//proj4.defs("EPSG:31467", "+proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +ellps=bessel +towgs84=598.1,73.7,418.2,0.202,0.045,-2.455,6.7 +units=m +no_defs");
proj4.defs("EPSG:25832", "+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs");
register(proj4);

let geobasis = new TileLayer({
  title: "Geobasis GB",
  opacity: 0.5,
  visible: true,
  source: new TileWMS({
    url: 'https://geodienste.hamburg.de/HH_WMS_Kombi_DISK_GB?',
    params: { 'LAYERS': '6,10,18,26,2,14,22,30', 'TILED': true },
    serverType: 'geoserver',
    // Countries have transparency, so do not fade tiles:
    transition: 0
  })
});

let dop = new TileLayer({
  title: "DOP",
  opacity: 0.6,
  visible: false,
  source: new TileWMS({
    url: 'https://geodienste.hamburg.de/HH_WMS_DOP?',
    params: { 'LAYERS': '1', 'TILED': true },
    serverType: 'geoserver',
    // Countries have transparency, so do not fade tiles:
    transition: 0
  })
});

var vectorSource = new VectorSource({
  format: new GeoJSON(),
  url: 'http://gv-srv-w00118:8080/radwegeGIS/jsp/geo.jsp',
  strategy: allStrategy
});


var vector = new VectorLayer({
  source: vectorSource,
  style: new Style({
    stroke: new Stroke({
      color: 'rgba(0, 0, 255, 1.0)',
      width: 2
    })
  })
});

var map = new Map({
  layers: [geobasis, dop, vector],
  target: document.getElementById('map'),
  view: new View({
    projection: 'EPSG:25832',
    center: fromLonLat([10.0045, 53.57], 'EPSG:25832'),
    zoom: 12
  })
});

let select = new Select({
  layers: [vector],
  hitTolerance: 10,
  style: new Style({
    stroke: new Stroke({
      color: 'rgba(255, 50, 50, 1)',
      width: 3
    })
  })
});
map.addInteraction(select);

map.getView().on('change:resolution', function (event) {
  console.log(event);
  let zoom = event.target.getZoom();
  if (zoom > 16) {
    dop.setVisible(true);
    geobasis.setVisible(false);
    dop.setOpacity(0.6);
  } else if (zoom == 16) {
    dop.setVisible(true);
    geobasis.setVisible(true);
    dop.setOpacity(0.3);
  } else {
    dop.setVisible(false);
    geobasis.setVisible(true);
  }
})