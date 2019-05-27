import { Draw as DrawInteraction, Snap as SnapInteraction } from 'ol/interaction.js';

class GeoPart {
    /**
     * @param {ol.Map} map Karte
     * @param {ol.layer.Vector} layer Layer mit Radwege-Geometrien
     * @param {ol.interaction.Select} selection Auswahl-Tool
     */
    constructor(map, layer, selection) {
        this.__map = map;
        this.__layer = layer;
        this.__selection = selection;

        this.__draw = new DrawInteraction({
            type: 'Point'
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
    __select(event) {
        console.log(event.selected);
    }
}

module.exports = GeoPart;