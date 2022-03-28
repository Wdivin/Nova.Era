﻿
import { TRoot, TDocument, TDocuments, TForm } from './index';

const template: Template = {
	options: {
		persistSelect:['Documents']
	},
	properties: {
	},
	commands: {
		create,
		editSelected,
		edit
	}
};

export default template;

async function create(this: TRoot, form: TForm) {
	const ctrl = this.$ctrl;
	let url = `/document/${form.Id}/edit`
	let docsrc = await ctrl.$showDialog(url, null, { Form: form.Id });
	let doc = this.Documents.$append(docsrc);
	doc.$select();
}

function editSelected(docs: TDocuments) {
	let doc = docs.$selected;
	if (!doc) return;
	edit.call(this, doc);
}

async function edit(this: TRoot, doc: TDocument) {
	if (!doc) return;
	const ctrl = this.$ctrl;
	let url = `/document/${doc.Operation.Form}/edit`
	let rdoc = await ctrl.$showDialog(url, { Id: doc.Id });
	doc.$merge(rdoc);
}