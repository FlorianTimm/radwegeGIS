import Karte from "./Karte";
import InfoTool from "./InfoTool";
import Control from "ol/control/Control";
import "../css/ToolSwitcher.css";
import EditTool from "./Tools/EditTool";

export default class ToolSwitcher extends Control {
    private buttons: { [text: string]: Tool };
    private div: HTMLDivElement;

    constructor(map: Karte) {
        let div = document.createElement("div");
        div.className = 'rotate-north ol-unselectable ol-control';
        div.id = "ToolSwitcher"
        super({ element: div, target: document.getElementById('map') ?? undefined });
        this.div = div
        document.body.append(this.div);

        this.buttons = {
            "Info": new InfoTool(map.getSelect()),
            "Bearbeiten": new EditTool(map.getSelect(), map),
        }

        for (let b in this.buttons) {
            let button = document.createElement("button");
            button.innerText = b;
            button.addEventListener("click", function (this: ToolSwitcher, clickEvent: MouseEvent) {
                $(this.div).children("button").removeClass("active")
                for (let b2 in this.buttons) {
                    this.buttons[b2].stop();
                }
                this.buttons[b].start();
                if (clickEvent.target)
                    $(clickEvent.target).addClass("active")
            }.bind(this))
            this.div.appendChild(button)
        }

        $(this.div).children("button").first().click();
    }
}

export interface Tool {
    start(): void;
    stop(): void;
}