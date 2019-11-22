import 'ol/ol.css';
import { Map, View } from 'ol';
import { Tile as TileLayer, Vector as VectorLayer } from 'ol/layer';
import TileWMS from 'ol/source/TileWMS';
import { fromLonLat } from 'ol/proj.js';
import VectorSource from 'ol/source/Vector';
import GeoJSON from 'ol/format/GeoJSON';
import { bbox as bboxStrategy, all as allStrategy } from 'ol/loadingstrategy';
import { Stroke, Style } from 'ol/style';
import { register } from 'ol/proj/proj4';
import proj4 from 'proj4';
import Select, { SelectEvent } from 'ol/interaction/Select';
//import GeoPart from './geoPart';
import { never as neverCondition } from 'ol/events/condition'

import "./import_jquery.js";

//proj4.defs("EPSG:31467", "+proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +ellps=bessel +towgs84=598.1,73.7,418.2,0.202,0.045,-2.455,6.7 +units=m +no_defs");
proj4.defs("EPSG:25832", "+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs");
register(proj4);

let geobasis = new TileLayer({
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

let dop = new TileLayer({
  opacity: 0.6,
  visible: false,
  source: new TileWMS({
    url: 'https://geodienste.hamburg.de/HH_WMS_DOP_hochaufloesend?',
    params: { 'LAYERS': 'DOP5', 'TILED': true },
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
  style: function (feat) {
    return new Style({
      stroke: new Stroke({
        color: get_color(feat),
        width: 2
      })
    })
  }
});

var map = new Map({
  layers: [geobasis, dop, vector],
  target: document.getElementById('map'),
  view: new View({
    projection: 'EPSG:25832',
    center: fromLonLat([9.977, 53.452], 'EPSG:25832'),
    zoom: 17
  })
});

let select = new Select({
  layers: [vector],
  hitTolerance: 10,
  toggleCondition: neverCondition
});
map.addInteraction(select);

map.getView().on('change:resolution', function (event) {
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

/*
let geoPart = new GeoPart(map, vector, select);
geoPart.start();*/

function get_color(feat) {
  switch (feat.get("radweg_art")) {
    case "Straße <= 30 km/h":
      return 'rgb(255,130,0)';
    case "Straße > 30km/h":
      return 'rgb(255,0,255)';
    case "Fuß-/Radweg":
    case "Fuß-/Radweg, unbeschildert":
      return 'rgb(255,0,255)';
    case "Getrennter Fuß-/Radweg":
    case "Getrennter Fuß-/Radweg, unbeschildert":
    case "Getrennter Fuß-/Radweg, benutzungspflichtig":
      return 'rgb(120,0,255)';
    case "Radfurt ohne LSA":
      return 'rgb(255,120,0)';
    case "Radfurt mit LSA":
      return 'rgb(0,120,0)';
    case "Radweg, benutzungspflichtig":
      return 'rgb(20,20,240)';
  }
  return 'rgb(100,100,100)'
}
let infoField = document.createElement("div");
infoField.id = "infoField"

$(infoField).hide();
document.body.appendChild(infoField);
select.on("select", function (evt: SelectEvent) {
  if (evt.selected.length <= 0) {
    $(infoField).hide("fast", function () {
      infoField.innerHTML = "";
    })
    return;
  }
  infoField.innerHTML = "";
  for (let feat of evt.selected) {
    for (let attr in feat.getProperties()) {
      if (attr == "geometry") continue;
      infoField.innerHTML += "<span class='label'>" + attr + ":</span>";
      infoField.innerHTML += "<span class='value'>" + feat.get(attr) + "</span>"
      $(infoField).show("fast");
    }
  }

})