import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["shortDescription", "fullDescription", "toggleLink"]

    connect() {
        this.showMoreText = "Show More";
        this.showLessText = "Show Less";
        this.checkDescriptionLength();
        this.updateLinkText();
    }

    toggle() {
        const displayStyle = this.fullDescriptionTarget.style.display;
        if (displayStyle === "none" || displayStyle === "") {
            this.fullDescriptionTarget.style.display = "inline";
            this.shortDescriptionTarget.style.display = "none";
        } else {
            this.fullDescriptionTarget.style.display = "none";
            this.shortDescriptionTarget.style.display = "inline";
        }
        this.updateLinkText();
    }

    updateLinkText() {
        const link = this.toggleLinkTarget;
        link.innerText = this.fullDescriptionTarget.style.display === "none" ? this.showMoreText : this.showLessText;
    }

    checkDescriptionLength() {
        // Assuming the fullDescriptionTarget is the complete text and shortDescriptionTarget is the truncated text
        if (this.fullDescriptionTarget.textContent.length <= 100) {
            this.toggleLinkTarget.style.display = "none"; // Hide the toggle link if description is short
        } else {
            this.toggleLinkTarget.style.display = ""; // Show the toggle link if description is long
        }
    }
}
