import { Draw as DrawInteraction, Snap as SnapInteraction, Select, Snap } from 'ol/interaction.js';
import { Map } from 'ol';
import { Layer } from 'ol/layer';
import GeometryType from 'ol/geom/GeometryType';
import { SelectEvent } from 'ol/interaction/Select';

export default class GeoPart {
    private __map: Map;
    private __layer: Layer;
    private __selection: Select;
    private __draw: DrawInteraction;
    private __snap: SnapInteraction;
    /**
     * @param {ol.Map} map Karte
     * @param {ol.layer.Vector} layer Layer mit Radwege-Geometrien
     * @param {ol.interaction.Select} selection Auswahl-Tool
     */
    constructor(map: Map, layer: Layer, selection: Select) {
        this.__map = map;
        this.__layer = layer;
        this.__selection = selection;

        this.__draw = new DrawInteraction({
            type: GeometryType.POINT
        });

        this.__snap = new SnapInteraction({
            pixelTolerance: 30
        });
    }

    start() {
        this.__selection.setActive(true);
        this.__selection.on("select", this.__select.bind(this));
    }

    stop() {
        this.__selection.setActive(false)

    }

    /**
     * 
     * @param {ol.interaction.Select.Event} event 
     */
    __select(event: SelectEvent) {
        console.log(event.selected);
    }
}