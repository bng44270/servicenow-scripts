/*
  Perform pre- and post-clone validation on "Preserve Data" definitions in ServiceNow
  
  Usage:
  
    1.  Change the value of the 'table' and 'checkfield' variables to reflect the Preserve Data definitions 
        you want to check.
    
    2.  Run the script as a background script in the clone source environment
        If Preserve Data definitions exist, you will be presented with a script.
        
    3.  Run the script provided in step 2 on the clone target environment.
        For each record found the value of the 'checkfield' field will be displayed
        which can be used to validate the query on the Preserve Data definition
    
    
*/

var table = 'sys_user';
var checkfield = 'name';


var condition=[];
var gr = new GlideRecord('clone_data_preserver');
gr.addQuery('table',table);
gr.query();
while (gr.next()) {
condition.push(gr.condition.toString());
}
if (condition.length == 0) {
  gs.info('No preserve data definitions found for ' + table);
}
else {
  var script = '\n\nvar conditions = ' + JSON.stringify(condition) + ';\n';
  script += 'conditions.forEach(function(q) {\n';
  script += 'var gr = new GlideRecord("' + table + '");\n';
  script += 'gr.addEncodedQuery(q);\n';
  script += 'gr.query();\n';
  script += 'while (gr.next()) {\n';
  script += 'gs.info(gr.' + checkfield + ');\n';
  script += '}\n'
  script += '});'
  
  gs.info(script);
}