/*

    Create <TABLE_OBJECT> for use with the sn_si.ReportTemplateUtil().constructTable(<TABLE_OBJECT>)
    
    Structure of <TABLE_OBJECT>:

        {
            columns : [
                {
                    label : "Field 1",
                    name : "field1"
                },
                {
                    label : "Field 2",
                    name : "field2"
                },

                ...
            ],
            data : [
                {
                    field1 : "field 1 value",
                    field2 : "field 2 value"
                },
                
                ...
            ]
        }

	Usage:

        var tableName = "sn_si_incident";
        var query = 'short_descriptionLIKEphishing';
        var fields = ['number','short_description'];
		var tableUtil = new sn_si.DataTableObjectUtil(tableName,query,fields);
        var tableObject = tableUtil.getTableObject();

*/

var DataTableObjectUtil = Class.create();
DataTableObjectUtil.prototype = {
    initialize: function(table, query, fields) {
        this.tableName = table;
        this.query = (query) ? query : '';
        this.fields = (fields) ? this.validateFields(fields) : [];
    },

    getTableObject: function() {
		var tableObj = {
            columns: this.fields,
            data: []
        };
		
        var tableGr = new GlideRecord(this.tableName);
        tableGr.addEncodedQuery(this.query);
        tableGr.query();

        while (tableGr.next()) {
            var newRow = {};

            this.fields.forEach(function(f) {
                var fieldName = f.name;

                newRow[fieldName] = tableGr.getValue(fieldName);
            });

            tableObj.data.push(newRow);
        }

        return tableObj;
    },

    validateFields: function(fieldList) {
        var tableGr = new GlideRecord(this.tableName);
        tableGr.setLimit(1);
        tableGr.query();
        tableGr.next();

        var selectedTableFields = [];

        fieldList.forEach(function(f) {
            if (tableGr.isValidField(f)) {
                var thisElement = tableGr.getElement(f);
                var fieldName = thisElement.getName();
                var fieldLabel = thisElement.getLabel();


                selectedTableFields.push({
                    label: fieldLabel,
                    name: fieldName
                });
            }
        });

        return selectedTableFields;
    },

    type: 'DataTableObjectUtil'
};
