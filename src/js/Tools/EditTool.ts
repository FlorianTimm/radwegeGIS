import Select, { SelectEvent } from 'ol/interaction/Select';
import InfoTool from '../InfoTool';
import { Modify } from 'ol/interaction';
import { never } from 'ol/events/condition';
import { ModifyEvent } from 'ol/interaction/Modify';
import Karte from '../Karte';

export default class EditTool extends InfoTool {
    private modify: Modify;

    constructor(select: Select, map: Karte) {
        super(select);

        this.modify = new Modify({
            features: select.getFeatures(),
            deleteCondition: never,
        })
        map.addInteraction(this.modify)

        this.modify.on("modifyend", function (evt: ModifyEvent) { console.log(evt) })
    }

    public start() {
        super.start();
        this.modify.setActive(true)
    }

    public stop() {
        super.stop();
        this.modify.setActive(false)
    }
}

