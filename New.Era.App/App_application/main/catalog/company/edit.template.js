define(["require", "exports"], function (require, exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", { value: true });
    const template = {
        properties: {
            'TCompany.$Id'() { return this.Id || '@[NewItem]'; }
        },
        validators: {
            'Company.Name': '@[Error.Required]'
        }
    };
    exports.default = template;
});
