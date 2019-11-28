import Select, { SelectEvent } from 'ol/interaction/Select';
import { Tool } from "./ToolSwitcher";
import { EventsKey } from 'ol/events';
import { unByKey } from 'ol/Observable';

export default class InfoTool implements Tool {
    protected infoField: HTMLDivElement;
    protected select: Select;
    protected selectEventKey: EventsKey | undefined;

    constructor(select: Select) {
        this.select = select;
        this.infoField = document.createElement("div");
        this.infoField.id = "infoField"

        $(this.infoField).hide();
        document.body.appendChild(this.infoField);
    }

    protected onSelect(evt: SelectEvent) {
        if (evt.selected.length <= 0) {
            this.hideInfoField();
            return;
        }
        this.infoField.innerHTML = "";
        for (let feat of evt.selected) {
            for (let attr in feat.getProperties()) {
                if (attr == "geometry") continue;
                this.infoField.innerHTML += "<span class='label'>" + attr + ":</span>";
                this.infoField.innerHTML += "<span class='value'>" + feat.get(attr) + "</span>"
                $(this.infoField).show("fast");
            }
        }
    }

    protected hideInfoField() {
        $(this.infoField).hide("fast", function (this: InfoTool) {
            this.infoField.innerHTML = "";
        }.bind(this))
    }

    public start() {
        this.selectEventKey = this.select.on("select", this.onSelect.bind(this))
        console.log("start", this)
    }

    public stop() {
        if (this.selectEventKey)
            unByKey(this.selectEventKey)
        this.hideInfoField();
        console.log("stop", this)
    }

}

