﻿
const base: Template = require("document/_common/index.module");

const template: Template = Object.assign(base, {
	properties: Object.assign(base.properties, {
		'TDocument.$Warehouse'() { return this.WhFrom.Id ? this.WhFrom.Name : this.WhTo.Name; }
	})
});

export default template;

