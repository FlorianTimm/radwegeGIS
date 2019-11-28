import 'ol/ol.css';
import { register } from 'ol/proj/proj4';
import proj4 from 'proj4';

import "./import_jquery.js";
import Karte from './Karte';
import ToolSwitcher from './ToolSwitcher';

proj4.defs("EPSG:25832", "+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs");
register(proj4);
let map = new Karte();

new ToolSwitcher(map);