﻿
// order.index

declare const d3: any;

const base: Template = require("document/_common/index.module");
const bind: Template = require("document/_common/bind.module");
const utils: Utils = require("std:utils");

const template: Template = {
	properties: {
		'TDocument.$Warehouse'() { return this.WhFrom.Id ? this.WhFrom.Name : this.WhTo.Name; },
		'TDocument.$Bind': bind.properties['TDocument.$Bind']
	}
};

export default utils.mergeTemplate(base, template);
