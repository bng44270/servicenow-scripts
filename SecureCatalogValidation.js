/*

Uses u_secure_catalog_def table

Fields:
	cat_item : reference to sc_cat_item
	grant_by : string (can be "user", "group", or "task")
		user : reference to sys_user
	   group : reference to sys_user_group
		
Usage:
	
	Control access on sc_req_item:
	
		if (new SecureCatalogItem(current.cat_item).isSecured() && 
			(new SecureCatalogItem(current.cat_item).hasUserAccess(gs.getUserID()) || 
			new SecureCatalogItem(current.cat_item).hasUserAccess(gs.getUserID()))) {
				//Access is granted
		}
		else if (new SecureCatalogItem(current.cat_item).isSecuredByTask() && (
		new SecureCatalogItem(current.cat_item).hasTaskAccess(gs.getUserId()) ||
		new SecureCatalogItem(current.cat_item).hasTaskManagerAccess(gs.getUserId()))) {
				//Access is granted
		}
		
*/

Array.prototype.contains = function(value) {
    return (this.indexOf(value) > -1) ? true : false;
};

var SecureCatalogValidation = Class.create();
SecureCatalogValidation.prototype = {
    //GR for specific catalog item in control table
    catalogItem: null,

    //sys_id of catalog item
    catalogId: null,

    //Constructor : setup catalogItem property
    initialize: function(catItem) {
        this.catalogId = catItem;

        var gr = new GlideRecord("u_secure_catalog_def");
        gr.addQuery("u_cat_item", catItem);
        this.catalogItem = gr;
    },

    //Returns true if catalog item is secured by user or group, false if not
    isSecuredByAuth: function() {
        var returnValue = false;

        var thisGr = this.catalogItem;
        //u_grant_by = user or group
        thisGr.addEncodedQuery('u_grant_by=group^ORu_grant_by=user');
        thisGr.query();
        if (thisGr.next()) {
            returnValue = true;
        }

        return returnValue;
    },

    //Returns true if catalog item is secured by RITM child task assignment
    isSecuredByTask: function() {
        var returnValue = false;

        var thisGr = this.catalogItem;
        thisGr.addQuery('u_grant_by', 'task');
        thisGr.query();
        if (thisGr.next()) {
            returnValue = true;
        }

        return returnValue;
    },

    //Return true if the current user is the manager of someone with task access, false if not
    hasRITMManagerAccess: function(ritmUniqueId, userUniqueId) {
        var returnValue = false;

        var taskGr = new GlideRecord("sc_task");
        taskGr.addQuery("request_item", ritmUniqueId);
		taskGr.addQuery("request_item.cat_item",this.catalogItem);
        taskGr.query();
        while (taskGr.next()) {
            if (this.hasTaskManagerAccess(taskGr, userUniqueId)) {
                returnValue = true;
                break;
            }
        }

        return returnValue;
    },

    //Return true if the current user has task access, false if not
    hasTaskManagerAccess: function(task, userUniqueId) {
        var returnValue = false;

        if (!gs.nil(task.getValue('assigned_to')))
            if (this._getReportingManagers(task.getValue('assigned_to')).indexOf(userUniqueId) > -1)
                returnValue = true;

        if (!returnValue && !gs.nil(task.getValue('assignment_group')))
            if (this._getGroupMembers(task.getValue('assignment_group')).filter(Array.prototype.contains, this._getSubordinates(userUniqueId)).length > -1)
                returnValue = true;

        if (!returnValue && !gs.nil(task.getValue('additional_assignee_list')))
            if (task.getValue('additional_assignee_list').split(',').filter(Array.prototype.contains, this._getSubordinates(userUniqueId)).length > -1)
                returnValue = true;

        return returnValue;
    },

	//Returns true if current user has access based on child tasks
    hasRITMAccess: function(ritmUniqueId, userUniqueId) {
		var returnValue = false;
		
        var taskGr = new GlideRecord("sc_task");
        taskGr.addQuery("request_item", ritmUniqueId);
		taskGr.addQuery("request_item.cat_item",this.catalogItem);
        taskGr.query();
        while (taskGr.next()) {
            if (this.hasTaskAccess(taskGr,userUniqueId)){
				returnValue = true;
				break;
			}
        }
		
		return returnValue;
    },

    //Returns true if user has access based on RITM child task assignee, false if not
    hasTaskAccess: function(task, userUniqueId) {
        var returnValue = false;

        var userGroups = this._getUserGroups(userUniqueId);

        if (!gs.nil(task.getValue('assigned_to'))) {
            if (task.getValue('assigned_to') == userUniqueId) {
                returnValue = true;
            }
        }

        if (!gs.nil(task.getValue('assignment_group'))) {
            if (userGroups.indexOf(task.getValue('assignment_group')) > -1) {
                returnValue = true;
            }
		}

        if (!gs.nil(task.getValue('additional_assignee_list'))) {
            var additionalAssigneeList = task.getValue('additional_assignee_list').split(',');
            if (additionalAssigneeList.indexOf(userUniqueId) > -1) {
                returnValue = true;
            }
        }

        return returnValue;
    },

    //Returns true if user has user-based access to a catalog item, false if not (Also checks for manage of someone with access)
    hasUserAccess: function(userUniqueId) {
        var returnValue = false;

        var thisGr = this.catalogItem;
        thisGr.addQuery('u_grant_by', 'user');
        thisGr.addQuery('u_user', userUniqueId);
        thisGr.query();
        if (thisGr.next()) {
            returnValue = true;
        }

        if (!returnValue) {
            var subordinates = this._getSubordinates(userUniqueId);
            thisGr = this.catalogItem;
            thisGr.addQuery('u_grant_by', 'user');
            thisGr.query();
            while (thisGr.next()) {
                if (subordinates.indexOf(thisGr.getValue('u_user')) > -1) {
                    returnValue = true;
                    break;
                }
            }
        }
        return returnValue;
    },
    //Returns true if user has group-based access to a catalog item, false if not
    hasGroupAccess: function(userUniqueId) {
        var returnValue = false;

        var userGroups = this._getUserGroups(userUniqueId);
        var thisGr = this.catalogItem;
        thisGr.addQuery('u_grant_by', 'group');
        thisGr.query();
        while (thisGr.next()) {
            if (userGroups.indexOf(thisGr.getValue('u_group').toString()) > -1) {
                returnValue = true;
                break;
            }
        }

        if (!returnValue) {
            var subordinates = this.getSubordinates(userUniqueId);

            for (var personIdx in subordinates) {
                userGroups = this.getUserGroups(thisSubordinate);
                thisGr = this.catalogItem;
                thisGr.addQuery('u_grant_by', 'group');
                thisGr.query();
                while (thisGr.next()) {
                    if (userGroups.indexOf(thisGr.getValue('u_group')) > -1) {
                        returnValue = true;
                        break;
                    }
                }
                if (returnValue)
                    break;
            }
        }

        return returnValue;
    },

    //Returns array of groups that user is a member of
    _getUserGroups: function(userUniqueId) {
        var returnValue = [];

        var userGr = new GlideRecord("sys_user_grmember");
        userGr.addQuery("user", userUniqueId);
        userGr.query();
        while (userGr.next()) {
            returnValue.push(userGr.getValue('group'));
        }
        return returnValue;
    },

    //Returns array of users who are a member of the specified group
    _getGroupMembers: function(groupUniqueId) {
        var returnValue = [];
        var gr = new GlideRecord("sys_user_grmember");
        gr.addQuery("group", groupUniqueId);
        gr.query();
        while (gr.next()) {
            returnValue.push(gr.getValue('user'));
        }
        return returnValue;
    },

    //Returns array of subordinates given a user sys_id (based on manager field)
    _getSubordinates: function(userUniqueId) {
        var returnValue = [];

        var gr = new GlideRecord("sys_user");
        gr.addQuery("manager", userUniqueId);
        gr.query();
        if (gr.getRowCount() > 0) {
            while (gr.next()) {
                returnValue.push(gr.getUniqueValue());
                this._getSubordinates(gr.getUniqueValue()).forEach(function(thisPerson) {
                    returnValue.push(thisPerson);
                });
            }
        }

        return returnValue;
    },

    //Returns array of reporting managers given an array of users sys_id (based on manager field)
    _getReportingManagers: function(userUniqueId) {
        var returnValue = [];

        var gr = new GlideRecord("sys_user");
        gr.addQuery("sys_id", userUniqueId);
        gr.query();
        if (gr.next()) {
            if (!gs.nil(gr.getValue('manager'))) {
                returnValue.push(gr.getValue('manager'));
                this._getReportingManagers(gr.getValue('manager')).forEach(function(thisPerson) {
                    returnValue.push(thisPerson);
                });
            }
        }
        return returnValue;
    },
    type: 'SecureCatalogValidation'
};
