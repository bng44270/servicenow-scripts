/*

  ServiceNow Lookup CI Relationships

  Usage 1 - Finding Children Relationships:

    //Build a CIRelationship object looking at relationships where Parent is <CI-SYS_ID>
    var thisCI = new CIRelationship('<CI-SYS_ID>');
     
    //Get children where <ci_relationship> is the Parent descriptor of the relationship type (i.e. Contains, etc.)
    //    The second argument is optional
    var ciChildren = thisCI.getChildrenByRelationshipType('<ci_relationship>',{
        'sys_class_name':'cmdb_ci_computer'
        //May contain more child CI filter criteria
    });
  
    //ciChildren is an array of CIRelationship objects for chilren of <CI-SYS_ID>

  Usage 2 - Finding Parent Relationships:
  
    //Build a CIRelationship object looking at relationships where Child is <CI-SYS_ID>
    var thisCI = new CIRelationship('<CI-SYS_ID>');
      
    //Get parents where <ci_relationship> is the Child descriptor of the relationship type (i.e. Contained by, etc.)
    //    The second argument is optional
    var ciParents = thisCI.getParentsByRelationshipType('<ci_relationship>',{
        'sys_class_name':'cmdb_ci_computer'
        //May contain more parent CI filter criteria
    });
  
    //ciParents is an array of CIRelationship objects for parents of <CI-SYS_ID>
    
  Usage 3 - Getting CI Data:
  
    //At the end of Usage 1 and 2, you have an array of CIRelationship objects.  Iterate through as such:
    ciChildren.forEach(function(c) {
      
      //Returns gr is a GlideRecord object for <CI-SYS_ID> containing table extension specific data
      var gr = c.getCI();
      
      //Work with gr using GlideRecord API
    
    });
  
*/

var CIRelationship = Class.create();
CIRelationship.prototype = {
  initialize: function(ciSysId) {
    this.ciSysId = ciSysId;
    this.populateRelationshipTypes();
  },

  //Populate local array of avaialble CMDB relationship types
  populateRelationshipTypes: function() {
    this.relationshipTypes = [];

    var relGr = new GlideRecord('cmdb_rel_type');
    relGr.query();
    while (relGr.next()) {
      this.relationshipTypes.push({
        'parent': relGr.getValue('parent_descriptor'),
        'child' : relGr.getValue('child_descriptor'),
        'sys_id' : relGr.getUniqueValue()
      });
    }
  },

  getParentsByRelationshipType : function(relType,relObject) {
    var useRelType = null;
    
    if (!relObject) relObject = {};
    
    //Append "parent." to filter attributes
    var relAttribs = Object.keys(relObject);
    for (var i = 0; i < relAttribs.length; i++) {
      relObject["parent." + relAttribs[i]] = relObject[relAttribs[i]];
      delete relObject[relAttribs[i]];
    }
    
    for (var i = 0; i < this.relationshipTypes.length; i++) {
      if (this.relationshipTypes[i].child == relType) {
        useRelType = this.relationshipTypes[i];
        break;
      }
    }
    
    if (useRelType) {
      relObject['type'] = useRelType.sys_id;
    }
    
    return this.getParents(relObject);
  },

  getParents : function(relObject) {
    var relGr = new GlideRecord('cmdb_rel_ci');
    relGr.addQuery('child',this.ciSysId);
    
    var parents = [];
    var qFields = Object.keys(relObject);

    for (var i = 0; i < qFields.length; i++) {
      relGr.addQuery(qFields[i], relObject[qFields[i]]);
    }

    relGr.query();

    while (relGr.next()) {
      parents.push(new CIRelationship(relGr.parent.sys_id.toString()));
    }

    return parents;
  },
  
  getChildrenByRelationshipType : function(relType,relObject) {
    var useRelType = null;
    
    if (!relObject) relObject = {};
    
    //Append "parent." to filter attributes
    var relAttribs = Object.keys(relObject);
    for (var i = 0; i < relAttribs.length; i++) {
      relObject["child." + relAttribs[i]] = relObject[relAttribs[i]];
      delete relObject[relAttribs[i]];
    }
    
    for (var i = 0; i < this.relationshipTypes.length; i++) {
      if (this.relationshipTypes[i].parent == relType) {
        useRelType = this.relationshipTypes[i];
        break;
      }
    }
    
    if (useRelType) {
      relObject['type'] = useRelType.sys_id;
    }
    
    return this.getChildren(relObject);
  },

  getChildren: function(relObject) {
    var relGr = new GlideRecord('cmdb_rel_ci');
    relGr.addQuery('parent',this.ciSysId);
    
    var children = [];
    var qFields = Object.keys(relObject);
    
    for (var i = 0; i < qFields.length; i++) {
      relGr.addQuery(qFields[i], relObject[qFields[i]]);
    }
    
    relGr.query();

    while (relGr.next()) {
      children.push(new CIRelationship(relGr.child.sys_id.toString()));
    }

    return children;
  },

  getCI: function() {
    var returnValue = false;

    var ciGr = new GlideRecord('cmdb_ci');
    if (ciGr.get(this.ciSysId)) {
      var ciTable = ciGr.sys_class_name.toString();
      ciGr = new GlideRecord(ciTable);
      returnValue = (ciGr.get(this.ciSysId)) ? ciGr : false;
    }

    return returnValue;
  },

  type: 'CIRelationship'
};
