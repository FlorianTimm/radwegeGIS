import { Tool } from "../ToolSwitcher";
import { Select, Draw } from "ol/interaction";
import GeometryType from "ol/geom/GeometryType";
import { DrawEvent } from "ol/interaction/Draw";
import { Map } from "ol";
import Karte from "../Karte";
import VectorLayer from "ol/layer/Vector";
import LineString from "ol/geom/LineString";

export default class AddTool implements Tool {
    private select: Select;
    private draw: Draw;
    constructor(select: Select, map: Karte, vectorLayer: VectorLayer) {
        this.select = select;

        this.draw = new Draw({
            type: GeometryType.LINE_STRING,
            source: vectorLayer.getSource()
        })

        map.addInteraction(this.draw);

        this.draw.on("drawend", function (this: AddTool, evt: DrawEvent) {
            this.select.getFeatures().clear();
            this.select.getFeatures().push(evt.feature);
            console.log((evt.feature.getGeometry() as LineString).getCoordinates())
        }.bind(this))
    }

    public start() {
        this.draw.setActive(true)
    }

    public stop() {
        this.draw.setActive(false)
    }


}