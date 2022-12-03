define(["require", "exports"], function (require, exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", { value: true });
    const eventBus = require('std:eventBus');
    const template = {
        properties: {
            'TNotify.$DoneIcon'() { return this.Done ? 'dot-blue' : 'circle'; }
        },
        commands: {
            clickNotify,
            deleteNotify
        }
    };
    exports.default = template;
    async function clickNotify(note) {
        const ctrl = this.$ctrl;
        await ctrl.$invoke('done', { Id: note.Id });
        if (note.Done) {
            note.Done = true;
            eventBus.$emit('app.notify.dec');
        }
        if (note.Link && note.LinkUrl)
            ctrl.$showDialog(note.LinkUrl, { Id: note.Link });
    }
    function deleteNotify(note) {
        alert(note.Id);
    }
});
